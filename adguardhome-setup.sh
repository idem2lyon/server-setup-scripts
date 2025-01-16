#!/bin/bash
#
# -----------------------------------------------------------------------------
# This script is available at:
#   https://github.com/idem2lyon/server-setup-scripts/blob/main/adguardhome-setup.sh
#
# You can install it quickly using:
#   curl -s -S -L https://raw.githubusercontent.com/idem2lyon/server-setup-scripts/main/adguardhome-setup.sh | sh -s -- -v
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ENGLISH COMMENTS, FRENCH PROMPTS
# -----------------------------------------------------------------------------

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root. Utilisez sudo."
  exit 1
fi

# Download AdGuard Home
echo "Téléchargement d'AdGuard Home..."
curl -s -L -o /tmp/AdGuardHome_linux_amd64.tar.gz https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz

# Extract the files
echo "Extraction des fichiers..."
mkdir -p /opt/adguardhome
cd /opt/adguardhome
tar -xzf /tmp/AdGuardHome_linux_amd64.tar.gz --strip-components=1

# We won't run the interactive /install wizard. Instead we'll install the service
# but skip the initial web configuration by providing a ready-to-use YAML file.

# Prompt for the web interface port
read -p "Entrez le port pour l'interface web (par défaut 3500) : " WEB_PORT
WEB_PORT=${WEB_PORT:-3500}

# Prompt for DNS upstream
echo "Configuration des DNS upstream :"
read -p "Entrez (en séparant par des espaces) vos DNS upstream (ex: 8.8.8.8 1.1.1.1) : " -a DNS_UPSTREAM
# If empty, use default
if [ ${#DNS_UPSTREAM[@]} -eq 0 ]; then
  DNS_UPSTREAM=("8.8.8.8" "1.1.1.1")
fi

# Prompt for DNS bootstrap
echo "Configuration des DNS bootstrap :"
read -p "Entrez (en séparant par des espaces) vos DNS bootstrap (par défaut 1.1.1.1 8.8.8.8) : " -a BOOTSTRAP_DNS
if [ ${#BOOTSTRAP_DNS[@]} -eq 0 ]; then
  BOOTSTRAP_DNS=("1.1.1.1" "8.8.8.8")
fi

# We define a default user "admin" with a *hashed* password.
# This example uses bcrypt. For production, generate your own hash:
#   /opt/adguardhome/AdGuardHome --hash-password "mot-de-passe-choisi"
# and replace the string below.
# The password in this example is "admin".
ADMIN_USER="admin"
ADMIN_PASSWORD_HASH='$2a$10$ryPnNoMHFBkGv1G5Vxx3L.8pHcn5ZyVVVBcxMYk5S1PCiTJ/cFZh.'

# Create the AdGuardHome.yaml configuration
CONFIG_FILE="/opt/adguardhome/AdGuardHome.yaml"
echo "Génération de la configuration dans $CONFIG_FILE..."

cat <<EOF > "$CONFIG_FILE"
bind_host: 0.0.0.0
bind_port: $WEB_PORT

# Define a default admin user with a bcrypt-hashed password.
users:
  - name: $ADMIN_USER
    password: "$ADMIN_PASSWORD_HASH"
    permissions:
      -1  # -1 => super-admin

dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  upstream_dns:
EOF

# Append the upstream DNS array
for dns in "${DNS_UPSTREAM[@]}"; do
  echo "    - $dns" >> "$CONFIG_FILE"
done

cat <<EOF >> "$CONFIG_FILE"
  bootstrap_dns:
EOF

# Append the bootstrap DNS array
for dns in "${BOOTSTRAP_DNS[@]}"; do
  echo "    - $dns" >> "$CONFIG_FILE"
done

cat <<EOF >> "$CONFIG_FILE"
  protection_enabled: true
  blocking_mode: default
  blocked_services:
    - facebook
  cache_size: 4194304
  ipv6_disabled: false

log_file: ""
log_file_enabled: false
log_http_requests: false
log_dns_queries: false
verbose: false
EOF

# Now install AdGuard Home as a service, skipping the initial web wizard
echo "Installation du service AdGuard Home (sans assistant)..."
/opt/adguardhome/AdGuardHome -s install

# Ensure correct permissions on the directory
chmod 755 /opt/adguardhome
chmod 644 /opt/adguardhome/AdGuardHome.yaml

# Restart AdGuard Home to apply the new config
echo "Redémarrage d'AdGuard Home..."
systemctl restart AdGuardHome

# Check status
echo "Vérification du statut du service AdGuard Home :"
systemctl status AdGuardHome --no-pager

echo "========================================================="
echo "AdGuard Home est installé et configuré sans assistant web."
echo "Interface web : http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
echo "Identifiants : admin / admin"
echo "========================================================="
