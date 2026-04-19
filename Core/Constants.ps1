<#
.SYNOPSIS
    Constantes globais do projeto PostInstall.

.DESCRIPTION
    Centraliza todas as cores, ícones, códigos de saída e outros valores
    que antes estavam hardcoded dispersos pelo código.
    Acesse via $global:PSConst.<Categoria>.<Chave>.
#>

if (-not $global:PSConst) {
    $global:PSConst = @{

        # ─── Cores da interface (WPF hex strings) ────────────────────────────
        Colors = @{
            Accent          = '#993233'   # Vermelho — botões de ação destrutiva / padrão
            Background      = '#1E1E1E'   # Fundo principal das janelas
            Surface         = '#2D2D30'   # Superfície de controles (botão padrão)
            Success         = '#28A745'   # Verde — sucesso leve
            SuccessAlt      = '#4CAF50'   # Verde — sucesso alternativo (Office/OEM)
            Error           = '#CC6666'   # Vermelho suave — estado de erro em botão
            ErrorStrong     = '#DC3545'   # Vermelho Bootstrap — erro crítico
            Disabled        = '#555555'   # Cinza — desabilitado / já executado
            Info            = '#0078D4'   # Azul — informação
            Warning         = '#FFA500'   # Laranja — aviso
        }

        # ─── Ícones Segoe MDL2 Assets (codepoints Unicode) ──────────────────
        Icons = @{
            All             = [char]0xF0E2   # "Mostrar todos" / reload
            CheckAll        = [char]0xE9D5   # Check / marcar tudo
            ClearAll        = [char]0xED62   # Borracha / limpar seleção
            Error           = [char]0xE783   # Exclamação — erro de carregamento
            Warning         = [char]0xE7BA   # Aviso
            Question        = [char]0xE9CE   # Ajuda / pergunta
            Connection      = [char]0xEB55   # Conexão
            Settings        = [char]0xE713   # Engrenagem
            Info            = [char]0xE946   # Informação
            Notification    = [char]0xE7E7   # Sino — notificação
            Theme           = [char]0xE793   # Paleta de cores / tema
            Moon            = [char]0xE708   # Lua — tema escuro
            Sun             = [char]0xE706   # Sol — tema claro
            AvoidSleepOn    = [char]0xEB50   # Lâmpada com check
            AvoidSleepOff   = [char]0xE82F   # Lâmpada padrão
            Sleep           = [char]0xE708   # Lua — evitar suspensão
            NoSleep         = [char]0xE7E8   # Copo de café — modo ativo
            Close           = [char]0xE8BB   # X
            Log             = [char]0xE7C3   # Documento de log
            Finalize        = [char]0xE930   # Seta de conclusão
        }

        # ─── Códigos de saída do WinGet ──────────────────────────────────────
        WinGet = @{
            # 0x80240024 = APPINSTALLER_ERROR_NO_APPLICABLE_UPGRADE
            # Tratado como sucesso: significa que o pacote já está atualizado
            ExitCode_AlreadyLatest = -1978335189
            ExitCode_Success       = 0
        }

        # ─── Status de licença do Windows (SoftwareLicensingProduct) ─────────
        WindowsLicense = @{
            Unlicensed          = 0
            Licensed            = 1   # Produto licenciado / ativado
            OutOfBoxGracePeriod = 2
            OutOfToleranceGrace = 3
            NonGenuineGrace     = 4
            Notification        = 5
            ExtendedGrace       = 6
        }

        # ─── Caminhos de log ─────────────────────────────────────────────────
        LogPaths = @{
            Primary  = "$env:SystemRoot\Setup\Scripts\Install.log"
            Fallback = "$env:APPDATA\Install.log"
        }

        # ─── Sentinelas e tipos especiais de Registro ───────────────────────
        Registry = @{
            DeleteKeyType = 'DeleteKey'
            DeleteKeyTypeUpper = 'DELETEKEY'
            RemoveEntrySentinel = '<RemoveEntry>'
            RestoreKeySentinel = '<RestoreKey>'
        }

        # ─── IDs de navegadores conhecidos (detecção de conflito MSEdgeRedirect) ──
        KnownBrowserIDs = @(
            'Google.Chrome'
            'Mozilla.Firefox'
            'Microsoft.Edge'
            'Opera.Opera'
        )
    }
}
