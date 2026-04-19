function Get-SharedDialogResourceDictionary {
    <#
    .SYNOPSIS
    Retorna estilos compartilhados para diÃ¡logos XAML.

    .DESCRIPTION
    Centraliza estilos visuais reutilizados por mÃºltiplos diÃ¡logos
    para reduzir duplicação e facilitar manutenção.
    #>

    [CmdletBinding()]
    param()

    try {
        $sharedResourcesXaml = @"
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <Style x:Key="CommonDialogButtonStyle" TargetType="Button">
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="FontFamily" Value="Futura"/>
        <Setter Property="FontSize" Value="14"/>
        <Setter Property="Padding" Value="10,5"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Margin" Value="5"/>
        <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="FocusBorder"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="3">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsKeyboardFocused" Value="True">
                            <Setter TargetName="FocusBorder" Property="BorderBrush" Value="White"/>
                            <Setter TargetName="FocusBorder" Property="BorderThickness" Value="2"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Opacity" Value="0.85"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter Property="Opacity" Value="0.7"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style x:Key="CommonFilledDialogButtonStyle" TargetType="Button" BasedOn="{StaticResource CommonDialogButtonStyle}">
        <Setter Property="Background" Value="#2D2D30"/>
        <Setter Property="BorderBrush" Value="#3F3F46"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="Padding" Value="15,8"/>
        <Setter Property="Margin" Value="5"/>
        <Style.Triggers>
            <Trigger Property="IsPressed" Value="True">
                <Setter Property="Opacity" Value="0.5"/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style x:Key="CommonDangerActionButtonStyle" TargetType="Button" BasedOn="{StaticResource CommonDialogButtonStyle}">
        <Setter Property="Background" Value="#993233"/>
        <Setter Property="BorderBrush" Value="#3F3F46"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Style.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#B73E40"/>
            </Trigger>
            <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#7A2829"/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style x:Key="CommonDialogTextBlockStyle" TargetType="TextBlock">
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="FontFamily" Value="Futura"/>
        <Setter Property="FontSize" Value="14"/>
    </Style>

    <Style x:Key="CommonDialogInputTextBoxStyle" TargetType="TextBox">
        <Setter Property="Background" Value="#2D2D30"/>
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="FontFamily" Value="Futura"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Padding" Value="8"/>
        <Setter Property="BorderBrush" Value="#3F3F46"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="CaretBrush" Value="White"/>
    </Style>

    <Style x:Key="CommonCheckBoxStyle" TargetType="CheckBox">
        <Setter Property="Foreground" Value="LightGray"/>
        <Setter Property="FontFamily" Value="Futura"/>
        <Setter Property="FontSize" Value="14"/>
        <Setter Property="Margin" Value="5,8"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Style.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="White"/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style x:Key="CommonCloseButtonStyle" TargetType="Button">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="BorderBrush" Value="Transparent"/>
        <Setter Property="Width" Value="30"/>
        <Setter Property="Height" Value="30"/>
        <Setter Property="FontSize" Value="16"/>
        <Setter Property="FontWeight" Value="Bold"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="FocusBorder"
                            Background="{TemplateBinding Background}"
                            CornerRadius="15"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}">
                        <ContentPresenter HorizontalAlignment="Center"
                                          VerticalAlignment="Center"
                                          TextElement.Foreground="{TemplateBinding Foreground}"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsKeyboardFocused" Value="True">
                            <Setter TargetName="FocusBorder" Property="BorderBrush" Value="White"/>
                            <Setter TargetName="FocusBorder" Property="BorderThickness" Value="2"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#4A4A4F"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter Property="Background" Value="#6A6A6F"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style x:Key="CommonMutedCloseButtonStyle" TargetType="Button" BasedOn="{StaticResource CommonCloseButtonStyle}">
        <Setter Property="Foreground" Value="#CCCCCC"/>
        <Style.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="White"/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style x:Key="SlimScrollBarStyle" TargetType="{x:Type ScrollBar}">
        <Setter Property="Width" Value="8"/>
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="{x:Type ScrollBar}">
                    <Grid>
                        <Track Name="PART_Track" IsDirectionReversed="True">
                            <Track.Thumb>
                                <Thumb>
                                    <Thumb.Style>
                                        <Style TargetType="{x:Type Thumb}">
                                            <Setter Property="Background" Value="#4A4A4F"/>
                                            <Setter Property="BorderBrush" Value="Transparent"/>
                                            <Setter Property="Template">
                                                <Setter.Value>
                                                    <ControlTemplate TargetType="{x:Type Thumb}">
                                                        <Border Background="{TemplateBinding Background}"
                                                                CornerRadius="4"
                                                                Margin="2,0"/>
                                                        <ControlTemplate.Triggers>
                                                            <Trigger Property="IsMouseOver" Value="True">
                                                                <Setter Property="Background" Value="#6A6A6F"/>
                                                            </Trigger>
                                                        </ControlTemplate.Triggers>
                                                    </ControlTemplate>
                                                </Setter.Value>
                                            </Setter>
                                        </Style>
                                    </Thumb.Style>
                                </Thumb>
                            </Track.Thumb>
                        </Track>
                    </Grid>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
</ResourceDictionary>
"@

        [xml]$parsed = $sharedResourcesXaml
        return [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $parsed))
    }
    catch {
        Write-InstallLog "Erro em Get-SharedDialogResourceDictionary: $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        return $null
    }
}

