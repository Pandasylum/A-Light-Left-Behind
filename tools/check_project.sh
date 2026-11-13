#!/usr/bin/env bash
# Vérifie que le projet Godot (game/) s'importe et se charge sans erreur (headless).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"

echo "Godot : $("$GODOT" --version)"
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
rc=0

# Étape 1 : import (fenêtre absente). Sa sortie n'est pas analysée : un premier lancement après de
# nouveaux fichiers ou sans dossier .godot/ y écrit des erreurs normales ; seul son code compte.
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true

# Étape 2 : clés de traduction « domaine.élément » utilisées entre guillemets dans game/ (hors tests)
# et absentes de ui.csv. Seuls les domaines déjà présents dans ui.csv sont contrôlés (pas de faux positif
# sur des identifiants comme "res.truc") ; les clés construites dynamiquement ne sont pas vues.
CSV="$ROOT/game/data/ui.csv"
DOMAINS="$(tail -n +2 "$CSV" | cut -d, -f1 | cut -d. -f1 | sort -u | paste -sd'|')"
USED="$(grep -rhoE --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.json' \
  --exclude-dir=tests --exclude-dir=.godot "\"($DOMAINS)(\.[a-z_0-9]+)+\"" "$ROOT/game" | tr -d '"' | sort -u)"
MISSING="$(comm -23 <(printf '%s\n' "$USED") <(tail -n +2 "$CSV" | cut -d, -f1 | sort -u))"
if [ -n "$MISSING" ]; then
  echo "Clés absentes de ui.csv :" >&2; printf '  %s\n' $MISSING >&2; rc=1
fi

# Étape 3 : chargement du projet.
"$GODOT" --headless --path "$ROOT/game" --quit >"$OUT" 2>&1 || rc=$?
cat "$OUT"
if [ "$rc" -ne 0 ] || grep -qE "ERROR|SCRIPT ERROR" "$OUT"; then
  echo "check_project : ÉCHEC (code $rc)" >&2; exit 1
fi
echo "check_project : OK"
