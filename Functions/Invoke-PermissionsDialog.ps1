<#
.SYNOPSIS
    Funções auxiliares para o diálogo de permissões

.DESCRIPTION
    Este arquivo contém todas as funções necessárias para o funcionamento
    do diálogo de permissões, incluindo montagem de volumes, reset de permissões
    e manipulação da interface.

.AUTHOR
    Sistema de Post-Instalação
#>
function global:Register-PermissionsReset {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$selectedFolders
    )
    
    try {
        $DateTime = Get-Date -Format "dd-MM-yyyy-HH-mm-ss"
        $taskName = "ResetPermissions-$DateTime"
        $scriptPath = "$env:TEMP\ResetPermissions-$DateTime.ps1"
        
        # Criar script temporário
        $scriptContent = @"
foreach (`$path in @('$($selectedFolders -join "', '")')) {
    if (Test-Path `$path) {
        icacls "`$path" /reset /T /C /Q
    }
}
Unregister-ScheduledTask -TaskName "$taskName" -Confirm:`$false

Remove-Item "$scriptPath" -Force
"@
        
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8
        
        # Criar tarefa agendada
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force
        
        Write-InstallLog "Tarefa agendada criada com sucesso: $taskName" -Status "SUCESSO"
        return $true
    } catch {
        Write-InstallLog "Falha ao agendar tarefa: $_" -Status "ERRO"
        return $false
    }
}

function global:Remove-RedundantSubfolders {
    <#
    .SYNOPSIS
    Remove subpastas redundantes de uma lista, mantendo apenas as pastas-pai
    
    .DESCRIPTION
    Analisa uma lista de caminhos de pastas e remove aquelas que são subpastas
    de outras já presentes na lista, evitando redundância no processamento
    
    .PARAMETER FolderList
    Array de caminhos de pastas para analisar
    
    .EXAMPLE
    $folders = @('C:\Users', 'C:\Users\Documents', 'D:\Data')
    $cleanFolders = Remove-RedundantSubfolders -FolderList $folders
    # Retorna: @('C:\Users', 'D:\Data')
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FolderList
    )
    
    if ($FolderList.Count -le 1) {
        return ,$FolderList
    }
    
    Write-InstallLog "Iniciando análise de $($FolderList.Count) pastas para remoção de redundâncias" 
    
    # Criar uma lista de objetos com caminho original e normalizado
     $folderObjects = @()
     for ($i = 0; $i -lt $FolderList.Count; $i++) {
         $folderObjects += [PSCustomObject]@{
             Original = $FolderList[$i]
             Normalized = $FolderList[$i].TrimEnd('\', '/').ToLower()
             Index = $i
         }
     }
    
    # ArrayList para melhor performance
    $parentFolders = New-Object System.Collections.ArrayList
    
    # Para cada pasta, verificar se ela é subpasta de alguma outra
    foreach ($currentFolderObj in $folderObjects) {
        $isSubfolder = $false
        $currentPath = $currentFolderObj.Normalized
        
        # Verificar contra todas as outras pastas
        foreach ($otherFolderObj in $folderObjects) {
            $otherPath = $otherFolderObj.Normalized
            
            # Pular se for a mesma pasta
            if ($currentFolderObj.Index -eq $otherFolderObj.Index) {
                continue
            }
            
            # Verificar se a pasta atual é subpasta da outra
            # A pasta atual é subpasta se começar com o caminho da outra + separador
            if ($currentPath.StartsWith($otherPath + '\') -or $currentPath.StartsWith($otherPath + '/')) {
                $isSubfolder = $true
                Write-InstallLog "Subpasta removida: '$($currentFolderObj.Original)' (pai: '$($otherFolderObj.Original)')" 
                break
            }
        }
        
        # Se não é subpasta de nenhuma outra, adicionar à lista de pastas-pai
        if (-not $isSubfolder) {
            [void]$parentFolders.Add($currentFolderObj)
        }
    }
    
    # Extrair apenas os caminhos originais
    $result = @($parentFolders | ForEach-Object { $_.Original })
    
    Write-InstallLog "Análise concluída: $($result.Count) pastas mantidas de $($FolderList.Count) originais" 
    
    # Garantir que retornamos um array mesmo com um único elemento
    return ,$result
}