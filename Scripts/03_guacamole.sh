#!/bin/bash
# 03_guacamole.sh
# Deploiement complet du Bastion Guacamole sur Debian 12
# Inclut : Guacamole + Tomcat 9 + MariaDB + JDBC + LDAP

GUAC_VERSION="1.5.5"
TOMCAT_VERSION="9.0.102"
GUAC_HOME="/usr/share/tomcat10/.guacamole"
TOMCAT_DIR="/opt/tomcat9"
BASTION_IP="10.30.0.240"
DC_IP="10.30.0.200"
GATEWAY_IP="10.30.0.237"
DNS_IP="10.30.0.200"
DB_PASSWORD="Guac@db123!"

INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ${INTERFACE}
iface ${INTERFACE} inet static
    address ${BASTION_IP}
    netmask 255.255.255.0
    gateway ${GATEWAY_IP}
    dns-nameservers ${DNS_IP}
EOF

ifdown ${INTERFACE} 2>/dev/null; ifup ${INTERFACE} 2>/dev/null || true

apt update && apt upgrade -y

apt install -y \
    build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev \
    libtool-bin uuid-dev libossp-uuid-dev libavcodec-dev libavformat-dev \
    libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev \
    libtelnet-dev libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
    libvorbis-dev libwebp-dev ghostscript default-jdk wget openssh-server \
    mariadb-server libmariadb-java

systemctl enable ssh mariadb
systemctl start ssh mariadb

# Base de donnees Guacamole
mysql -u root <<SQLEOF
CREATE DATABASE guacamole_db CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER 'guacamole_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

# Compilation et installation de guacd
cd /root || exit
wget -q https://archive.apache.org/dist/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz
cd guacamole-server-${GUAC_VERSION} || exit
./configure --with-init-dir=/etc/init.d
make && make install
ldconfig

# Correctif : guacd ecoute sur ::1 (IPv6) par defaut
# Guacamole se connecte sur 127.0.0.1 (IPv4) -> connexion refusee sans ce correctif
sed -i 's|getpid > /dev/null || $exec -p "$pidfile"|getpid > /dev/null || $exec -b 127.0.0.1 -p "$pidfile"|g' /etc/init.d/guacd

systemctl daemon-reload
systemctl enable guacd
systemctl start guacd

# Correctif : Tomcat 10 est incompatible avec Guacamole 1.5.5
# Tomcat 10 utilise jakarta.servlet, Guacamole 1.5.5 utilise javax.servlet
# Erreur : NoClassDefFoundError: javax/servlet/ServletContextListener
# Solution : installer Tomcat 9 manuellement
cd /opt || exit
wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
mv apache-tomcat-${TOMCAT_VERSION} tomcat9

useradd -m -d /opt/tomcat9 -U -s /bin/false tomcat9 2>/dev/null || true
chown -R tomcat9:tomcat9 /opt/tomcat9

cd /root || exit
wget -q https://archive.apache.org/dist/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war
cp guacamole-${GUAC_VERSION}.war ${TOMCAT_DIR}/webapps/guacamole.war
chown tomcat9:tomcat9 ${TOMCAT_DIR}/webapps/guacamole.war

# Configuration GUACAMOLE_HOME
mkdir -p ${GUAC_HOME}/extensions
mkdir -p ${GUAC_HOME}/lib

# Extension JDBC MySQL pour la gestion des users/groupes/connexions via BDD
wget -q https://archive.apache.org/dist/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
cat guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql | mysql -u root guacamole_db
cp guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar ${GUAC_HOME}/extensions/
cp /usr/share/java/mariadb-java-client.jar ${GUAC_HOME}/lib/

# Extension LDAP pour l authentification via l AD
wget -q https://archive.apache.org/dist/guacamole/${GUAC_VERSION}/binary/guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-auth-ldap-${GUAC_VERSION}.tar.gz
cp guacamole-auth-ldap-${GUAC_VERSION}/guacamole-auth-ldap-${GUAC_VERSION}.jar ${GUAC_HOME}/extensions/

# Donner les droits admin a guacadmin dans la BDD
mysql -u root guacamole_db <<SQLEOF
INSERT INTO guacamole_system_permission (entity_id, permission)
SELECT entity_id, 'ADMINISTER' FROM guacamole_entity WHERE name = 'guacadmin'
ON DUPLICATE KEY UPDATE permission = 'ADMINISTER';
SQLEOF

cat > ${GUAC_HOME}/guacamole.properties <<EOF
guacd-hostname: 127.0.0.1
guacd-port: 4822
mysql-hostname: 127.0.0.1
mysql-port: 3306
mysql-database: guacamole_db
mysql-username: guacamole_user
mysql-password: ${DB_PASSWORD}
mysql-ssl-mode: disabled
ldap-hostname: ${DC_IP}
ldap-port: 389
ldap-user-base-dn: DC=lospollos,DC=local
ldap-username-attribute: sAMAccountName
ldap-search-bind-dn: CN=Administrateur,CN=Users,DC=lospollos,DC=local
ldap-search-bind-password: admin1234**!
ldap-user-search-filter: (objectClass=user)
EOF

chown -R tomcat9:tomcat9 ${GUAC_HOME}

cat > /etc/systemd/system/tomcat9.service <<EOF
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
User=tomcat9
Group=tomcat9
Environment="JAVA_HOME=/usr/lib/jvm/default-java"
Environment="CATALINA_HOME=/opt/tomcat9"
Environment="CATALINA_BASE=/opt/tomcat9"
Environment="GUACAMOLE_HOME=${GUAC_HOME}"
ExecStart=/opt/tomcat9/bin/startup.sh
ExecStop=/opt/tomcat9/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tomcat9
systemctl start tomcat9

echo "Guacamole accessible sur http://${BASTION_IP}:8080/guacamole"
echo "Admin Guacamole : guacadmin / guacadmin (changer le mdp apres installation)"
echo "Ensuite executer 04_guacamole_setup.sql pour creer les groupes et connexions"
