# 02_AD_config.ps1
# Configuration complete de l AD : OUs, Users, Groupes, Tiering, GPO
# A executer apres le redemarrage de 01_AD_setup.ps1
# Se connecter avec LOSPOLLOS\Administrateur

$Domain = "DC=lospollos,DC=local"

# OUs
New-ADOrganizationalUnit -Name "Tier0" -Path $Domain
New-ADOrganizationalUnit -Name "Tier1" -Path $Domain
New-ADOrganizationalUnit -Name "Tier2" -Path $Domain
Start-Sleep -Seconds 2
New-ADOrganizationalUnit -Name "Admins"       -Path "OU=Tier0,$Domain"
New-ADOrganizationalUnit -Name "Serveurs"     -Path "OU=Tier0,$Domain"
New-ADOrganizationalUnit -Name "Machines"     -Path "OU=Tier0,$Domain"
New-ADOrganizationalUnit -Name "Admins"       -Path "OU=Tier1,$Domain"
New-ADOrganizationalUnit -Name "Serveurs"     -Path "OU=Tier1,$Domain"
New-ADOrganizationalUnit -Name "Machines"     -Path "OU=Tier1,$Domain"
New-ADOrganizationalUnit -Name "Admins"       -Path "OU=Tier2,$Domain"
New-ADOrganizationalUnit -Name "Users"        -Path "OU=Tier2,$Domain"
New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Tier2,$Domain"
New-ADOrganizationalUnit -Name "Machines"     -Path "OU=Tier2,$Domain"
Write-Host "OUs creees" -ForegroundColor Green
Start-Sleep -Seconds 2

# Users Tier 0
$UsersT0 = @(
    @{ Name = "Walter White";     SamAccount = "w.white";       Password = "Tier0@dmin123!" },
    @{ Name = "Gustavo Fring";    SamAccount = "g.fring";       Password = "Tier0@dmin123!" },
    @{ Name = "Mike Ehrmantraut"; SamAccount = "m.ehrmantraut"; Password = "Tier0@dmin123!" }
)
foreach ($User in $UsersT0) {
    $Pass = ConvertTo-SecureString $User.Password -AsPlainText -Force
    New-ADUser -Name $User.Name -SamAccountName $User.SamAccount -AccountPassword $Pass `
        -Enabled $true -Path "OU=Admins,OU=Tier0,$Domain" -Description "Administrateur Tier 0"
    Write-Host "  [+] $($User.Name) cree" -ForegroundColor Green
}

# Users Tier 1
$UsersT1 = @(
    @{ Name = "Jesse Pinkman"; SamAccount = "j.pinkman";  Password = "Tier1@dmin123!" },
    @{ Name = "Saul Goodman";  SamAccount = "s.goodman";  Password = "Tier1@dmin123!" },
    @{ Name = "Hank Schrader"; SamAccount = "h.schrader"; Password = "Tier1@dmin123!" },
    @{ Name = "Lydia Rodarte"; SamAccount = "l.rodarte";  Password = "Tier1@dmin123!" }
)
foreach ($User in $UsersT1) {
    $Pass = ConvertTo-SecureString $User.Password -AsPlainText -Force
    New-ADUser -Name $User.Name -SamAccountName $User.SamAccount -AccountPassword $Pass `
        -Enabled $true -Path "OU=Admins,OU=Tier1,$Domain" -Description "Administrateur Tier 1"
    Write-Host "  [+] $($User.Name) cree" -ForegroundColor Green
}

