function Set-RegistryEntry {
    <#
    .SYNOPSIS
        Aplica uma entrada de registro (cria ou atualiza valor, ou remove chave).
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $false)][string]$Name,
        [Parameter(Mandatory = $true)] [string]$Type,
        [Parameter(Mandatory = $false)]$Value
    )
    try {
        $norm        = ConvertTo-RegistryType -Type $Type
        $typeUpper   = $norm.Up
        $psType      = $norm.Ps

        if ($typeUpper -eq 'DELETEKEY') {
            if (Test-Path -Path $Path) {
                Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
                Write-InstallLog "Chave removida: $Path"
            }
            else {
                Write-InstallLog "Chave nÃ£o encontrada para remover: $Path" -Status "AVISO"
            }
            return $true
        }

        if (-not (Test-Path -Path $Path)) { New-Item -Path $Path -Force | Out-Null }

        $existing = if ($Name) { Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue } else { $null }

        $converted = $Value
        switch ($typeUpper) {
            'DWORD'        { $converted = [int]$Value }
            'QWORD'        { $converted = [long]$Value }
            'STRING'       { $converted = [string]$Value }
            'EXPANDSTRING' { $converted = [string]$Value }
            'BINARY'       {
                if ($Value -is [string]) { $converted = ($Value -split ',') | ForEach-Object { [byte]$_ } }
            }
            'MULTISTRING'  {
                if ($Value -isnot [array]) { $converted = @([string]$Value) }
            }
            default { $converted = $Value }
        }

        if ($Name) {
            if ($null -ne $existing) {
                Set-ItemProperty -Path $Path -Name $Name -Value $converted -ErrorAction Stop
            }
            else {
                New-ItemProperty -Path $Path -Name $Name -PropertyType $psType -Value $converted -Force -ErrorAction Stop | Out-Null
            }
        }
        Write-InstallLog "Registro aplicado: $Path :: $Name = $converted ($typeUpper/$psType)"
        return $true
    }
    catch {
        Write-InstallLog "Erro em Set-RegistryEntry ($Path::$Name): $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

# Wrapper de compatibilidade com cÃ³digo anterior
function Apply-RegistryEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $false)][string]$Name,
        [Parameter(Mandatory = $true)] [string]$Type,
        [Parameter(Mandatory = $false)]$Value
    )

    return Set-RegistryEntry @PSBoundParameters
}

