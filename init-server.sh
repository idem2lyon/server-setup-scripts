#!/bin/bash
#
# -----------------------------------------------------------------------------
# This script is available at:
#   https://github.com/idem2lyon/server-setup-scripts/blob/main/init-server.sh
#
# You can install it quickly using:
#   curl -s -S -L -o init-server.sh https://raw.githubusercontent.com/idem2lyon/server-setup-scripts/main/init-server.sh
#   chmod +x init-server.sh
#   sudo ./init-server.sh

# -----------------------------------------------------------------------------

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

# Prompt for the new username and password
read -p "Enter the new username: " NEW_USER
read -s -p "Enter the password for user $NEW_USER: " NEW_PASS
echo

# Update the system
echo "Updating the system..."
apt update && apt upgrade -y

# Create the user and add them to the sudo group
echo "Creating user $NEW_USER and adding them to the sudo group..."
adduser --gecos "" $NEW_USER <<EOF
$NEW_PASS
$NEW_PASS
EOF
usermod -aG sudo $NEW_USER

# Install basic packages
echo "Installing basic packages..."
apt install -y \
  vim \
  zip unzip \
  curl wget \
  net-tools \
  dnsutils \
  nftables \
  htop \
  git \
  gnupg \
  software-properties-common \
  ufw \
  traceroute \
  lsof \
  tree

# Configure Vim
echo "Configuring Vim..."
cat <<EOL > /root/.vimrc
syntax on
set mouse-=a
set clipboard=unnamedplus
EOL

cp /root/.vimrc /home/$NEW_USER/.vimrc
chown $NEW_USER:$NEW_USER /home/$NEW_USER/.vimrc

# Configure SSH
echo "Configuring SSH..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# Enable UFW firewall
echo "Configuring the UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw enable

# Confirmation
echo "Configuration completed successfully!"