# Users Tier 2
# Les users vont dans OU=Users et non OU=Workstations
# OU=Workstations est reservee aux objets ordinateurs
$UsersT2 = @(
    @{ Name = "Skyler White";    SamAccount = "s.white";     Password = "Tier2User123!" },
    @{ Name = "Marie Schrader";  SamAccount = "m.schrader";  Password = "Tier2User123!" },
    @{ Name = "Tuco Salamanca";  SamAccount = "t.salamanca"; Password = "Tier2User123!" },
    @{ Name = "Jane Margolis";   SamAccount = "j.margolis";  Password = "Tier2User123!" },
    @{ Name = "Ted Beneke";      SamAccount = "t.beneke";    Password = "Tier2User123!" },
    @{ Name = "Badger Mayhew";   SamAccount = "b.mayhew";    Password = "Tier2User123!" },
    @{ Name = "Skinny Pete";     SamAccount = "s.pete";      Password = "Tier2User123!" },
    @{ Name = "Andrea Cantillo"; SamAccount = "a.cantillo";  Password = "Tier2User123!" },
    @{ Name = "Combo Ortega";    SamAccount = "c.ortega";    Password = "Tier2User123!" },
    @{ Name = "Huell Babineaux"; SamAccount = "h.babineaux"; Password = "Tier2User123!" }
)
foreach ($User in $UsersT2) {
    $Pass = ConvertTo-SecureString $User.Password -AsPlainText -Force
    New-ADUser -Name $User.Name -SamAccountName $User.SamAccount -AccountPassword $Pass `
        -Enabled $true -Path "OU=Users,OU=Tier2,$Domain" -Description "Utilisateur standard Tier 2"
    Write-Host "  [+] $($User.Name) cree" -ForegroundColor Green
}
Write-Host "Users crees" -ForegroundColor Green
Start-Sleep -Seconds 2

# Groupes de securite
New-ADGroup -Name "Tier0-Admins" -GroupScope Global -Path "OU=Admins,OU=Tier0,$Domain"
New-ADGroup -Name "Tier1-Admins" -GroupScope Global -Path "OU=Admins,OU=Tier1,$Domain"
New-ADGroup -Name "Tier2-Admins" -GroupScope Global -Path "OU=Admins,OU=Tier2,$Domain"
Start-Sleep -Seconds 2
Add-ADGroupMember -Identity "Tier0-Admins" -Members "w.white","g.fring","m.ehrmantraut"
Add-ADGroupMember -Identity "Tier1-Admins" -Members "j.pinkman","s.goodman","h.schrader","l.rodarte"
Add-ADGroupMember -Identity "Tier2-Admins" -Members "s.white","m.schrader","t.salamanca","j.margolis","t.beneke","b.mayhew","s.pete","a.cantillo","c.ortega","h.babineaux"

# Tier0-Admins dans Admins du domaine pour acces RDP aux DCs
Add-ADGroupMember -Identity "Admins du domaine" -Members "Tier0-Admins"

Write-Host "Groupes crees et membres affectes" -ForegroundColor Green
Start-Sleep -Seconds 2

# GPO de cloisonnement Tiering
Import-Module GroupPolicy

New-GPO -Name "GPO-Tier0-Restrictions"
Set-GPRegistryValue -Name "GPO-Tier0-Restrictions" `
    -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "DontDisplayLockedUserId" -Type DWord -Value 3
New-GPLink -Name "GPO-Tier0-Restrictions" -Target "OU=Tier0,$Domain" -Enforced Yes

New-GPO -Name "GPO-Tier1-Restrictions"
Set-GPRegistryValue -Name "GPO-Tier1-Restrictions" `
    -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "DontDisplayLockedUserId" -Type DWord -Value 3
New-GPLink -Name "GPO-Tier1-Restrictions" -Target "OU=Tier1,$Domain" -Enforced Yes

New-GPO -Name "GPO-Tier2-Restrictions"
Set-GPRegistryValue -Name "GPO-Tier2-Restrictions" `
    -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "DontDisplayLockedUserId" -Type DWord -Value 3
New-GPLink -Name "GPO-Tier2-Restrictions" -Target "OU=Tier2,$Domain" -Enforced Yes

Start-Sleep -Seconds 2

$SIDTier1 = (Get-ADGroup "Tier1-Admins").SID.Value
$SIDTier2 = (Get-ADGroup "Tier2-Admins").SID.Value

Set-GPRegistryValue -Name "GPO-Tier1-Restrictions" `
    -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
    -ValueName "RestrictRemoteSAM" -Type String `
    -Value "O:BAG:BAD:(A;;RC;;;$SIDTier1)"

Set-GPRegistryValue -Name "GPO-Tier2-Restrictions" `
    -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
    -ValueName "RestrictRemoteSAM" -Type String `
    -Value "O:BAG:BAD:(A;;RC;;;$SIDTier2)"

Invoke-GPUpdate -Force
Write-Host "GPO configurees et appliquees" -ForegroundColor Green
