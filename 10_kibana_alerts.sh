#!/bin/bash
# 10_kibana_alerts.sh
# Creation des alertes SIEM dans Kibana via l API REST
# A executer sur la VM SIEM apres 05_elk.sh

KIBANA_URL="http://localhost:5601"
ELASTIC_PASSWORD="gejk33-uT1QNFK=zvmO7"
ENCRYPTION_KEY="LosPollosHermanos2026SecretKey32"

# Ajout de la cle de chiffrement obligatoire pour les alertes Kibana
echo "xpack.encryptedSavedObjects.encryptionKey: \"${ENCRYPTION_KEY}\"" >> /etc/kibana/kibana.yml
systemctl restart kibana
echo "Attente redemarrage Kibana..."
sleep 30

# Alerte 1 : Brute Force
# Declenchement si plus de 5 echecs de connexion (event 4625) en 5 minutes
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "${KIBANA_URL}/api/alerting/rule" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Brute Force - Echecs de connexion",
    "rule_type_id": ".es-query",
    "consumer": "alerts",
    "schedule": { "interval": "1m" },
    "params": {
      "index": ["lospollos-*"],
      "timeField": "@timestamp",
      "esQuery": "{\"query\":{\"match\":{\"event.code\":\"4625\"}}}",
      "size": 100,
      "threshold": [5],
      "thresholdComparator": ">",
      "timeWindowSize": 5,
      "timeWindowUnit": "m",
      "searchType": "esQuery"
    },
    "actions": []
  }' | python3 -m json.tool | grep '"id"\|"name"\|"enabled"'

echo "Alerte Brute Force creee"

# Alerte 2 : Creation de compte utilisateur
# Declenchement sur tout event 4720 (creation de compte)
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "${KIBANA_URL}/api/alerting/rule" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Creation de compte utilisateur",
    "rule_type_id": ".es-query",
    "consumer": "alerts",
    "schedule": { "interval": "1m" },
    "params": {
      "index": ["lospollos-*"],
      "timeField": "@timestamp",
      "esQuery": "{\"query\":{\"match\":{\"event.code\":\"4720\"}}}",
      "size": 100,
      "threshold": [0],
      "thresholdComparator": ">",
      "timeWindowSize": 1,
      "timeWindowUnit": "m",
      "searchType": "esQuery"
    },
    "actions": []
  }' | python3 -m json.tool | grep '"id"\|"name"\|"enabled"'

echo "Alerte Creation de compte creee"

# Alerte 3 : Modification groupe sensible
# Declenchement sur events 4728, 4731, 4735 (modifications de groupes AD)
curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "${KIBANA_URL}/api/alerting/rule" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Modification groupe sensible",
    "rule_type_id": ".es-query",
    "consumer": "alerts",
    "schedule": { "interval": "5m" },
    "params": {
      "index": ["lospollos-*"],
      "timeField": "@timestamp",
      "esQuery": "{\"query\":{\"bool\":{\"should\":[{\"match\":{\"event.code\":\"4728\"}},{\"match\":{\"event.code\":\"4731\"}},{\"match\":{\"event.code\":\"4735\"}}]}}}",
      "size": 100,
      "threshold": [0],
      "thresholdComparator": ">",
      "timeWindowSize": 5,
      "timeWindowUnit": "m",
      "searchType": "esQuery"
    },
    "actions": []
  }' | python3 -m json.tool | grep '"id"\|"name"\|"enabled"'

echo "Alerte Modification groupe creee"
echo "Les 3 alertes SIEM sont configurees dans Kibana"
