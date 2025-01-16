#!/bin/bash
#
# -----------------------------------------------------------------------------
# This script is available at:
#   https://github.com/idem2lyon/server-setup-scripts/blob/main/adguardhome-setup.sh
#
# You can install it quickly using:
#   curl -s -S -L -o adguardhome-setup.sh https://raw.githubusercontent.com/idem2lyon/server-setup-scripts/main/adguardhome-setup.sh
#   chmod +x adguardhome-setup.sh
#   sudo ./adguardhome-setup.sh

# -----------------------------------------------------------------------------
# ENGLISH COMMENTS, FRENCH PROMPTS
# Merges:
#   - The "court-circuit" approach (generate AdGuardHome.yaml before first run)
#   - The interactive questions (interface, DNS, etc.)
#   => This prevents the /install.html wizard and makes AdGuard Home fully
#      functional with the user's chosen parameters.
# -----------------------------------------------------------------------------

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root. Utilisez sudo."
  exit 1
fi

# Download AdGuard Home
echo "Téléchargement d'AdGuard Home..."
curl -s -L -o /tmp/AdGuardHome_linux_amd64.tar.gz \
  https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz

# Extract the files (no --strip-components)
echo "Extraction des fichiers..."
mkdir -p /opt/adguardhome
cd /opt/adguardhome
tar -xzf /tmp/AdGuardHome_linux_amd64.tar.gz

# If there's a subfolder named AdGuardHome, cd into it
if [ -d "/opt/adguardhome/AdGuardHome" ]; then
  cd AdGuardHome
fi

