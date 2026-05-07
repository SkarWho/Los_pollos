# 08_DC02.ps1
# Deploiement du Domain Controller secondaire
# A executer sur une installation fraiche de Windows Server 2019
#
# PARTIE 1 : configuration reseau + jonction domaine (redemarrage auto)
# PARTIE 2 : promotion en DC secondaire (apres redemarrage)

# PARTIE 1 - Executer en premier
Rename-Computer -NewName "DC-02" -Force

$InterfaceIndex = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" }).ifIndex

New-NetIPAddress `
    -InterfaceIndex $InterfaceIndex `
    -IPAddress "10.30.0.201" `
    -PrefixLength 24 `
    -DefaultGateway "10.30.0.237"

Set-DnsClientServerAddress `
    -InterfaceIndex $InterfaceIndex `
    -ServerAddresses "10.30.0.200"

Set-ItemProperty `
    -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name "fDenyTSConnections" `
    -Value 0

Enable-NetFirewallRule -DisplayGroup "Bureau a distance"

$Password = ConvertTo-SecureString "admin1234**!" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential("LOSPOLLOS\Administrateur", $Password)

Add-Computer -DomainName "lospollos.local" -Credential $Credential -Restart -Force

# PARTIE 2 - Executer apres le redemarrage
# Se connecter avec LOSPOLLOS\Administrateur
# Decommentez les lignes ci-dessous et relancez

# Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose
#
# $Password = ConvertTo-SecureString "admin1234**!" -AsPlainText -Force
# $Credential = New-Object System.Management.Automation.PSCredential("LOSPOLLOS\Administrateur", $Password)
# $SafeModePassword = ConvertTo-SecureString "admin1234**!" -AsPlainText -Force
#
# Install-ADDSDomainController `
#     -DomainName "lospollos.local" `
#     -InstallDns:$true `
#     -Credential $Credential `
#     -SafeModeAdministratorPassword $SafeModePassword `
#     -Force:$true
