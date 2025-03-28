param (
    [Parameter(Mandatory = $true)]
    [string]$ForestName
)

# Variables
$SafeModePassword = Read-Host -AsSecureString -Prompt "Safe Mode Administrator Password (DSRM)"
$DomainNetBIOSName = ($ForestName -split '\.')[0].ToUpper()
$LogPath = "C:\Logs\DCPromo.log"

# Create the log directory if it doesn't exist
if (-not (Test-Path "C:\Logs")) {
    New-Item -ItemType Directory -Path "C:\Logs"
}

Write-Output "==========================" | Tee-Object -FilePath $LogPath -Append
Write-Output "Domain Controller Promotion - $ForestName" | Tee-Object -FilePath $LogPath -Append
Write-Output "Date: $(Get-Date)" | Tee-Object -FilePath $LogPath -Append
Write-Output "==========================" | Tee-Object -FilePath $LogPath -Append

# Install the AD DS role
Write-Output "Installing AD DS role..." | Tee-Object -FilePath $LogPath -Append
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Tee-Object -FilePath $LogPath -Append

# Promote the server as a domain controller
Write-Output "Promoting the server as a domain controller..." | Tee-Object -FilePath $LogPath -Append
Install-ADDSForest `
    -DomainName $ForestName `
    -DomainNetbiosName $DomainNetBIOSName `
    -SafeModeAdministratorPassword $SafeModePassword `
    -InstallDns `
    -Force `
    -NoRebootOnCompletion:$false | Tee-Object -FilePath $LogPath -Append
