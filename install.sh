#!/bin/sh
# ==============================================================================
# Aqara Magic Switch S1E - Turnkey Custom GUI Installer
# ==============================================================================

set -e

echo "========================================================"
echo "    Aqara S1E Standalone Custom GUI Installer"
echo "========================================================"

TARGET_DIR="/data/scripts"
mkdir -p "$TARGET_DIR"

# 1. Locate or prepare working curl
CURL_EXEC=""
if [ -x /tmp/curl ]; then
    CURL_EXEC="/tmp/curl"
elif [ -x /data/scripts/curl ]; then
    CURL_EXEC="/data/scripts/curl"
elif command -v curl >/dev/null 2>&1; then
    CURL_EXEC="curl"
else
    echo "[*] BusyBox wget does not support HTTPS. Downloading portable curl via HTTP..."
    wget -O /tmp/curl "http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1" 2>/dev/null || true
    chmod a+x /tmp/curl 2>/dev/null || true
    if [ -x /tmp/curl ]; then
        CURL_EXEC="/tmp/curl"
    fi
fi

if [ -z "$CURL_EXEC" ]; then
    echo "[-] Error: Failed to acquire HTTPS capable curl utility."
    echo "    Please run: wget -O /tmp/curl http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1 && chmod +x /tmp/curl"
    exit 1
fi

# 2. Stop running services if any
echo "[1/5] Stopping existing processes..."
killall -9 aqgui gui_monitor.sh app_monitor.sh s1e_standalone_app ha_daemon httpd 2>/dev/null || true

# 3. Backup existing configs if present
BACKUP_DIR="/data/scripts_backup_$(date +%s)"
if [ -f "$TARGET_DIR/ha_config.json" ] || [ -f "$TARGET_DIR/ha_cards.json" ]; then
    echo "[2/5] Backing up existing configurations to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -rf "$TARGET_DIR"/*.json "$BACKUP_DIR/" 2>/dev/null || true
fi

# 4. Download and extract release bundle using HTTPS curl
RELEASE_URL="https://raw.githubusercontent.com/oopuuu/AqaraS1E-Custom-GUI/main/release/s1e_custom_gui_latest.tar.gz"
LOCAL_TAR="/tmp/s1e_custom_gui_latest.tar.gz"

echo "[3/5] Downloading latest release bundle via $CURL_EXEC..."
$CURL_EXEC -s -k -L -o "$LOCAL_TAR" "$RELEASE_URL"

if [ ! -s "$LOCAL_TAR" ]; then
    echo "[-] Error: Downloaded archive is empty or failed!"
    exit 1
fi

echo "[4/5] Extracting assets to $TARGET_DIR..."
cd "$TARGET_DIR"
tar -zxvf "$LOCAL_TAR" -C "$TARGET_DIR"
rm -f "$LOCAL_TAR"

# Persist curl tool to /data/scripts/curl so system has HTTPS curl permanently
if [ -f /tmp/curl ]; then
    cp -f /tmp/curl "$TARGET_DIR/curl" 2>/dev/null || true
    chmod +x "$TARGET_DIR/curl" 2>/dev/null || true
fi

# Restore user configuration if backup existed
if [ -d "$BACKUP_DIR" ]; then
    echo "[*] Restoring user configurations..."
    cp -rf "$BACKUP_DIR"/* "$TARGET_DIR/" 2>/dev/null || true
    rm -rf "$BACKUP_DIR"
fi

# 5. Set executable permissions
chmod +x "$TARGET_DIR/s1e_standalone_app" \
         "$TARGET_DIR/ha_daemon" \
         "$TARGET_DIR/api.cgi" \
         "$TARGET_DIR/snap_fast" \
         "$TARGET_DIR/post_init.sh" \
         "$TARGET_DIR/curl" 2>/dev/null || true

# 6. Launch post_init daemon
echo "[5/5] Launching standalone GUI & web server..."
sh "$TARGET_DIR/post_init.sh" >/tmp/post_init_install.log 2>&1 &

sleep 2

# Verify running process
if ps | grep -v grep | grep -q "s1e_standalone_app"; then
    DEV_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2 || echo "192.168.x.x")
    echo "========================================================"
    echo " [SUCCESS] Custom GUI installed and running!"
    echo " -> Device Web Console: http://${DEV_IP}:8080/"
    echo "========================================================"
else
    echo "[-] Warning: App process did not start immediately. Check /tmp/app.log"
fi
