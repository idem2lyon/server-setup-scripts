#!/bin/bash

# Vérifier si l'utilisateur est root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root. Utilisez sudo."
  exit 1
fi

# Télécharger AdGuard Home
echo "Téléchargement d'AdGuard Home..."
curl -s -L -o /tmp/AdGuardHome_linux_amd64.tar.gz https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz

echo "Extraction des fichiers..."
mkdir -p /opt/adguardhome
cd /opt/adguardhome
tar -xzf /tmp/AdGuardHome_linux_amd64.tar.gz -C /opt/adguardhome --strip-components=1

# Lancer le script d'installation d'AdGuard Home
echo "Installation d'AdGuard Home..."
/opt/adguardhome/AdGuardHome/AdGuardHome -s install

# Configuration interactive
echo "Configuration d'AdGuard Home :"
read -p "Entrez le port pour l'interface web (par défaut : 3500) : " web_port
web_port=${web_port:-3500}

# Demander sur quelle interface AdGuard doit écouter
echo "Interfaces réseau disponibles :"
ip -o -4 addr list | awk '{print $2, $4}' | while read -r iface addr; do
  echo "$iface ($addr)"
done
read -p "Entrez l'interface réseau sur laquelle AdGuard doit écouter (par exemple : wg0) : " bind_iface
bind_iface=${bind_iface:-0.0.0.0}

# Configuration des DNS upstream
echo "Configuration des DNS upstream :"
echo "1. Upstream standard (entrer les IP directement)"
echo "2. DNS-over-TLS/QUIC (entrer un hôte, par exemple f8e666.dns.nextdns.io)"
read -p "Choisissez une option (1 ou 2) : " dns_option

# Validation stricte de l'entrée
if [[ "$dns_option" != "1" && "$dns_option" != "2" ]]; then
  echo "Option non valide. Arrêt du script."
  exit 1
fi

upstream_dns=()
if [ "$dns_option" == "1" ]; then
  read -p "Entrez les IP des serveurs DNS upstream, séparées par des espaces : " -a dns_ips
  for ip in "${dns_ips[@]}"; do
    upstream_dns+=("$ip")
  done
elif [ "$dns_option" == "2" ]; then
  read -p "Entrez l'hôte pour DNS-over-TLS/QUIC (par exemple f8e666.dns.nextdns.io) : " dns_host
  read -p "Souhaitez-vous activer DNS-over-TLS ? (o/n, par défaut : o) : " use_tls
  use_tls=${use_tls:-o}
  if [ "$use_tls" == "o" ]; then
    upstream_dns+=("tls://$dns_host")
  fi
  read -p "Souhaitez-vous activer DNS-over-QUIC ? (o/n, par défaut : o) : " use_quic
  use_quic=${use_quic:-o}
  if [ "$use_quic" == "o" ]; then
    upstream_dns+=("quic://$dns_host")
  fi
fi

# Configuration des DNS bootstrap
echo "Configuration des DNS bootstrap :"
read -p "Entrez les IP des serveurs bootstrap, séparées par des espaces (par défaut : 1.1.1.1 8.8.8.8) : " -a bootstrap_dns
bootstrap_dns=(${bootstrap_dns[@]:-1.1.1.1 8.8.8.8})

# Générer le fichier de configuration d'AdGuard Home
config_file="/opt/adguardhome/AdGuardHome.yaml"
echo "Mise à jour de la configuration dans $config_file..."

cat <<EOF > $config_file
bind_host: $bind_iface
bind_port: $web_port
dns:
  bind_hosts:
    - $bind_iface
  port: 53
  upstream_dns:
$(for dns in "${upstream_dns[@]}"; do echo "    - $dns"; done)
  bootstrap_dns:
$(for dns in "${bootstrap_dns[@]}"; do echo "    - $dns"; done)
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
users:
  - name: admin
    password: "$(openssl passwd -6 admin)"
    password_salt: "random_salt"
EOF

# Configurer le pare-feu
if command -v ufw > /dev/null; then
  echo "Configuration du pare-feu avec UFW..."
  ufw allow from any to any port $web_port proto tcp
  ufw allow from any to any port 53 proto udp
  ufw allow from any to any port 53 proto tcp
elif command -v nft > /dev/null; then
  echo "Configuration du pare-feu avec nftables..."
  nft add rule inet filter input tcp dport $web_port accept
  nft add rule inet filter input udp dport 53 accept
  nft add rule inet filter input tcp dport 53 accept
else
  echo "Aucun gestionnaire de pare-feu compatible trouvé. Configuration manuelle requise."
fi

# Redémarrer AdGuard Home pour appliquer les modifications
echo "Redémarrage d'AdGuard Home pour appliquer les modifications..."
systemctl restart AdGuardHome

# Vérification du statut
echo "Vérification du statut du service AdGuard Home :"
systemctl status AdGuardHome --no-pager

echo "AdGuard Home a été installé et configuré avec succès."
echo "L'interface web est disponible sur : http://$(hostname -I | awk '{print $1}'):$web_port"
