function global:Get-SystemInfo {
    <#
    .SYNOPSIS
    Coleta informações detalhadas do sistema atual
    
    .DESCRIPTION
    Coleta informações sobre hardware, sistema operacional, BIOS, processador,
    memória, discos e placas de vídeo do sistema atual. Sempre popula a variável
    global $global:SystemInfoData como PSCustomObject e pode escrever no log se for solicitado.
    
    .PARAMETER WriteToLog
    Se especificado, escreve as informações do sistema no log
    
    .EXAMPLE
    $info = Get-SystemInfo
    $info | Format-List
    
    .EXAMPLE
    $info = Get-SystemInfo -WriteToLog
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
        
        # Construir objeto estruturado de informações do sistema
        $systemInfoObj = [pscustomobject]@{
            Machine = [pscustomobject]@{
                Manufacturer = $computerSystem.Manufacturer
                Model = $computerSystem.Model
                ChassisSKUNumber = $computerSystem.ChassisSKUNumber
            }
            SerialNumber = $bios.SerialNumber
            Processor = [pscustomobject]@{
                Name = $processor.Name
                NumberOfCores = $processor.NumberOfCores
                LogicalProcessors = $processor.NumberOfLogicalProcessors
            }
            TotalMemoryGB = [math]::Round($computerSystem.TotalPhysicalMemory/1GB, 2)
            OS = [pscustomobject]@{
                Caption = $os.Caption
                Architecture = $os.OSArchitecture
                DisplayVersion = $win.DisplayVersion
                Version = $os.Version
            }
            Boot = [pscustomobject]@{
                Type = if ($bootType -like 'Legacy*') { 'Legacy' } else { 'UEFI' }
                SecureBootEnabled = if ($null -ne $secureBootStatus) { [bool]$secureBootStatus } else { $null }
                Description = $bootType
            }
            Disks = @(
                $disks | ForEach-Object {
                    [pscustomobject]@{
                        Index = $_.Index
                        Model = $_.Model
                        SizeGB = [math]::Round($_.Size / 1GB, 2)
                    }
                }
            )
            GPUs = @(
                $gpus | ForEach-Object {
                    [pscustomobject]@{
                        Name = $_.Name
                        MemoryMB = if ($_.AdapterRAM -gt 0) { [math]::Round($_.AdapterRAM / 1MB, 0) } else { $null }
                    }
                }
            )
        }
        
        $global:SystemInfoData = $systemInfoObj
        $result = $systemInfoObj
        
        # Escrever no log apenas se solicitado
        if ($WriteToLog) {
            Write-SystemInfoToLog -SystemInfoData $result
        }
        
        return $result
    }
    catch {
        $errorMessage = "Erro ao coletar informações do sistema: $($_.Exception.Message)"
        Write-InstallLog $errorMessage -Status "ERRO"
        return "Erro na coleta de informações do sistema"
    }
}