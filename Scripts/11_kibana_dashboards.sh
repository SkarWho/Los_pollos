#!/bin/bash
# 11_kibana_dashboards.sh
# Configuration complete du SIEM Kibana : alertes + dashboards
# Remplace et consolide : 10_kibana_alerts.sh
# A executer sur la VM SIEM apres 05_elk.sh
#
# Alertes creees (depuis 10_kibana_alerts.sh) :
#   Brute Force - Echecs de connexion (4625 > 5 en 5 min)
#   Creation de compte utilisateur (4720)
#   Modification groupe sensible (4728, 4731, 4735)
#
# Dashboards crees :
#   [LP] Vue d ensemble SIEM
#   [LP] Authentification & Brute Force
#   [LP] Gestion des comptes & Groupes AD
#   [LP] Bastion Guacamole - Acces et Sessions

KIBANA_URL="http://localhost:5601"
ELASTIC_PASSWORD="gejk33-uT1QNFK=zvmO7"
ENCRYPTION_KEY="LosPollosHermanos2026SecretKey32"
SIEM_IP="10.30.0.220"
NDJSON_FILE="/tmp/lospollos_dashboards.ndjson"

echo "=== Configuration SIEM Kibana - Los Pollos Hermanos ==="

# ─────────────────────────────────────────────────────────────────
# Cle de chiffrement obligatoire pour les alertes Kibana
# (depuis 10_kibana_alerts.sh)
# ─────────────────────────────────────────────────────────────────
if ! grep -q "xpack.encryptedSavedObjects.encryptionKey" /etc/kibana/kibana.yml; then
    echo "Ajout de la cle de chiffrement Kibana..."
    echo "xpack.encryptedSavedObjects.encryptionKey: \"${ENCRYPTION_KEY}\"" >> /etc/kibana/kibana.yml
    systemctl restart kibana
    echo "Attente redemarrage Kibana..."
    sleep 30
fi

echo "Attente Kibana..."
until curl -s -u "elastic:${ELASTIC_PASSWORD}" "${KIBANA_URL}/api/status" | grep -q '"level":"available"'; do
    sleep 5
done
echo "Kibana disponible."

# ─────────────────────────────────────────────────────────────────
# ALERTES (depuis 10_kibana_alerts.sh)
# ─────────────────────────────────────────────────────────────────
echo ""
echo "[1/3] Creation des alertes SIEM..."

# Alerte 1 : Brute Force (4625 > 5 en 5 minutes)
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
  }' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  [OK] Brute Force : id={d.get(\"id\",\"?\")}')" 2>/dev/null || echo "  [INFO] Alerte Brute Force deja existante ou erreur"

# Alerte 2 : Creation de compte (4720)
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
  }' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  [OK] Creation compte : id={d.get(\"id\",\"?\")}')" 2>/dev/null || echo "  [INFO] Alerte Creation compte deja existante ou erreur"

# Alerte 3 : Modification groupe sensible (4728, 4731, 4735)
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
  }' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  [OK] Modification groupe : id={d.get(\"id\",\"?\")}')" 2>/dev/null || echo "  [INFO] Alerte Modification groupe deja existante ou erreur"

echo "Alertes configurees."

# ─────────────────────────────────────────────────────────────────
# Generation du NDJSON via Python (evite les problemes d echappement)
# ─────────────────────────────────────────────────────────────────
python3 << 'PYEOF' > "$NDJSON_FILE"
import json

IP_ID = "lospollos-ip"
objects = []

# ── Index Pattern ──────────────────────────────────────────────
objects.append({
    "type": "index-pattern",
    "id": IP_ID,
    "attributes": {
        "title": "lospollos-*",
        "timeFieldName": "@timestamp"
    }
})

