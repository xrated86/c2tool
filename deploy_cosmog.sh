#!/bin/bash

CONFIG_FILE_HOST="./deploy_cosmog.toml"
if [[ ! -f "$CONFIG_FILE_HOST" ]]; then
    echo "❌ Configuratiebestand $CONFIG_FILE_HOST niet gevonden."
    exit 1
fi

source <(grep = "$CONFIG_FILE_HOST" | sed 's/ *= */=/g' | sed 's/^/export /')

# === CONTROLEER OF ADB EN UNZIP AANWEZIG ZIJN ===
for cmd in adb unzip curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Vereist commando ontbreekt: $cmd"
        exit 1
    fi
done

# === TIJDELIJKE MAP AANMAKEN ===
TMPDIR=$(mktemp -d)
echo "📁 Temporary directory created: $TMPDIR"

# === ZIP DOWNLOADEN EN UITPAKKEN ===
curl -sL "$ZIP_URL" -o "$TMPDIR/cosmog.zip"
unzip -q "$TMPDIR/cosmog.zip" -d "$TMPDIR/cosmog"
EXTRACTED_DIR=$(find "$TMPDIR/cosmog" -mindepth 1 -maxdepth 1 -type d | head -n 1)
echo "📦 Contents extracted to $EXTRACTED_DIR"

# === OPHALEN VAN ADB-DEVICES OP localhost ===
DEVICES=$(adb devices | grep -o 'localhost:[0-9]*')

if [[ -z "$DEVICES" ]]; then
    echo "❌ No active ADB Redroid instances found via localhost."
    exit 1
fi

echo "✅ Devices found: $DEVICES"

BASE_DEVICE_NAME="$DEVICE_NAME"

# === PER DEVICE ACTIES ===
for DEVICE in $DEVICES; do
    echo "🚀 Processing: $DEVICE"

    PORT=$(echo "$DEVICE" | cut -d':' -f2)
    DEVICE_NAME="${BASE_DEVICE_NAME}-${PORT}"
[ -d "$TMPDIR/cosmog" ] || mkdir -p "$TMPDIR/cosmog"
    CONFIG_FILE="$TMPDIR/cosmog/config.toml"

    cat > "$CONFIG_FILE" <<EOF
[rotom]
rotom_worker_endpoint = "$ROTOM_WORKER_ENDPOINT"
rotom_device_endpoint = "$ROTOM_DEVICE_ENDPOINT"
rotom_secret = "$ROTOM_SECRET"
use_compression = true

[general]
device_name = "$DEVICE_NAME"
workers = $WORKERS
klefki_token = "$KLEFKI_TOKEN"

[log]
level = "info"
use_colors = true
log_to_file = true
max_size = 10
max_backups = 10
max_age = 30
compress = true

[tuning]
worker_spawn_delay_ms = $WORKER_SPAWN_DELAY_MS
EOF

    echo "📝 config.toml generated for $DEVICE_NAME"

    # App verwijderen
    adb -s "$DEVICE" shell pm uninstall com.nianticlabs.pokemongo.ares

    # Proces stoppen als het al draait (robuustere aanpak)
    PID=$(adb -s "$DEVICE" shell pidof com.nianticlabs.pokemongo | tr -d '\r')
    if [[ -n "$PID" ]]; then
        echo "⛔ Process ID $PID found on $DEVICE, stopping..."
        adb -s "$DEVICE" shell kill "$PID"
    fi

    # Verwijder oude bestanden
    echo "🧹 Removing old files on $DEVICE..."
    adb -s "$DEVICE" shell rm -rf /data/local/tmp/com.nianticlabs.pokemongo
    adb -s "$DEVICE" shell rm -rf /data/local/tmp/config.toml
    adb -s "$DEVICE" shell rm -rf /data/local/tmp/assets
    adb -s "$DEVICE" shell rm -rf /data/local/tmp/lib || true

    # Nieuwe bestanden pushen
    adb -s "$DEVICE" push "$EXTRACTED_DIR/." /data/local/tmp/
    adb -s "$DEVICE" push "$CONFIG_FILE" /data/local/tmp/config.toml

    # Uitvoerbaar maken en starten
    adb -s "$DEVICE" shell chmod +x /data/local/tmp/com.nianticlabs.pokemongo
    adb -s "$DEVICE" shell "sh -c 'cd /data/local/tmp && ./com.nianticlabs.pokemongo > /dev/null 2>&1 &'" &

    echo "✅ Cosmog started on $DEVICE"
done

rm -rf "$TMPDIR"
echo "🎉 All Redroid instances have been processed."