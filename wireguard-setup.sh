#!/bin/bash

################################################################################
# Script Name: WireGuard Installation Script
# Description: Installs and configures WireGuard VPN server on Debian/Ubuntu.
#              Provides options to add, list, revoke clients, and reset config.
# Author: Mehdi HAMIDA
# Date: 2025-01-12
# Version: 1.0
# License: MIT
# -----------------------------------------------------------------------------
# This script is available at:
#   https://github.com/idem2lyon/server-setup-scripts/blob/main/wireguard-setup.sh
#
# You can install it quickly using:
#   curl -s -S -L -o wireguard-setup.sh https://raw.githubusercontent.com/idem2lyon/server-setup-scripts/main/wireguard-setup.sh
#   chmod +x wireguard-setup.sh
#   sudo ./wireguard-setup.sh
################################################################################

# Couleurs pour l'affichage
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration initiale
VPN_PORT=${VPN_PORT:-51820} # Port par défaut pour WireGuard
echo "Port VPN utilisé : $VPN_PORT"

# Vérification des privilèges root
function isRoot() {
    if [ "${EUID}" -ne 0 ]; then
        echo -e "${RED}Vous devez exécuter ce script en tant que root.${NC}"
        exit 1
    fi
}

# Vérification de la distribution
function checkOS() {
    if [ ! -f /etc/os-release ]; then
        echo -e "${RED}Impossible de détecter le système d'exploitation. Ce script ne supporte que Debian et Ubuntu.${NC}"
        exit 1
    fi

    . /etc/os-release
    if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
        echo -e "${RED}Ce script supporte uniquement Debian et Ubuntu. Distribution détectée : $ID.${NC}"
        exit 1
    fi
}

# Demander la plage d'adresses IP
function askSubnet() {
    read -rp "Entrez la plage d'adresses IP (par défaut 10.66.67.0/24) : " input_subnet
    VPN_SUBNET=${input_subnet:-10.66.67.0/24}
    echo -e "${GREEN}Plage d'adresses configurée : $VPN_SUBNET${NC}"
}

# Choix des DNS
function chooseDNS() {
    echo "Choisissez un résolveur DNS :"
    echo "1) Résolveur local (AdGuard ou autre DNS local sur le port 53)"
    echo "2) Cloudflare (1.1.1.1)"
    echo "3) Google (8.8.8.8)"
    echo "4) Quad9 (9.9.9.9)"
    echo "5) DNS personnalisés"
    read -rp "Option [1-5] : " dns_choice

    case $dns_choice in
        1)
            echo "Vérification du service DNS local sur le port 53..."
            if lsof -Pi :53 -sTCP:LISTEN -t >/dev/null; then
                echo "Interfaces réseau disponibles :"
                ip -o -4 addr show | awk '{print $2 " : " $4}'
                read -rp "Entrez l'interface réseau où AdGuard écoute (ex. eth0) : " dns_interface
                LOCAL_IP=$(ip -o -4 addr show "$dns_interface" | awk '{print $4}' | cut -d'/' -f1)
                if [ -z "$LOCAL_IP" ]; then
                    echo -e "${RED}Interface non valide. Assurez-vous qu'AdGuard est actif et configuré correctement.${NC}"
                    exit 1
                fi
                DNS="$LOCAL_IP"
                echo -e "${GREEN}WireGuard utilisera le DNS local : $DNS${NC}"
            else
                echo -e "${RED}Aucun service DNS actif sur le port 53. Assurez-vous qu'AdGuard est en cours d'exécution.${NC}"
                exit 1
            fi
            ;;
        2) DNS="1.1.1.1" ;;
        3) DNS="8.8.8.8" ;;
        4) DNS="9.9.9.9" ;;
        5)
            read -rp "Entrez votre DNS personnalisé : " custom_dns
            DNS="$custom_dns"
            ;;
        *)
            echo "Option invalide. Utilisation de Cloudflare par défaut."
            DNS="1.1.1.1"
            ;;
    esac
}

# Configuration du pare-feu
function setupFirewall() {
    if command -v nft > /dev/null || apt update && apt install -y nftables; then
        echo -e "${GREEN}nftables détecté. Configuration...${NC}"
        cat <<EOF > /etc/nftables.conf
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ip saddr $VPN_SUBNET accept
        ip protocol icmp accept
        tcp dport 22 accept
        udp dport $VPN_PORT accept
    }
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
}
EOF
        systemctl enable nftables
        systemctl restart nftables || {
            echo -e "${RED}Erreur lors du redémarrage de nftables. Vérifiez la configuration.${NC}"
            exit 1
        }
    else
        echo -e "${RED}Impossible d'installer nftables. Veuillez configurer manuellement le pare-feu.${NC}"
        exit 1
    fi
}

