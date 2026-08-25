#!/usr/bin/env bash
# Pasif rezerve bekleyen Vera cephaneligini aktive eder
set -euo pipefail
RESERVE="$HOME/.local/share/opencode/skills-reserve"
SKILLS="$HOME/.agents/skills"

if [ ! -d "$RESERVE" ] || [ -z "$(ls -A "$RESERVE" 2>/dev/null)" ]; then
  echo "Rezerve bos. Cephanelik zaten aktif ya da hic kurulmamis."
  exit 0
fi
mkdir -p "$SKILLS"
n=0
for d in "$RESERVE"/*/; do
  name=$(basename "$d")
  cp -r "$d" "$SKILLS/"
  rm -rf "$d"
  n=$((n+1))
done
rmdir "$RESERVE" 2>/dev/null || true
echo "✓ $n skill aktive edildi → $SKILLS"
echo "opencode'u yeniden baslat."
