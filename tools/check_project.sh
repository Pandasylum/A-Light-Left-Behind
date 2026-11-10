#!/usr/bin/env bash
# Vérifie que le projet Godot (game/) s'importe et se charge sans erreur (headless).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"

echo "Godot : $("$GODOT" --version)"
OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
rc=0
"$GODOT" --headless --path "$ROOT/game" --import >"$OUT" 2>&1 || rc=$?
"$GODOT" --headless --path "$ROOT/game" --quit >>"$OUT" 2>&1 || rc=$?
cat "$OUT"
if [ "$rc" -ne 0 ] || grep -qE "ERROR|SCRIPT ERROR" "$OUT"; then
  echo "check_project : ÉCHEC (code $rc)" >&2; exit 1
fi
echo "check_project : OK"
