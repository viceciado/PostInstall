@{
    Severity = @('Error', 'Warning')

    Rules = @{
        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace = @{
            Enable          = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $true
            CheckSeparator  = $true
            CheckPipe       = $true
            CheckPipeForRedundantWhitespace = $false
        }

        PSPlaceOpenBrace = @{
            Enable              = $true
            OnSameLine          = $true
            NewLineAfter        = $true
            IgnoreOneLineBlock  = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
    }
}
