# Procédure SIEM — Los Pollos Hermanos

## 1. Déploiement des scripts

Exécuter dans l'ordre suivant :

| Étape | Script | Où | Ce que ça fait |
|-------|--------|----|----------------|
| 1 | `01_AD_setup.ps1` | DC-01 | Installe AD DS, redémarre |
| 2 | `02_AD_config.ps1` | DC-01 | OUs, users, groupes, GPO |
| 3 | `03_guacamole.sh` | VM Guacamole | Installe Apache Guacamole |
| 4 | `04_guacamole_setup.sql` | VM Guacamole | Connexions RDP/SSH dans Guacamole |
| 5 | `05_elk.sh` | VM SIEM | Installe Elasticsearch + Kibana + Logstash |
| 6 | `06_filebeat_guacamole.sh` | VM Guacamole | Envoie les logs Guacamole vers le SIEM |
| 7 | `12_winlogbeat_extended.ps1` | DC-01 **et** DC-02 | Installe Winlogbeat + config étendue *(remplace 07)* |
| 8 | `08_DC02.ps1` | DC-02 | Réplication AD sur le second DC |
| 9 | `09_WS-T2-01.ps1` | WS-T2-01 | Jonction domaine Workstation Tier 2 |
| 10 | `11_kibana_dashboards.sh` | VM SIEM | Crée les alertes + dashboards Kibana *(remplace 10)* |

---

## 2. Accès à Kibana

```
URL      : http://10.30.0.220:5601
Login    : elastic
Password : gejk33-uT1QNFK=zvmO7
```

Dashboards : **Menu → Analytics → Dashboards** — filtrer par `[LP]`

---

## 3. Générer des événements de test

### 3.1 Brute Force — Échecs de connexion (Event 4625)

Depuis **WS-T2-01** ou n'importe quelle machine du domaine, tenter 6+ connexions avec un mauvais mot de passe :

```powershell
# Depuis PowerShell sur WS-T2-01
# Répéter 6 fois pour déclencher l'alerte (seuil : 5 en 5 min)
$cred = New-Object System.Management.Automation.PSCredential(
    "LOSPOLLOS\w.white",
    (ConvertTo-SecureString "mauvaismdp" -AsPlainText -Force)
)
Start-Process cmd -Credential $cred -ErrorAction SilentlyContinue
```

Ou via `runas` en ligne de commande :
```cmd
runas /user:LOSPOLLOS\w.white cmd
# Entrer un mauvais mot de passe → répéter 6 fois
```

**Dashboard** : `[LP] Authentification & Brute Force` → compteur rouge, pic sur la timeline.  
**Alerte** : visible dans **Menu → Alerts** au bout de 1 minute.

---

### 3.2 Création de compte utilisateur (Event 4720)

Depuis **DC-01**, connecté en tant que `LOSPOLLOS\Administrateur` :

```powershell
New-ADUser -Name "Test Heisenberg" `
    -SamAccountName "t.heisenberg" `
    -AccountPassword (ConvertTo-SecureString "Test@1234!" -AsPlainText -Force) `
    -Enabled $true `
    -Path "OU=Users,OU=Tier2,DC=lospollos,DC=local"
```

**Dashboard** : `[LP] Gestion des comptes & Groupes AD` → barre "Création (4720)".  
**Alerte** : visible dans **Menu → Alerts** au bout de 1 minute.

---

### 3.3 Modification d'un groupe sensible (Events 4728 / 4735)

Depuis **DC-01** :

```powershell
# Ajouter un utilisateur Tier 2 dans Tier0-Admins (mouvement latéral simulé)
Add-ADGroupMember -Identity "Tier0-Admins" -Members "t.salamanca"

# Attendre quelques secondes puis retirer pour remettre en état
Remove-ADGroupMember -Identity "Tier0-Admins" -Members "t.salamanca" -Confirm:$false
```

**Dashboard** : `[LP] Gestion des comptes & Groupes AD` → tableau "Modifications groupes".  
**Alerte** : visible dans **Menu → Alerts** au bout de 5 minutes.

---

### 3.4 Connexion d'un compte Tier 0 (Event 4624)

Se connecter en RDP ou localement avec un compte Tier 0 depuis une machine non autorisée :

```powershell
# Depuis WS-T2-01 — connexion avec compte Tier 0 (violation tiering)
mstsc /v:DC-01 /u:LOSPOLLOS\g.fring
```

**Dashboard** : `[LP] Authentification & Brute Force` → tableau "Connexions comptes Tier 0".

---

### 3.5 Accès via le bastion Guacamole (logs Tomcat)

Se connecter à Guacamole depuis un navigateur et ouvrir une session RDP ou SSH :

```
URL      : http://<IP-Guacamole>:8080/guacamole
Login    : guacadmin / guacadmin  (ou compte AD si SSO configuré)
```

Naviguer vers une connexion existante → ouvrir et fermer la session.

**Dashboard** : `[LP] Bastion Guacamole - Accès et Sessions` → pic sur la timeline.

---

## 4. Délai d'apparition dans Kibana

| Source | Délai typique |
|--------|--------------|
| Winlogbeat (DCs) | 10 à 30 secondes |
| Filebeat (Guacamole) | 10 à 30 secondes |
| Alertes Kibana | 1 à 5 minutes (selon l'intervalle de la règle) |

Si les dashboards semblent vides : ajuster la plage de temps en haut à droite de Kibana (`Last 1 hour` ou `Last 24 hours`).

---

## 5. Vérification rapide de la chaîne

```bash
# Sur la VM SIEM — vérifier que les index reçoivent des données
curl -s -u "elastic:gejk33-uT1QNFK=zvmO7" \
  "https://localhost:9200/lospollos-*/_count" \
  --insecure | python3 -m json.tool

# Résultat attendu : { "count": N, ... }  avec N > 0
```

```bash
# Vérifier les services
systemctl status elasticsearch kibana logstash
```

```powershell
# Sur les DCs — vérifier Winlogbeat
Get-Service winlogbeat
```
