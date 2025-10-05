function global:Get-SystemInfo {
    <#
    .SYNOPSIS
    Coleta informações detalhadas do sistema atual
    
    .DESCRIPTION
    Coleta informações sobre hardware, sistema operacional, BIOS, processador,
    memória, discos e placas de vídeo do sistema atual. Sempre popula a variável
    global $systemInfo, mas só escreve no log se for solicitado.
    
    .PARAMETER WriteToLog
    Se especificado, escreve as informações do sistema no log
    
    .EXAMPLE
    $systemInfo = Get-SystemInfo
    Write-Host $systemInfo
    
    .EXAMPLE
    $systemInfo = Get-SystemInfo -WriteToLog
    #>
    
    param(
        [switch]$WriteToLog
    )
    
    try { 
        
        # Coletar informações do sistema
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $win = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        $disks = Get-WmiObject -Class Win32_DiskDrive | Where-Object { $_.MediaType -like "*Fixed*" } | Sort-Object -Property Index
        $gpus = Get-WmiObject -Class Win32_VideoController
        
        # Determinar tipo de boot
        $bootType = "Indeterminado"
        try {
            $secureBootStatus = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
            $bootType = "UEFI"
            if ($secureBootStatus) {
                $bootType += " com Secure Boot ativado"
            }
            else {
                $bootType += " com Secure Boot desativado"
            }
        }
        catch [System.PlatformNotSupportedException] {
            $bootType = "Legacy"
        }
        catch {
            $bootType = "UEFI (status do Secure Boot indeterminado)"
        }
        
        # Construir string de informações do sistema
        $global:systemInfo = New-Object System.Text.StringBuilder
        [void]$global:systemInfo.AppendLine("INFORMAÇÕES DO SISTEMA")
        [void]$global:systemInfo.AppendLine("="*50)
        [void]$global:systemInfo.AppendLine("Máquina: $($computerSystem.ChassisSKUNumber) $($computerSystem.Manufacturer) $($computerSystem.Model)")
        [void]$global:systemInfo.AppendLine("Número de série / Service Tag: $($bios.SerialNumber)")
        [void]$global:systemInfo.AppendLine("Processador: $($processor.Name)")
        [void]$global:systemInfo.AppendLine("Memória RAM: $([math]::Round($computerSystem.TotalPhysicalMemory/1GB, 2)) GB")
        [void]$global:systemInfo.AppendLine("$($os.Caption) de $($os.OSArchitecture)")
        [void]$global:systemInfo.AppendLine("Build: $($win.DisplayVersion)")
        [void]$global:systemInfo.AppendLine("Tipo de Boot: $bootType")
        [void]$global:systemInfo.AppendLine("")
        [void]$global:systemInfo.AppendLine("DISCOS:")
        [void]$global:systemInfo.AppendLine("-"*20)
        
        # Adicionar informações dos discos
        $disks | ForEach-Object {
            $diskSize = [math]::Round($_.Size / 1GB, 2)
            [void]$global:systemInfo.AppendLine("Disco $($_.Index): $($_.Model) ($diskSize GB)")
        }
        
        [void]$global:systemInfo.AppendLine("")
        [void]$global:systemInfo.AppendLine("GPUS:")
        [void]$global:systemInfo.AppendLine("-"*20)
        
        # Adicionar informações das GPUs
        $gpus | ForEach-Object {
            $gpuMemory = if ($_.AdapterRAM -gt 0) { [math]::Round($_.AdapterRAM / 1MB, 0) } else { "Desconhecida" }
            $gpuMemoryUnit = if ($_.AdapterRAM -gt 0) { "MB" } else { "" }
            [void]$global:systemInfo.AppendLine("GPU: $($_.Name) - Memória: $gpuMemory $gpuMemoryUnit")
        }
        
        $result = $global:systemInfo.ToString()
        
        # Escrever no log apenas se solicitado
        if ($WriteToLog) {
            Write-SystemInfoToLog -SystemInfo $result
        }
        
        return $result
    }
    catch {
        $errorMessage = "Erro ao coletar informações do sistema: $($_.Exception.Message)"
        Write-InstallLog $errorMessage -Status "ERRO"
        return "Erro na coleta de informações do sistema"
    }
}