# 07_winlogbeat_dc.ps1
# Installation Winlogbeat sur DC-01 et DC-02
# A executer sur les deux DCs
#
# Prerequis : telecharger winlogbeat depuis le SIEM
# Sur la VM SIEM : python3 -m http.server 8888
# Sur le DC :
# wget http://10.30.0.220:8888/winlogbeat-8.17.4-windows-x86_64.zip -OutFile winlogbeat.zip

$LOGSTASH_IP = "10.30.0.220"
$WINLOGBEAT_DIR = "C:\Program Files\Winlogbeat\winlogbeat-8.17.4-windows-x86_64"

Expand-Archive winlogbeat.zip -DestinationPath "C:\Program Files\Winlogbeat" -Force

$Config = @"
winlogbeat.event_logs:
  - name: Application
  - name: System
  - name: Security

output.logstash:
  hosts: ["${LOGSTASH_IP}:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: C:\ProgramData\winlogbeat\Logs
"@

Set-Content -Path "$WINLOGBEAT_DIR\winlogbeat.yml" -Value $Config

Set-Location $WINLOGBEAT_DIR
.\install-service-winlogbeat.ps1
Start-Service winlogbeat
Get-Service winlogbeat
