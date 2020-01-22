param(
    [string]$ComputerName = $null,
    [string]$Username = 'vagrant',
    [string]$Password = 'vagrant'
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
$unattendPs1Path = "$PSScriptRoot\vagrant-windows-sysprep-unattend.ps1"

# sysprep renames the user that has the well-known Administrator SID
# to the Administrator name, when $Username has that SID, we must
# rename Administrator back to the $Username name.
# NB this SID always has the format S-1-5-21-<domain>-500.
# see https://support.microsoft.com/en-us/help/243330/well-known-security-identifiers-in-windows-operating-systems
$administratorLocalUser = Get-LocalUser | Where-Object {$_.SID.Value -match '^S-1-5-21-.+-500$'}
$enableAdministrator = $administratorLocalUser.Enabled
$renameAdministratorToUsername = $administratorLocalUser.Name -eq $Username

# NB doing an auto-logon after a sysprep has two effects:
#    1. make Windows 10 1809 not ask for an account creation (regardless of the
#       value of SkipUserOOBE/SkipMachineOOBE).
#       NB even when you disable the local accounts security questions with:
#               # Windows 10 1803 started to require local account security questions but provided
#               # no way to configure or skip those on sysprep, so we have to manually disable
#               # that feature.
#               # NB even with this windows stills asks for a Password Hint.
#               # see https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/customize-oobe
#               Write-Host 'Disabling the use of Security Questions for Local Accounts...'
#               Set-ItemProperty `
#                   -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\System `
#                   -Name NoLocalPasswordResetQuestions `
#                   -Value 1
#          Windows will still ask for a password hint...
#    2. make vagrant be able to go through the stage (on Windows 10 1809):
#           ==> default: Mounting SMB shared folders...
#               default: /home/rgl/Projects/windows-2016-vagrant/example => /vagrant
# NB there's a bug somewhere in windows sysprep machinery that prevents it from setting the
#    ComputerName when the name doesn't really change (like when you use config.vm.hostname),
#    it will instead set the ComputerName to something like WIN-0F47SUATAF5.
#    so this configuration will not really work... but its here to see when they fix this problem.
Write-Host 'Configuring sysprep...'
Set-Content `
    -Encoding UTF8 `
    -Path $unattendPath `
    -Value (
        (Get-Content -Raw $unattendPath) `
            -replace '@@COMPUTERNAME@@',$ComputerName `
            -replace '@@USERNAME@@',$Username `
            -replace '@@PASSWORD@@',$Password `
            -replace '@@UNATTENDPS1PATH@@',$unattendPs1Path
    )
$unattendPs1 = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Write-Host
    Write-Host 'Sleeping during 60 minutes to give you time to see this error message...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

Write-Host @"
WARNING WARNING WARNING WARNING WARNING WARNING

  this is being run by vagrant-windows-sysprep

            do NOT touch anything

WARNING WARNING WARNING WARNING WARNING WARNING

"@

if ($enableAdministrator) {
    Get-LocalUser -Name Administrator | Enable-LocalUser
} else {
    Get-LocalUser -Name Administrator | Disable-LocalUser
}

if ($renameAdministratorToUsername) {
    Get-LocalUser -Name Administrator | Rename-LocalUser -NewName $Username
}

Write-Host 'Waiting for WinRM to be running...'
while ((Get-Service WinRM).Status -ne 'Running') {
    Start-Sleep -Seconds 5
}

Write-Host 'Disabling auto logon...'
$autoLogonKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty `
    -Path $autoLogonKeyPath `
    -Name AutoAdminLogon `
    -Value 0
Remove-ItemProperty `
    -Path $autoLogonKeyPath `
    -Name @(
        'DefaultDomainName',
        'DefaultUserName',
        'DefaultPassword'
    ) `
    -ErrorAction SilentlyContinue

Write-Host 'Logging off...'
logoff
'@ `
    -replace '\$enableAdministrator',"$(if ($enableAdministrator) {'$true'} else {'$false'})" `
    -replace '\$renameAdministratorToUsername',"$(if ($renameAdministratorToUsername) {'$true'} else {'$false'})" `
    -replace '\$Username',"'$Username'"
Set-Content `
    -Encoding UTF8 `
    -Path $unattendPs1Path `
    -Value $unattendPs1

Write-Host 'Syspreping...'
C:/Windows/System32/Sysprep/sysprep.exe `
    /generalize `
    /oobe `
    /quiet `
    /shutdown `
    "/unattend:$unattendPath" `
    | Out-String -Stream