# Génération de la configuration WireGuard
function generateWireGuardConfig() {
    SERVER_PRIV_KEY=$(wg genkey)
    SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

    mkdir -p /etc/wireguard
    echo "[Interface]" > /etc/wireguard/wg0.conf
    echo "PrivateKey = $SERVER_PRIV_KEY" >> /etc/wireguard/wg0.conf
    echo "Address = ${VPN_SUBNET%/*}/24" >> /etc/wireguard/wg0.conf
    echo "ListenPort = $VPN_PORT" >> /etc/wireguard/wg0.conf
    echo "DNS = $DNS" >> /etc/wireguard/wg0.conf

    chmod 600 /etc/wireguard/wg0.conf
    echo -e "${GREEN}Configuration WireGuard générée avec succès.${NC}"
}

# Installation de WireGuard (uniquement si non installé)
function installWireGuard() {
    if ! command -v wg > /dev/null; then
        echo -e "${GREEN}Installation de WireGuard...${NC}"
        apt update && apt install -y wireguard qrencode
    else
        echo -e "${ORANGE}WireGuard est déjà installé. Configuration uniquement.${NC}"
    fi
    generateWireGuardConfig
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0 || {
        echo -e "${RED}Échec du démarrage de WireGuard. Veuillez vérifier la configuration avec 'systemctl status wg-quick@wg0'.${NC}"
        exit 1
    }
}

# Gestion des utilisateurs WireGuard
function newClient() {
    read -rp "Nom du client : " CLIENT_NAME
    CLIENT_PRIV_KEY=$(wg genkey)
    CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

    CLIENT_IP=$(echo "$VPN_SUBNET" | sed 's|0/.*|2|')

    SERVER_IP=$(curl -s ifconfig.me || echo "0.0.0.0")
    if [[ "$SERVER_IP" == "0.0.0.0" ]]; then
        echo -e "${RED}Impossible de récupérer l'adresse IP publique. Configurez-la manuellement dans le fichier client.${NC}"
    fi

    echo "[Peer]" >> /etc/wireguard/wg0.conf
    echo "PublicKey = $CLIENT_PUB_KEY" >> /etc/wireguard/wg0.conf
    echo "AllowedIPs = $CLIENT_IP/32" >> /etc/wireguard/wg0.conf

    cat <<EOF > ~/$CLIENT_NAME.conf
[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_IP/24
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $SERVER_IP:$VPN_PORT
AllowedIPs = 0.0.0.0/0
EOF

    qrencode -t ansiutf8 < ~/$CLIENT_NAME.conf
    echo -e "${GREEN}Configuration pour $CLIENT_NAME générée.${NC}"
}

function listClients() {
    echo -e "${GREEN}Liste des clients WireGuard :${NC}"
    grep -oP 'AllowedIPs = \K.*' /etc/wireguard/wg0.conf
}

function revokeClient() {
    read -rp "Nom du client à révoquer : " CLIENT_NAME
    sed -i "/\[Peer\]/,/AllowedIPs =.*$CLIENT_NAME/d" /etc/wireguard/wg0.conf
    echo -e "${GREEN}Client $CLIENT_NAME révoqué.${NC}"
    systemctl restart wg-quick@wg0
}

function uninstallWg() {
    echo -e "${RED}Désinstallation de WireGuard...${NC}"
    systemctl stop wg-quick@wg0
    apt remove -y wireguard
    rm -rf /etc/wireguard
    echo -e "${GREEN}WireGuard a été désinstallé.${NC}"
}

function resetWireGuard() {
    echo -e "${ORANGE}Réinitialisation de la configuration de WireGuard...${NC}"
    systemctl stop wg-quick@wg0
    rm -rf /etc/wireguard
    askSubnet
    chooseDNS
    setupFirewall
    generateWireGuardConfig
    systemctl start wg-quick@wg0 || {
        echo -e "${RED}Échec du démarrage de WireGuard. Veuillez vérifier la configuration avec 'systemctl status wg-quick@wg0'.${NC}"
        exit 1
    }
    echo -e "${GREEN}WireGuard a été réinitialisé avec succès.${NC}"
}

# Menu principal
function manageMenu() {
    echo "Welcome to WireGuard-install!"
    echo "The git repository is available at: https://github.com/angristan/wireguard-install"
    echo ""
    echo "It looks like WireGuard is already installed."
    echo ""
    echo "What do you want to do?"
    echo "   1) Add a new user"
    echo "   2) List all users"
    echo "   3) Revoke existing user"
    echo "   4) Reset WireGuard configuration"
    echo "   5) Uninstall WireGuard"
    echo "   6) Exit"
    until [[ ${MENU_OPTION} =~ ^[1-6]$ ]]; do
        read -rp "Select an option [1-6]: " MENU_OPTION
    done
    case "${MENU_OPTION}" in
    1)
        newClient
        ;;
    2)
        listClients
        ;;
    3)
        revokeClient
        ;;
    4)
        resetWireGuard
        ;;
    5)
        uninstallWg
        ;;
    6)
        exit 0
        ;;
    esac
}

# Vérifications initiales
function initialCheck() {
    isRoot
    checkOS
    askSubnet
    chooseDNS
    setupFirewall
}

# Lancer les vérifications initiales ou afficher le menu
if [[ -e /etc/wireguard/wg0.conf ]]; then
    manageMenu
else
    initialCheck
    installWireGuard
    manageMenu
fi
