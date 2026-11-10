#!/usr/bin/env bash
# Télécharge (si absent) puis exécute Godot en version épinglée. Linux x86_64 uniquement.
GODOT_VERSION="4.7.2"
set -euo pipefail

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
  echo "godot.sh : Linux x86_64 requis." >&2; exit 1
fi

DIR="$HOME/.cache/godot/$GODOT_VERSION"
NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
BIN="$DIR/$NAME"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"

if [ ! -x "$BIN" ]; then
  mkdir -p "$DIR"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Téléchargement de Godot $GODOT_VERSION..." >&2
  curl -fsSL -o "$TMP/$NAME.zip" "$BASE/$NAME.zip" || { echo "godot.sh : échec du téléchargement." >&2; exit 1; }
  if curl -fsSL -o "$TMP/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"; then
    expected="$(grep " $NAME.zip\$" "$TMP/SHA512-SUMS.txt" | awk '{print $1}')"
    actual="$(sha512sum "$TMP/$NAME.zip" | awk '{print $1}')"
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
      echo "godot.sh : SHA512 invalide ou absent du fichier de sommes." >&2; exit 1
    fi
    echo "SHA512 vérifié." >&2
  else
    echo "ATTENTION : SHA512-SUMS.txt indisponible, empreinte non vérifiée." >&2
  fi
  unzip -q -o "$TMP/$NAME.zip" -d "$DIR"
  chmod +x "$BIN"
fi

exec "$BIN" "$@"
