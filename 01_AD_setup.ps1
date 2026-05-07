# 01_AD_setup.ps1
# Deploiement du Domain Controller principal - DC-01
# A executer sur une installation fraiche de Windows Server 2019
# La machine redemarrera automatiquement a la fin
# Apres le redemarrage, executer 02_AD_config.ps1

$DomainName = "lospollos.local"
$NetbiosName = "LOSPOLLOS"
$SafeModePassword = ConvertTo-SecureString "admin1234**!" -AsPlainText -Force

Rename-Computer -NewName "DC-01" -Force

$InterfaceIndex = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" }).ifIndex

New-NetIPAddress `
    -InterfaceIndex $InterfaceIndex `
    -IPAddress "10.30.0.200" `
    -PrefixLength 24 `
    -DefaultGateway "10.30.0.237"

Set-DnsClientServerAddress `
    -InterfaceIndex $InterfaceIndex `
    -ServerAddresses "127.0.0.1"

Set-ItemProperty `
    -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name "fDenyTSConnections" `
    -Value 0

Enable-NetFirewallRule -DisplayGroup "Bureau a distance"

Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools -Verbose

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -SafeModeAdministratorPassword $SafeModePassword `
    -InstallDns:$true `
    -Force:$true `
    -Verbose
