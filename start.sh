#!/bin/bash

# Dynamischer Pfad zur Serverinstallation
SERVER_DIR="/mnt/server"
FREELANCER_DIR="$SERVER_DIR/Freelancer"
ISO_PATH="$SERVER_DIR/Freelancer.iso"
TEMP_DIR="$SERVER_DIR/temp_cab"

# Sicherstellen, dass das Datenverzeichnis existiert
echo "Ensuring data directory exists..."
mkdir -p "$SERVER_DIR/data"

# Überprüfen, ob Freelancer-Serverdateien bereits vorhanden sind
if [ -d "$FREELANCER_DIR" ]; then
    echo "Freelancer server is already installed. Skipping installation steps."
else
    echo "Freelancer server files not found. Starting installation process..."

    # Prüfen, ob eine lokale ISO vorhanden ist oder eine URL gesetzt wurde
    if [ -f "$ISO_PATH" ]; then
        echo "Using local ISO: $ISO_PATH"
    elif [ -n "$ISO_URL" ]; then
        echo "Downloading Freelancer.iso from $ISO_URL..."
        wget -O "$ISO_PATH" "$ISO_URL"

        if [ $? -eq 0 ]; then
            echo "Freelancer.iso downloaded successfully."
        else
            echo "Failed to download Freelancer.iso!" >&2
            exit 1
        fi
    else
        echo "No ISO file found and ISO_URL is not set. Cannot proceed with installation." >&2
        exit 1
    fi

    # ISO entpacken
    echo "Extracting CAB1.CAB from Freelancer.iso..."
    mkdir -p "$TEMP_DIR"
    7z e "$ISO_PATH" CAB1.CAB -o"$TEMP_DIR"

    echo "Unpacking contents of CAB1.CAB..."
    cd "$TEMP_DIR"
    cabextract CAB1.CAB

    echo "Copying Freelancer server files..."
    mkdir -p "$FREELANCER_DIR"
    cp -r Cab1/data "$FREELANCER_DIR/DATA"
    cp -r Cab1/dlls "$FREELANCER_DIR/DLLS"
    cp -r Cab1/exe "$FREELANCER_DIR/EXE"

    echo "Setting permissions for server executables..."
    chmod -R +x "$FREELANCER_DIR/EXE"

    # Temporäre Dateien entfernen
    echo "Cleaning up temporary files..."
    cd "$SERVER_DIR"
    rm -rf "$TEMP_DIR"

    echo "Freelancer server installation completed."
fi

# Symlink für Accounts-Verzeichnis erstellen
echo "Ensuring symlink for Multiplayer accounts..."
rm -rf "/root/.wine/drive_c/users/root/My Documents/My Games/Freelancer/Accts/MultiPlayer"
ln -s "$SERVER_DIR/data" "/root/.wine/drive_c/users/root/My Documents/My Games/Freelancer/Accts/MultiPlayer"

# Display und VNC einrichten
echo "Setting up VNC display..."
export DISPLAY=:1
Xvfb $DISPLAY -screen 0 1024x768x16 &
fluxbox &
x11vnc -display $DISPLAY -bg -forever -nopw -quiet -rfbport 5909 &

# noVNC starten
echo "Starting noVNC service..."
websockify --web=/usr/share/novnc/ --wrap-mode=ignore 0.0.0.0:6080 localhost:5909 &

# Konfigurationsskript ausführen
echo "Running server configuration script..."
"$SERVER_DIR/server_config.sh"

# Freelancer-Server starten
echo "Starting Freelancer server..."
cd "$FREELANCER_DIR/EXE"
wine ./FLServer.exe /c

# Container am Laufen halten
echo "Freelancer server is running. Keeping container alive..."
tail -f /dev/null
