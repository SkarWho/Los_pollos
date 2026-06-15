# 12_winlogbeat_extended.ps1
# Installation et configuration complete de Winlogbeat sur DC-01 et DC-02
# Remplace et consolide : 07_winlogbeat_dc.ps1
# A executer sur les deux DCs apres 01_AD_setup.ps1 / 02_AD_config.ps1
#
# Prerequis : telecharger winlogbeat depuis le SIEM
#   Sur la VM SIEM : python3 -m http.server 8888
#   Sur le DC      : wget http://10.30.0.220:8888/winlogbeat-8.17.4-windows-x86_64.zip -OutFile winlogbeat.zip
#
# Canaux collectes (etend 07_winlogbeat_dc.ps1) :
#   Security (filtre sur event IDs pertinents)
#   Application, System
#   Microsoft-Windows-PowerShell/Operational  (4103, 4104 - commandes PS)
#   Microsoft-Windows-Windows Defender/Operational (1116-1119 - malware)
#   Microsoft-Windows-TaskScheduler/Operational (4698-4702 - persistance)
#
# Event IDs Windows couverts :
#   4624  Connexion reussie
#   4625  Echec connexion (brute force)
#   4634  Deconnexion
#   4648  Connexion avec credentials explicites (Pass-the-Hash)
#   4720  Creation de compte
#   4722  Activation de compte
#   4725  Desactivation de compte
#   4726  Suppression de compte
#   4728  Ajout membre groupe securite global
#   4729  Suppression membre groupe securite global
#   4732  Ajout membre groupe securite local
#   4733  Suppression membre groupe securite local
#   4740  Verrouillage de compte
#   4756  Ajout membre groupe securite universel
#   4768  Demande ticket Kerberos TGT
#   4769  Demande ticket de service Kerberos
#   4771  Echec pre-auth Kerberos (brute force Kerberos)
#   4776  Tentative authentification NTLM

$LOGSTASH_IP = "10.30.0.220"
$WINLOGBEAT_DIR = "C:\Program Files\Winlogbeat\winlogbeat-8.17.4-windows-x86_64"

# ─────────────────────────────────────────────────────────────────
# PARTIE 1 : Installation Winlogbeat (depuis 07_winlogbeat_dc.ps1)
# ─────────────────────────────────────────────────────────────────
if (-Not (Test-Path "$WINLOGBEAT_DIR\winlogbeat.exe")) {
    Write-Host "[1/3] Installation de Winlogbeat..." -ForegroundColor Cyan

    if (-Not (Test-Path "winlogbeat.zip")) {
        Write-Host "  [ERREUR] winlogbeat.zip introuvable dans le repertoire courant." -ForegroundColor Red
        Write-Host "  Telecharger depuis le SIEM :"
        Write-Host "    wget http://${LOGSTASH_IP}:8888/winlogbeat-8.17.4-windows-x86_64.zip -OutFile winlogbeat.zip"
        exit 1
    }

    Expand-Archive winlogbeat.zip -DestinationPath "C:\Program Files\Winlogbeat" -Force
    Write-Host "  [OK] Winlogbeat extrait dans C:\Program Files\Winlogbeat" -ForegroundColor Green

    # Installation du service Windows
    Set-Location $WINLOGBEAT_DIR
    PowerShell -ExecutionPolicy Bypass -File ".\install-service-winlogbeat.ps1"
    Write-Host "  [OK] Service Winlogbeat installe" -ForegroundColor Green
} else {
    Write-Host "[1/3] Winlogbeat deja installe - mise a jour de la configuration uniquement." -ForegroundColor Yellow
}

$Config = @"
winlogbeat.event_logs:
  # Canaux standards
  - name: Application
  - name: System

  # Securite - tous les evenements (filtre possible via event_id)
  - name: Security
    event_id: 4624, 4625, 4634, 4648, 4720, 4722, 4725, 4726,
              4728, 4729, 4731, 4732, 4733, 4735, 4740, 4756,
              4768, 4769, 4771, 4776

  # PowerShell - journalisation des commandes (detection living-off-the-land)
  - name: Microsoft-Windows-PowerShell/Operational
    event_id: 4103, 4104

  # Windows Defender - alertes antivirus
  - name: Microsoft-Windows-Windows Defender/Operational
    event_id: 1116, 1117, 1118, 1119

  # Taches planifiees - detection de persistance
  - name: Microsoft-Windows-TaskScheduler/Operational
    event_id: 4698, 4699, 4700, 4702

output.logstash:
  hosts: ["${LOGSTASH_IP}:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: C:\ProgramData\winlogbeat\Logs
"@

$ConfigPath = "$WINLOGBEAT_DIR\winlogbeat.yml"

# ─────────────────────────────────────────────────────────────────
# PARTIE 2 : Configuration etendue (remplace 07_winlogbeat_dc.ps1)
# ─────────────────────────────────────────────────────────────────
Write-Host "[2/3] Application de la configuration Winlogbeat etendue..." -ForegroundColor Cyan
Set-Content -Path $ConfigPath -Value $Config

# Validation de la configuration
Write-Host "Validation de la configuration..." -ForegroundColor Cyan
$TestResult = & "$WINLOGBEAT_DIR\winlogbeat.exe" test config -c $ConfigPath 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Configuration valide" -ForegroundColor Green
} else {
    Write-Host "  [ERREUR] Configuration invalide :" -ForegroundColor Red
    Write-Host $TestResult
    exit 1
}

# ─────────────────────────────────────────────────────────────────
# PARTIE 3 : Demarrage / redemarrage du service
# ─────────────────────────────────────────────────────────────────
Write-Host "[3/3] Demarrage du service Winlogbeat..." -ForegroundColor Cyan

$ServiceExists = Get-Service winlogbeat -ErrorAction SilentlyContinue
if ($ServiceExists) {
    Restart-Service winlogbeat
} else {
    Start-Service winlogbeat
}
Start-Sleep -Seconds 5

$Status = (Get-Service winlogbeat).Status
Write-Host "  Statut : $Status" -ForegroundColor $(if ($Status -eq "Running") {"Green"} else {"Red"})

Write-Host ""
Write-Host "=== Canaux collectes ===" -ForegroundColor Green
Write-Host "  Security          : 4624, 4625, 4634, 4648, 4720-4726, 4728-4740, 4768-4776"
Write-Host "  PowerShell/Ops    : 4103 (module logging), 4104 (script block logging)"
Write-Host "  Windows Defender  : 1116 (malware detecte), 1117 (action malware)"
Write-Host "  TaskScheduler/Ops : 4698/4702 (creation/modif tache planifiee)"
Write-Host ""
Write-Host "Dans Kibana, ces evenements apparaitront dans l index lospollos-* sous 24h."
Write-Host "Pour les rechercher :"
Write-Host "  PowerShell  -> winlog.channel:\"Microsoft-Windows-PowerShell/Operational\""
Write-Host "  Defender    -> winlog.channel:\"Microsoft-Windows-Windows Defender/Operational\""
Write-Host "  Kerberos    -> event.code:4768 OR event.code:4769 OR event.code:4771"
