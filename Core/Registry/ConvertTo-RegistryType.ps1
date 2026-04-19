function ConvertTo-RegistryType {
    <#
    .SYNOPSIS
        Converte uma string de tipo de registro em representação normalizada.
    .OUTPUTS
        Hashtable com chaves 'Up' (tipo uppercase) e 'Ps' (PropertyType para New-ItemProperty).
    #>
    param([string]$Type)
    $t = if ($Type) { $Type.ToUpperInvariant() } else { '' }
    switch ($t) {
        'REG_DWORD'      { return @{ Up = 'DWORD';        Ps = 'DWord' } }
        'DWORD'          { return @{ Up = 'DWORD';        Ps = 'DWord' } }
        'REG_QWORD'      { return @{ Up = 'QWORD';        Ps = 'QWord' } }
        'QWORD'          { return @{ Up = 'QWORD';        Ps = 'QWord' } }
        'REG_SZ'         { return @{ Up = 'STRING';       Ps = 'String' } }
        'STRING'         { return @{ Up = 'STRING';       Ps = 'String' } }
        'REG_EXPAND_SZ'  { return @{ Up = 'EXPANDSTRING'; Ps = 'ExpandString' } }
        'EXPANDSTRING'   { return @{ Up = 'EXPANDSTRING'; Ps = 'ExpandString' } }
        'REG_BINARY'     { return @{ Up = 'BINARY';       Ps = 'Binary' } }
        'BINARY'         { return @{ Up = 'BINARY';       Ps = 'Binary' } }
        'REG_MULTI_SZ'   { return @{ Up = 'MULTISTRING';  Ps = 'MultiString' } }
        'MULTISTRING'    { return @{ Up = 'MULTISTRING';  Ps = 'MultiString' } }
        default          { return @{ Up = $t;             Ps = $Type } }
    }
}