# ── Helper ────────────────────────────────────────────────────
def make_vis(vid, title, desc, vis_type, params, aggs, kql=""):
    vis_state = {"title": title, "type": vis_type, "params": params, "aggs": aggs}
    return {
        "type": "visualization",
        "id": vid,
        "attributes": {
            "title": title,
            "visState": json.dumps(vis_state),
            "uiStateJSON": "{}",
            "description": desc,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({
                    "index": IP_ID,
                    "query": {"query": kql, "language": "kuery"},
                    "filter": []
                })
            }
        },
        "references": [
            {"name": "kibanaSavedObjectMeta.searchSourceJSON.index",
             "type": "index-pattern", "id": IP_ID}
        ]
    }

def make_dash(did, title, desc, panels, refs, kql=""):
    return {
        "type": "dashboard",
        "id": did,
        "attributes": {
            "title": title,
            "description": desc,
            "panelsJSON": json.dumps(panels),
            "optionsJSON": json.dumps({"darkTheme": False, "hidePanelTitles": False, "useMargins": True}),
            "version": 1,
            "timeRestore": False,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({
                    "query": {"query": kql, "language": "kuery"},
                    "filter": []
                })
            }
        },
        "references": refs
    }

def panel(idx, vis_id, x, y, w, h):
    return {
        "panelIndex": str(idx),
        "gridData": {"x": x, "y": y, "w": w, "h": h, "i": str(idx)},
        "version": "8.17.0",
        "type": "visualization",
        "embeddableConfig": {},
        "panelRefName": f"panel_{idx}"
    }

def ref(idx, vis_id):
    return {"name": f"panel_{idx}", "type": "visualization", "id": vis_id}

# ══════════════════════════════════════════════════════════════
# VISUALISATIONS
# ══════════════════════════════════════════════════════════════

# VIS 1 : Timeline Authentifications (4624 succes vs 4625 echec)
objects.append(make_vis(
    "lp-vis-auth-timeline",
    "[LP] Authentifications - Succes vs Echec",
    "Comparaison des connexions reussies (4624) et echouees (4625) dans le temps",
    "histogram",
    {
        "addLegend": True, "addTooltip": True, "mode": "stacked",
        "legendPosition": "right", "times": [], "addTimeMarker": False
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}},
        {"id": "3", "enabled": True, "type": "filters", "schema": "group",
         "params": {"filters": [
             {"input": {"query": "event.code:4624", "language": "kuery"}, "label": "Succes (4624)"},
             {"input": {"query": "event.code:4625", "language": "kuery"}, "label": "Echec (4625)"}
         ]}}
    ],
    kql="event.code:4624 OR event.code:4625"
))

# VIS 2 : Top 10 utilisateurs avec echecs de connexion
objects.append(make_vis(
    "lp-vis-top-failed-users",
    "[LP] Top 10 utilisateurs - Echecs de connexion (4625)",
    "Comptes avec le plus d echecs d authentification - indicateur brute force",
    "table",
    {
        "perPage": 10, "showPartialRows": False,
        "showMetricsAtAllLevels": False, "showTotal": True,
        "totalFunc": "sum"
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {
             "field": "winlog.event_data.TargetUserName",
             "size": 10, "order": "desc", "orderBy": "1",
             "otherBucket": False, "missingBucket": False,
             "customLabel": "Utilisateur"
         }}
    ],
    kql="event.code:4625"
))

# VIS 3 : Compteur echecs 24h (metrique avec couleurs)
objects.append(make_vis(
    "lp-vis-bruteforce-metric",
    "[LP] Echecs de connexion - Compteur (24h)",
    "Nombre total d echecs de connexion - rouge si > 20",
    "metric",
    {
        "addLegend": False,
        "addTooltip": True,
        "metric": {
            "colorSchema": "Green to Red",
            "colorsRange": [
                {"from": 0, "to": 5},
                {"from": 5, "to": 20},
                {"from": 20, "to": 100000}
            ],
            "invertColors": False,
            "labels": {"show": True},
            "metricColorMode": "Background",
            "percentageMode": False,
            "style": {"bgColor": False, "bgFill": "#000", "fontSize": 60, "labelColor": False},
            "useRanges": True
        }
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}}
    ],
    kql="event.code:4625"
))

