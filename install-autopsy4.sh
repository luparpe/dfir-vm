#!/usr/bin/env bash
#
# Prerequisites: 
# Install "testdisk photorec", Requirement for Autopsy: sudo apt install -y testdisk which photorec#
# Download latests interworking interworking Autopsy and Sleukith packets:
# wget https://github.com/sleuthkit/sleuthkit/releases/download/sleuthkit-4.14.0/sleuthkit-java_4.14.0-1_amd64.deb
# wget https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.22.1/autopsy-4.22.1_v2.zip
# Install as sudo ./install-autopsy4.sh ./sleuthkit-java_4.14.0-1_amd64.deb ./autopsy-4.22.1_v2.zip

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 /path/to/sleuthkit-java_x.y.z_amd64.deb /path/to/autopsy-x.y.z.zip"
  exit 1
fi

if [[ $# -ne 2 ]]; then
  echo "Usage: sudo bash $0 /path/to/sleuthkit-java_x.y.z_amd64.deb /path/to/autopsy-x.y.z.zip"
  exit 1
fi

TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

TSK_JAVA_DEB="$(readlink -f "$1")"
AUTOPSY_ZIP="$(readlink -f "$2")"

INSTALL_DIR="/opt/autopsy"
WORK_DIR="/opt/autopsy-installer"

if [[ ! -f "$TSK_JAVA_DEB" ]]; then
  echo "Missing Sleuth Kit Java package: $TSK_JAVA_DEB"
  exit 1
fi

if [[ ! -f "$AUTOPSY_ZIP" ]]; then
  echo "Missing Autopsy ZIP: $AUTOPSY_ZIP"
  exit 1
fi

echo "[*] Installing Java 17 and supporting packages..."
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
  openjdk-17-jdk \
  libcanberra-gtk-module \
  libcanberra-gtk3-module \
  libgstreamer1.0-0 \
  gstreamer1.0-plugins-base \
  sqlite3 \
  unzip

echo "[*] Removing distro autopsy if present..."
apt remove -y autopsy || true

echo "[*] Installing upstream Sleuth Kit Java package..."
apt install -y "$TSK_JAVA_DEB"

echo "[*] Preparing install directory..."
mkdir -p "$INSTALL_DIR"
chown "$TARGET_USER:$TARGET_USER" "$INSTALL_DIR"

echo "[*] Preparing working directory..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "[*] Unpacking Autopsy ZIP..."
unzip -q "$AUTOPSY_ZIP" -d "$WORK_DIR"

AUTOPSY_SRC_DIR="$(find "$WORK_DIR" -maxdepth 1 -mindepth 1 -type d -name 'autopsy-*' | head -n1)"
if [[ -z "$AUTOPSY_SRC_DIR" ]]; then
  echo "Could not find extracted autopsy-* directory in $WORK_DIR"
  exit 1
fi

INSTALL_SCRIPT="$AUTOPSY_SRC_DIR/linux_macos_install_scripts/install_application.sh"
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "Could not find installer script: $INSTALL_SCRIPT"
  exit 1
fi

chmod 755 "$INSTALL_SCRIPT"

JAVA_HOME_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
echo "[*] Using JAVA_HOME=${JAVA_HOME_DIR}"

echo "[*] Running upstream installer..."
cd "$AUTOPSY_SRC_DIR"
sudo -u "$TARGET_USER" env JAVA_HOME="$JAVA_HOME_DIR" bash ./linux_macos_install_scripts/install_application.sh \
  -z "$AUTOPSY_ZIP" \
  -i "$INSTALL_DIR" \
  -j "$JAVA_HOME_DIR"

echo "[*] Creating launcher..."
cat > /usr/local/bin/autopsy4 <<EOF
#!/usr/bin/env bash
export JAVA_HOME="${JAVA_HOME_DIR}"
exec ${INSTALL_DIR}/bin/autopsy "\$@"
EOF
chmod +x /usr/local/bin/autopsy4

echo "[*] Creating desktop entry..."
cat > /usr/share/applications/autopsy4.desktop <<EOF
[Desktop Entry]
Name=Autopsy 4
Comment=Digital Forensics Platform
Exec=/usr/local/bin/autopsy4
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;Security;
EOF

echo
echo "[+] Done."
echo "[+] Start it with: autopsy4 --nosplash"
user@cirws1:~/install$
