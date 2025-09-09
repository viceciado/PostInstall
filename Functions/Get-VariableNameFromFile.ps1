function global:Get-VariableNameFromFile {
    param([string]$FileName)
    
    # Remover extensão .xaml
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    
    # Usar convenção consistente: NomeArquivo + 'Xaml' (camelCase)
    # Ex: MainWindow.xaml -> mainWindowXaml
    # Ex: SplashScreen.xaml -> splashScreenXaml
    # Ex: ActivationDialog.xaml -> activationDialogXaml
    $variableName = $baseName.Substring(0,1).ToLower() + $baseName.Substring(1) + 'Xaml'
    return $variableName
}