# VIS 4 : Timeline evenements gestion des comptes
objects.append(make_vis(
    "lp-vis-account-events",
    "[LP] Gestion des comptes AD - Timeline",
    "Creation (4720), suppression (4726), activation (4722), desactivation (4725), verrouillage (4740)",
    "histogram",
    {
        "addLegend": True, "addTooltip": True, "mode": "stacked",
        "legendPosition": "right", "times": [], "addTimeMarker": False
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}},
        {"id": "3", "enabled": True, "type": "filters", "schema": "group",
         "params": {"filters": [
             {"input": {"query": "event.code:4720", "language": "kuery"}, "label": "Creation (4720)"},
             {"input": {"query": "event.code:4726", "language": "kuery"}, "label": "Suppression (4726)"},
             {"input": {"query": "event.code:4722", "language": "kuery"}, "label": "Activation (4722)"},
             {"input": {"query": "event.code:4725", "language": "kuery"}, "label": "Desactivation (4725)"},
             {"input": {"query": "event.code:4740", "language": "kuery"}, "label": "Verrouillage (4740)"}
         ]}}
    ],
    kql="event.code:4720 OR event.code:4726 OR event.code:4722 OR event.code:4725 OR event.code:4740"
))

# VIS 5 : Modifications groupes AD (table avec groupe cible et membre)
objects.append(make_vis(
    "lp-vis-group-changes",
    "[LP] Modifications groupes AD (4728/4729/4731/4732/4735/4756)",
    "Ajout et suppression de membres dans les groupes de securite - focus Tier0-Admins et Tier1-Admins",
    "table",
    {
        "perPage": 10, "showPartialRows": False,
        "showMetricsAtAllLevels": False, "showTotal": True,
        "totalFunc": "sum"
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {
             "field": "winlog.event_data.TargetUserName",
             "size": 10, "order": "desc", "orderBy": "1",
             "customLabel": "Groupe cible"
         }},
        {"id": "3", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {
             "field": "winlog.event_data.MemberName",
             "size": 5, "order": "desc", "orderBy": "1",
             "customLabel": "Membre ajoute/supprime"
         }}
    ],
    kql="event.code:4728 OR event.code:4729 OR event.code:4731 OR event.code:4732 OR event.code:4735 OR event.code:4756"
))

# VIS 6 : Timeline acces bastion Guacamole
objects.append(make_vis(
    "lp-vis-guacamole-timeline",
    "[LP] Acces Bastion Guacamole - Timeline",
    "Volume d acces au bastion Guacamole (logs Tomcat via Filebeat - fields.source:guacamole)",
    "histogram",
    {
        "addLegend": True, "addTooltip": True, "mode": "stacked",
        "legendPosition": "right", "times": [], "addTimeMarker": False
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "date_histogram", "schema": "segment",
         "params": {"field": "@timestamp", "interval": "auto", "min_doc_count": 1}}
    ],
    kql="fields.source:guacamole"
))

# VIS 7 : Connexions comptes privilegies Tier 0
objects.append(make_vis(
    "lp-vis-priv-logons",
    "[LP] Connexions comptes Tier 0 (4624)",
    "Suivi des authentifications des admins Tier 0 : w.white, g.fring, m.ehrmantraut",
    "table",
    {
        "perPage": 15, "showPartialRows": False,
        "showMetricsAtAllLevels": False, "showTotal": True,
        "totalFunc": "sum"
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {
             "field": "winlog.event_data.TargetUserName",
             "size": 10, "order": "desc", "orderBy": "1",
             "customLabel": "Compte Tier 0"
         }},
        {"id": "3", "enabled": True, "type": "terms", "schema": "bucket",
         "params": {
             "field": "winlog.event_data.WorkstationName",
             "size": 5, "order": "desc", "orderBy": "1",
             "customLabel": "Machine source"
         }}
    ],
    kql="event.code:4624 AND (winlog.event_data.TargetUserName:w.white OR winlog.event_data.TargetUserName:g.fring OR winlog.event_data.TargetUserName:m.ehrmantraut)"
))

