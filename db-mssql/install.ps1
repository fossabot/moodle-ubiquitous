Param(
    [string] $dataRoot = "C:\SQLData",
    [string] $dataDatabases = (Join-Path $dataRoot "Databases"),
    [string] $dataLogs = (Join-Path $dataRoot "Logs")
)

function Export-LocalSecurityPolicy {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $FileName
    )

    & secedit /export /cfg $securityPolicyCfg
}

function Import-LocalSecurityPolicy {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $FileName,

        [Parameter(Mandatory=$false)]
        [string] $Database = "$($env:WINDIR)\security\local.sdb"
    )

    & secedit /import /db $Database /cfg $FileName /overwrite /quiet
}

function Set-LocalSecurityPolicy {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $FileName,

        [Parameter(Mandatory=$true)]
        [string] $Policy,

        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    $find    = "^$($Policy) = .*$"
    $replace = "$($Policy) = $($Value)"

    (Get-Content $FileName) -replace $find, $replace | Set-Content $FileName
}

# Disable enforcement of the password policy
$securityPolicyCfg = [System.IO.Path]::GetTempFileName()
Export-LocalSecurityPolicy -FileName $securityPolicyCfg
Set-LocalSecurityPolicy `
        -FileName $securityPolicyCfg -Policy "PasswordComplexity" -Value 0
Import-LocalSecurityPolicy -FileName $securityPolicyCfg

# Create the directories
New-Item -Force -Type Directory $dataRoot
New-Item -Force -Type Directory $dataDatabases, $dataLogs
