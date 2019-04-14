param(
    [string]$ComputerName = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

if (!$ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$unattendPath = "$PSScriptRoot\vagrant-windows-sysprep-unattend.xml"

# NB there's a bug somewhere in windows sysprep machinery that prevents it from setting the
#    ComputerName when the name doesn't really change (like when you use config.vm.hostname),
#    it will instead set the ComputerName to something like WIN-0F47SUATAF5.
#    so this configuration will not really work... but its here to see when they fix this problem.
Write-Host "Configuring sysprep to set ComputerName to $ComputerName..."
Set-Content `
    -Encoding UTF8 `
    -Path $unattendPath `
    -Value (
        (Get-Content -Raw $unattendPath) `
            -replace '@@COMPUTERNAME@@',$ComputerName
    )

Write-Host 'Syspreping...'
C:/Windows/System32/Sysprep/sysprep.exe `
    /generalize `
    /oobe `
    /quiet `
    /shutdown `
    "/unattend:$unattendPath" `
    | Out-String -Stream