# VIS 8 : Repartition par canal Windows (pie)
objects.append(make_vis(
    "lp-vis-events-by-channel",
    "[LP] Repartition evenements par canal Windows",
    "Distribution Security / System / Application des logs collectes par Winlogbeat",
    "pie",
    {
        "addLegend": True, "addTooltip": True,
        "isDonut": True, "legendPosition": "right"
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {
             "field": "winlog.channel",
             "size": 5, "order": "desc", "orderBy": "1"
         }}
    ]
))

# VIS 9 : Top 10 Event IDs (barre horizontale)
objects.append(make_vis(
    "lp-vis-top-event-codes",
    "[LP] Top 10 Event IDs Windows",
    "Les 10 event IDs les plus frequents - utile pour identifier les activites dominantes",
    "horizontal_bar",
    {
        "addLegend": True, "addTooltip": True, "legendPosition": "right",
        "categoryAxes": [{
            "id": "CategoryAxis-1", "type": "category",
            "position": "left", "show": True, "style": {},
            "scale": {"type": "linear"},
            "labels": {"show": True, "rotate": 0},
            "title": {}
        }],
        "valueAxes": [{
            "id": "ValueAxis-1", "name": "LeftAxis-1",
            "type": "value", "position": "bottom", "show": True,
            "style": {}, "scale": {"type": "linear", "mode": "normal"},
            "labels": {"show": True, "rotate": 0, "filter": True, "truncate": 100},
            "title": {"text": "Nombre d evenements"}
        }],
        "seriesParams": [{
            "show": True, "type": "histogram", "mode": "stacked",
            "data": {"label": "Count", "id": "1"},
            "valueAxis": "ValueAxis-1",
            "drawLinesBetweenPoints": True
        }]
    },
    [
        {"id": "1", "enabled": True, "type": "count", "schema": "metric", "params": {}},
        {"id": "2", "enabled": True, "type": "terms", "schema": "segment",
         "params": {
             "field": "event.code",
             "size": 10, "order": "desc", "orderBy": "1",
             "customLabel": "Event ID"
         }}
    ]
))

# ══════════════════════════════════════════════════════════════
# DASHBOARDS
# ══════════════════════════════════════════════════════════════

# DASH 1 : Vue d ensemble SIEM
objects.append(make_dash(
    "lp-dash-overview",
    "[LP] Vue d ensemble SIEM",
    "Dashboard global Los Pollos Hermanos - Vue de haut niveau sur tous les evenements de securite",
    [
        panel(1, "lp-vis-auth-timeline",      x=0,  y=0,  w=36, h=15),
        panel(2, "lp-vis-bruteforce-metric",  x=36, y=0,  w=12, h=8),
        panel(3, "lp-vis-events-by-channel",  x=36, y=8,  w=12, h=7),
        panel(4, "lp-vis-top-event-codes",    x=0,  y=15, w=24, h=15),
        panel(5, "lp-vis-top-failed-users",   x=24, y=15, w=24, h=15),
    ],
    [
        ref(1, "lp-vis-auth-timeline"),
        ref(2, "lp-vis-bruteforce-metric"),
        ref(3, "lp-vis-events-by-channel"),
        ref(4, "lp-vis-top-event-codes"),
        ref(5, "lp-vis-top-failed-users"),
    ]
))

# DASH 2 : Authentification & Brute Force
objects.append(make_dash(
    "lp-dash-auth",
    "[LP] Authentification & Brute Force",
    "Suivi des connexions, echecs d authentification, detection brute force et activite des comptes privilegies",
    [
        panel(1, "lp-vis-bruteforce-metric",  x=0,  y=0,  w=12, h=8),
        panel(2, "lp-vis-top-failed-users",   x=12, y=0,  w=36, h=8),
        panel(3, "lp-vis-auth-timeline",      x=0,  y=8,  w=28, h=15),
        panel(4, "lp-vis-priv-logons",        x=28, y=8,  w=20, h=15),
    ],
    [
        ref(1, "lp-vis-bruteforce-metric"),
        ref(2, "lp-vis-top-failed-users"),
        ref(3, "lp-vis-auth-timeline"),
        ref(4, "lp-vis-priv-logons"),
    ]
))

