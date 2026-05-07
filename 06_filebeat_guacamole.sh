#!/bin/bash
# 06_filebeat_guacamole.sh
# Installation Filebeat sur la VM Guacamole
# pour envoyer les logs du bastion vers Logstash

LOGSTASH_IP="10.30.0.220"

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
apt update
apt install -y filebeat

mv /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak

cat > /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /opt/tomcat9/logs/catalina.out
      - /opt/tomcat9/logs/localhost_access_log*.txt
    fields:
      source: guacamole
      type: bastion

output.logstash:
  hosts: ["${LOGSTASH_IP}:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
EOF

systemctl enable filebeat
systemctl start filebeat

echo "Filebeat demarre - logs Guacamole envoyes vers ${LOGSTASH_IP}:5044"
echo "Dans Kibana filtrer avec : fields.source : guacamole"
