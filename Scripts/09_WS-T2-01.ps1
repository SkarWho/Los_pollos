# 09_WS-T2-01.ps1
# Deploiement de la Workstation Tier 2
# A executer sur une installation fraiche de Windows 11
#
# Prerequis Proxmox pour eviter les erreurs TPM/Secure Boot :
# Machine : q35
# BIOS : OVMF (UEFI)
# TPM : v2.0
# EFI Disk : active
#
# PARTIE 1 : configuration reseau + jonction domaine (redemarrage auto)
# PARTIE 2 : configuration RDP et groupes (apres redemarrage)

# PARTIE 1 - Executer en premier
$InterfaceIndex = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" }).ifIndex

New-NetIPAddress `
    -InterfaceIndex $InterfaceIndex `
    -IPAddress "10.30.0.210" `
    -PrefixLength 24 `
    -DefaultGateway "10.30.0.237"

Set-DnsClientServerAddress `
    -InterfaceIndex $InterfaceIndex `
    -ServerAddresses "10.30.0.200"

Set-ItemProperty `
    -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name "fDenyTSConnections" `
    -Value 0

Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

$Password = ConvertTo-SecureString "admin1234**!" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential("LOSPOLLOS\Administrateur", $Password)

Rename-Computer -NewName "WS-T2-01" -DomainCredential $Credential
Add-Computer -DomainName "lospollos.local" -Credential $Credential -Restart -Force

# PARTIE 2 - Executer apres le redemarrage
# Se connecter avec LOSPOLLOS\Administrateur
# Decommentez les lignes ci-dessous et relancez

# Ajouter les users Tier 2 au groupe Bureau a distance
# Add-LocalGroupMember -Group "Utilisateurs du Bureau a distance" -Member "LOSPOLLOS\Tier2-Admins"
#
# Deplacer la machine dans l OU Workstations Tier 2 depuis le DC-01 :
# Get-ADComputer -Identity "WS-T2-01" | Move-ADObject -TargetPath "OU=Workstations,OU=Tier2,DC=lospollos,DC=local"