# DASH 3 : Gestion des comptes & Groupes AD
objects.append(make_dash(
    "lp-dash-accounts",
    "[LP] Gestion des comptes & Groupes AD",
    "Creation, modification et suppression de comptes et groupes Active Directory - modele Tier 0/1/2",
    [
        panel(1, "lp-vis-account-events",  x=0,  y=0,  w=48, h=15),
        panel(2, "lp-vis-group-changes",   x=0,  y=15, w=48, h=15),
    ],
    [
        ref(1, "lp-vis-account-events"),
        ref(2, "lp-vis-group-changes"),
    ]
))

# DASH 4 : Bastion Guacamole
objects.append(make_dash(
    "lp-dash-guacamole",
    "[LP] Bastion Guacamole - Acces et Sessions",
    "Suivi des acces RDP/SSH via le bastion Apache Guacamole (logs Tomcat via Filebeat)",
    [
        panel(1, "lp-vis-guacamole-timeline",  x=0, y=0, w=48, h=20),
    ],
    [
        ref(1, "lp-vis-guacamole-timeline"),
    ],
    kql="fields.source:guacamole"
))

# ── Ecriture NDJSON ──────────────────────────────────────────
for obj in objects:
    print(json.dumps(obj))

PYEOF

OBJECT_COUNT=$(wc -l < "$NDJSON_FILE")
echo ""
echo "[2/3] Generation et import des dashboards..."
echo "NDJSON genere : ${OBJECT_COUNT} objets (1 index pattern + 9 visualisations + 4 dashboards)"

# ─────────────────────────────────────────────────────────────────
# Import via l API Saved Objects
# ─────────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Import des dashboards dans Kibana..."

IMPORT_RESULT=$(curl -s -u "elastic:${ELASTIC_PASSWORD}" \
  -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -F "file=@${NDJSON_FILE}")

SUCCESS_COUNT=$(echo "$IMPORT_RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('successCount', '?'))
" 2>/dev/null)

ERRORS=$(echo "$IMPORT_RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
errs = d.get('errors', [])
if errs:
    for e in errs:
        print(f'  ERREUR [{e.get(\"type\",\"?\")}] {e.get(\"id\",\"?\")} : {e.get(\"error\",{}).get(\"message\",\"?\")}')
else:
    print('  Aucune erreur.')
" 2>/dev/null)

echo ""
echo "=== Resultat ==="
echo "  Objets importes : ${SUCCESS_COUNT} / ${OBJECT_COUNT}"
echo "$ERRORS"

echo ""
echo "=== Dashboards disponibles dans Kibana ==="
echo "  URL : http://${SIEM_IP}:5601"
echo "  Navigation : Menu > Analytics > Dashboards"
echo "  Filtrer par : [LP]"
echo ""
echo "  [LP] Vue d ensemble SIEM"
echo "       -> Timeline auth, Top event IDs, Repartition canaux, Top echecs"
echo ""
echo "  [LP] Authentification & Brute Force"
echo "       -> Compteur echecs (rouge > 20), Top users 4625, Timeline 4624 vs 4625, Comptes Tier 0"
echo ""
echo "  [LP] Gestion des comptes & Groupes AD"
echo "       -> Timeline 4720/4722/4725/4726/4740, Tableau modifications groupes"
echo ""
echo "  [LP] Bastion Guacamole - Acces et Sessions"
echo "       -> Timeline des acces via le bastion (fields.source:guacamole)"
echo ""
echo "Note : ajuster la plage de temps en haut a droite de Kibana si les dashboards"
echo "       semblent vides (les donnees peuvent etre sur les dernieres 15 min ou 24h)."

rm -f "$NDJSON_FILE"
