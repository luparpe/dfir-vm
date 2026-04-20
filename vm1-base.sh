#!/usr/bin/env bash
# Install Base tools + XRDP + Volatility for Ubuntu 
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

echo "[*] Updating package lists..."
apt update

echo "[*] Installing core packages..."
DEBIAN_FRONTEND=noninteractive apt install -y \
  xfce4 \
  xfce4-goodies \
  xrdp \
  xorgxrdp \
  openjdk-17-jdk \
  python3 \
  python3-pip \
  python3-venv \
  pipx \
  wireshark \
  tshark \
  wxhexeditor \
  bless \
  hexedit \
  xxd \
  vim \
  nano \
  curl \
  wget \
  unzip \
  p7zip-full \
  git \
  build-essential \
  jq \
  tree \
  sqlite3 \
  libimage-exiftool-perl \
  file \
  zip \
  unzip

echo "[*] Enabling pipx for ${TARGET_USER}..."
sudo -u "$TARGET_USER" env PATH="$PATH" pipx ensurepath

echo "[*] Installing Volatility 3 via pipx..."
sudo -u "$TARGET_USER" env PATH="$PATH:$TARGET_HOME/.local/bin" pipx install volatility3

echo "[*] Configuring Wireshark capture permissions..."
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive wireshark-common || true
usermod -aG wireshark "$TARGET_USER"

echo "[*] Configuring XRDP for XFCE..."
cat > "${TARGET_HOME}/.xsession" <<'EOF'
startxfce4
EOF
chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.xsession"
chmod 644 "${TARGET_HOME}/.xsession"

# Make sure XRDP starts XFCE cleanly
if ! grep -q "startxfce4" /etc/xrdp/startwm.sh; then
  cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.bak.$(date +%F-%H%M%S)
  sed -i '/^test -x \/etc\/X11\/Xsession/a startxfce4' /etc/xrdp/startwm.sh
fi

echo "[*] Enabling XRDP..."
systemctl enable xrdp
systemctl restart xrdp

echo "[*] Adding xrdp to ssl-cert group..."
adduser xrdp ssl-cert || true
systemctl restart xrdp

echo
echo "[+] Done."
echo "[+] Log out and back in once so group membership and PATH refresh."
echo "[+] Test commands:"
echo "    java -version"
echo "    python3 --version"
echo "    ${TARGET_HOME}/.local/bin/vol"
echo "    wireshark"
echo "    wxhexeditor"
echo "    systemctl status xrdp --no-pager"
