#!/bin/bash

# Umgebungsvariablen auslesen (Standardwerte für den Fall, dass nichts gesetzt wurde)
SERVER_NAME=${SERVER_NAME:-MyFreelancerServer}
SERVER_DESCRIPTION=${SERVER_DESCRIPTION:-A Server for Freelancer}
SERVER_PASSWORD=${SERVER_PASSWORD:-""}
ALLOW_NEW_PLAYERS=${ALLOW_NEW_PLAYERS:-1}
ENABLE_INTERNET=${INTERNET_ACCESS:-1}
PLAYER_CAN_FIGHT=${PVP_ENABLED:-1}
MAX_PLAYERS=${MAX_PLAYERS:-16}

# EULA als akzeptiert markieren
wine reg add "HKCU\\Software\\Microsoft\\Microsoft Games\\Freelancer\\1.0" /v FIRSTRUN /t REG_DWORD /d 1 /f

# FLServer-Einstellungen setzen
wine reg add "HKCU\\Software\\Microsoft\\flserver\\Settings" /v EULA_Accepted /t REG_DWORD /d 1 /f
wine reg add "HKCU\\Software\\Microsoft\\flserver\\Settings" /v Firstrun /t REG_DWORD /d 1 /f

# Pfad zur FLServer.cfg
FL_SERVER_CFG="/root/.wine/drive_c/users/root/My Documents/My Games/Freelancer/Accts/MultiPlayer/FLServer.cfg"

# Verzeichnis erstellen, falls nicht vorhanden
mkdir -p "$(dirname "$FL_SERVER_CFG")"

# Funktion zum Konvertieren eines Strings in das spezielle Format
convert_string() {
  local input="$1"
  local max_chars="$2"
  local output=""
  local length=${#input}

  # Auf maximale Länge beschränken
  if [ $length -gt $max_chars ]; then
    length=$max_chars
    input=${input:0:$length}
  fi

  # Jedes Zeichen konvertieren
  for ((i=0; i<length; i++)); do
    char="${input:$i:1}"
    # ASCII-Wert des Zeichens holen
    ascii=$(printf '%d' "'$char")
    output+=$(printf '\\x%02X\\x00' "$ascii")
  done

  # Mit Nullbytes auffüllen
  remaining=$((max_chars - length))
  for ((i=0; i<remaining; i++)); do
    output+="\x00\x00"
  done

  echo -ne "$output"
}

# Erstellung der FLServer.cfg
{
  # Header (4 Bytes)
  echo -ne "\x03\x00\x00\x00"

  # Servername (32 Zeichen)
  convert_string "$SERVER_NAME" 32

  # 2 Nullbytes als Trennung
  echo -ne "\x00\x00"

  # Beschreibung (128 Zeichen)
  convert_string "$SERVER_DESCRIPTION" 128

  # 2 Nullbytes als Trennung
  echo -ne "\x00\x00"

  # Passwort (16 Zeichen)
  convert_string "$SERVER_PASSWORD" 16

  # 2 Nullbytes nach dem Passwort
  echo -ne "\x00\x00"

  # Einstellungen
  # Einstellung 1: "Neue Spieler zulassen"
  echo -ne "$(printf '\\x%02X' $ALLOW_NEW_PLAYERS)"

  # Einstellung 2: "Server auf Internetzugriff umstellen"
  echo -ne "$(printf '\\x%02X' $ENABLE_INTERNET)"

  # Maximale Spieleranzahl (1 Byte in Hex)
  MAX_PLAYERS_HEX=$(printf '%02X' "$MAX_PLAYERS")
  echo -ne "\\x$MAX_PLAYERS_HEX"

  # 3 Nullbytes
  echo -ne "\x00\x00\x00"

  # Einstellung 3: "Spieler können andere Spieler bekämpfen"
  echo -ne "$(printf '\\x%02X' $PLAYER_CAN_FIGHT)"

  # Auffüllen auf gewünschte Größe
  desired_size=373
  current_size=$(wc -c < /dev/stdin)
  padding_size=$((desired_size - current_size))

  if [ $padding_size -gt 0 ]; then
    dd if=/dev/zero bs=1 count=$padding_size 2>/dev/null
  fi
} > "$FL_SERVER_CFG"
