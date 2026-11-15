#!/bin/zsh
# Copies Craftwise into the WoW Forever AddOns folder.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/Applications/World of Warcraft/_forever_/Interface/AddOns/Craftwise"
mkdir -p "$DST/Media"
cp "$SRC/Craftwise.toc" "$SRC/LICENSE" "$SRC/README.md" "$SRC/README.ru.md" "$DST/"
cp "$SRC/Media/icon.blp" "$SRC/Media/minimap.blp" "$DST/Media/"
grep -v '^##' "$SRC/Craftwise.toc" | tr -d '\r' | while read -r file; do
  [ -z "$file" ] && continue
  cp "$SRC/$file" "$DST/$file"
done
echo "Craftwise installed to $DST. Type /reload in the game."