# Define the path to the AdGuardHome binary
BIN="$(pwd)/AdGuardHome"
if [ ! -f "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "Erreur : le binaire AdGuardHome est introuvable ou non exécutable dans : $BIN"
  exit 1
fi

# -----------------------------------------------------------------------------
# INTERACTIVE PROMPTS
# -----------------------------------------------------------------------------
read -p "Entrez le port pour l'interface web (par défaut : 3500) : " WEB_PORT
WEB_PORT=${WEB_PORT:-3500}

echo "Interfaces réseau disponibles :"
ip -o -4 addr list | awk '{print $2, $4}' | while read -r iface addr; do
  echo "  $iface ($addr)"
done
echo "Par défaut, AdGuard écoutera sur 0.0.0.0 (toutes les interfaces)."
read -p "Entrez l'interface réseau sur laquelle AdGuard doit écouter (ou laisser vide) : " BIND_IFACE
BIND_IFACE=${BIND_IFACE:-0.0.0.0}

echo "Configuration des DNS upstream :"
echo "1. Upstream standard (entrer les IP directement, ex: 8.8.8.8 1.1.1.1)"
echo "2. DNS-over-TLS/QUIC (entrer un hôte, par exemple f8e666.dns.nextdns.io)"
read -p "Choisissez une option (1 ou 2) : " DNS_OPTION

if [[ "$DNS_OPTION" != "1" && "$DNS_OPTION" != "2" ]]; then
  echo "Option non valide. Arrêt du script."
  exit 1
fi

UPSTREAM_DNS=()
if [ "$DNS_OPTION" == "1" ]; then
  read -p "Entrez les IP des serveurs DNS upstream, séparées par des espaces : " -a DNS_IPS
  if [ ${#DNS_IPS[@]} -eq 0 ]; then
    DNS_IPS=("8.8.8.8" "1.1.1.1")
  fi
  for ip in "${DNS_IPS[@]}"; do
    UPSTREAM_DNS+=("$ip")
  done
elif [ "$DNS_OPTION" == "2" ]; then
  read -p "Entrez l'hôte pour DNS-over-TLS/QUIC (par exemple f8e666.dns.nextdns.io) : " DNS_HOST
  if [ -z "$DNS_HOST" ]; then
    echo "Hôte non valide. Arrêt du script."
    exit 1
  fi
  read -p "Souhaitez-vous activer DNS-over-TLS ? (o/n, par défaut : o) : " USE_TLS
  USE_TLS=${USE_TLS:-o}
  if [ "$USE_TLS" == "o" ]; then
    UPSTREAM_DNS+=("tls://$DNS_HOST")
  fi
  read -p "Souhaitez-vous activer DNS-over-QUIC ? (o/n, par défaut : o) : " USE_QUIC
  USE_QUIC=${USE_QUIC:-o}
  if [ "$USE_QUIC" == "o" ]; then
    UPSTREAM_DNS+=("quic://$DNS_HOST")
  fi
fi

echo "Configuration des DNS bootstrap :"
read -p "Entrez les IP des serveurs bootstrap, séparées par des espaces (par défaut : 1.1.1.1 8.8.8.8) : " -a BOOTSTRAP_DNS
if [ ${#BOOTSTRAP_DNS[@]} -eq 0 ]; then
  BOOTSTRAP_DNS=("1.1.1.1" "8.8.8.8")
fi

# Define admin user & hashed password (default: "admin")
ADMIN_USER="admin"
ADMIN_PASSWORD_HASH='$2a$10$ryPnNoMHFBkGv1G5Vxx3L.8pHcn5ZyVVVBcxMYk5S1PCiTJ/cFZh.'

# -----------------------------------------------------------------------------
# GENERATE AdGuardHome.yaml BEFORE THE FIRST LAUNCH
# -----------------------------------------------------------------------------
# We'll place it in the *current* directory (where the binary is).
CONFIG_FILE="$(pwd)/AdGuardHome.yaml"

echo "Génération de la configuration dans $CONFIG_FILE..."

cat <<EOF > "$CONFIG_FILE"
bind_host: $BIND_IFACE
bind_port: $WEB_PORT

users:
  - name: $ADMIN_USER
    password: "$ADMIN_PASSWORD_HASH"
    permissions:
      -1

dns:
  bind_hosts:
    - $BIND_IFACE
  port: 53
  upstream_dns:
EOF

for dns in "${UPSTREAM_DNS[@]}"; do
  echo "    - $dns" >> "$CONFIG_FILE"
done

cat <<EOF >> "$CONFIG_FILE"
  bootstrap_dns:
EOF

for dns in "${BOOTSTRAP_DNS[@]}"; do
  echo "    - $dns" >> "$CONFIG_FILE"
done

cat <<EOF >> "$CONFIG_FILE"
  protection_enabled: true
  ratelimit: 20
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

# -----------------------------------------------------------------------------
# INSTALL AS A SERVICE (SKIPPING THE /install.html WIZARD)
# -----------------------------------------------------------------------------
echo "Installation du service AdGuard Home (sans assistant)..."
"$BIN" -s install

# Adjust permissions
chmod 755 "$(pwd)"
chmod 644 "$CONFIG_FILE"

# -----------------------------------------------------------------------------
# FIREWALL CONFIGURATION
# -----------------------------------------------------------------------------
if command -v ufw > /dev/null; then
  echo "Configuration du pare-feu avec UFW..."
  # Web port (TCP)
  ufw allow "$WEB_PORT"/tcp
  # DNS port (53, TCP & UDP)
  ufw allow 53/tcp
  ufw allow 53/udp
elif command -v nft > /dev/null; then
  echo "Configuration du pare-feu avec nftables..."
  nft add rule inet filter input tcp dport "$WEB_PORT" accept
  nft add rule inet filter input tcp dport 53 accept
  nft add rule inet filter input udp dport 53 accept
else
  echo "Aucun gestionnaire de pare-feu compatible trouvé. Configuration manuelle requise."
fi

# -----------------------------------------------------------------------------
# RESTART AdGuard Home TO APPLY CHANGES
# -----------------------------------------------------------------------------
echo "Redémarrage d'AdGuard Home..."
systemctl restart AdGuardHome || echo "Échec du redémarrage : le service est peut-être indisponible."

# Check status
echo "Vérification du statut du service AdGuard Home :"
systemctl status AdGuardHome --no-pager

# -----------------------------------------------------------------------------
# FINAL MESSAGE
# -----------------------------------------------------------------------------
echo "========================================================="
echo "AdGuard Home a été installé et configuré avec succès !"
echo "Interface web : http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
echo "Identifiants : admin / admin (pensez à changer ce mot de passe)"
echo "========================================================="
