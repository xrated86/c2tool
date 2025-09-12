#!/bin/bash

PM2_DIR="/root/cosmog/pm2"
mkdir -p "$PM2_DIR"

DEVICES=$(adb devices | grep -o 'localhost:[0-9]*')

for DEVICE in $DEVICES; do
    PORT=$(echo "$DEVICE" | cut -d':' -f2)
    SCRIPT_NAME="redroid-$PORT.sh"
    SCRIPT_PATH="$PM2_DIR/$SCRIPT_NAME"

    echo "🔧 Creating script for $DEVICE..."

    cat > "$SCRIPT_PATH" <<EOF
#!/bin/bash
DEVICE="$DEVICE"
adb -s "\$DEVICE" shell "cd /data/local/tmp && chmod +x com.nianticlabs.pokemongo && exec ./com.nianticlabs.pokemongo"
EOF

    chmod +x "$SCRIPT_PATH"

    echo "🚀 Starting PM2 process redroid-$PORT..."
    pm2 start "$SCRIPT_PATH" --name "redroid-$PORT" --interpreter bash --restart-delay 2000
done

pm2 save