#!/bin/bash
# 05_elk.sh
# Deploiement de la stack ELK sur Debian 12

ELASTIC_PASSWORD="gejk33-uT1QNFK=zvmO7"
KIBANA_PASSWORD="gejk33-uT1QNFK=zvmO7"
SIEM_IP="10.30.0.220"
GATEWAY_IP="10.30.0.237"
DNS_IP="10.30.0.200"

INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${INTERFACE}
iface ${INTERFACE} inet static
    address ${SIEM_IP}
    netmask 255.255.255.0
    gateway ${GATEWAY_IP}
    dns-nameservers ${DNS_IP}
EOF

ifdown ${INTERFACE} 2>/dev/null; ifup ${INTERFACE} 2>/dev/null || true

apt update && apt upgrade -y
apt install -y wget curl gnupg apt-transport-https default-jdk openssh-server

systemctl enable ssh && systemctl start ssh

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
apt update

apt install -y elasticsearch
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch
sleep 20

apt install -y kibana

cat >> /etc/kibana/kibana.yml <<EOF
server.port: 5601
server.host: "0.0.0.0"
server.name: "lospollos-siem"
elasticsearch.hosts: ["https://localhost:9200"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "${KIBANA_PASSWORD}"
elasticsearch.ssl.verificationMode: none
EOF

# Reset du mot de passe kibana_system obligatoire
# Le mot de passe genere a l installation est different de celui configure dans kibana.yml
echo -e "${KIBANA_PASSWORD}\n${KIBANA_PASSWORD}" | /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system -i

systemctl daemon-reload
systemctl enable kibana
systemctl start kibana
sleep 15

apt install -y logstash

# Correctif critique : Elasticsearch 8 interprete winlog.event_data.param1 et param2
# comme des champs de type date ce qui provoque des erreurs d indexation status 400
# sur tous les evenements Windows de type System
# Solution : forcer ces champs en type string via filtre mutate
cat > /etc/logstash/conf.d/lospollos.conf <<EOF
input {
  beats {
    port => 5044
    ssl => false
  }
}

filter {
  mutate {
    convert => {
      "winlog.event_data.param1" => "string"
      "winlog.event_data.param2" => "string"
    }
  }
}

output {
  elasticsearch {
    hosts => ["https://localhost:9200"]
    user => "elastic"
    password => "${ELASTIC_PASSWORD}"
    ssl => true
    ssl_certificate_verification => false
    index => "lospollos-%{+YYYY.MM.dd}"
  }
}
EOF

systemctl daemon-reload
systemctl enable logstash
systemctl start logstash

echo "Kibana accessible sur http://${SIEM_IP}:5601"
echo "Login : elastic / ${ELASTIC_PASSWORD}"
