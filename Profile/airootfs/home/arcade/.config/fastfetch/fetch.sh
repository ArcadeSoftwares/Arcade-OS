#!/bin/bash
# ── Arcade Linux Ultra-HQ Terminal Fetch ──

IMG="${1:-/usr/share/calamares/branding/arcade/arcade-logo.png}"
IMG_COLS=32
IMG_ROWS=16

# Render high-definition image with Chafa
mapfile -t img < <(chafa "$IMG" \
  --size "${IMG_COLS}x${IMG_ROWS}" \
  --symbols sextant+half+block+quad \
  --colors full \
  --color-space din99d \
  --dither none \
  --work 9 \
  --threshold 0.5 \
  2>/dev/null)

# System info from Fastfetch with full color forced
mapfile -t info < <(fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --logo none --pipe false 2>/dev/null)

# Calculate total lines
lines=${#img[@]}
(( ${#info[@]} > lines )) && lines=${#info[@]}

# Clean side-by-side printing
for (( i=0; i<lines; i++ )); do
    img_line="${img[$i]:-}"
    info_line="${info[$i]:-}"
    
    if [[ -n "$img_line" ]]; then
        printf '%s\e[0m  %s\n' "$img_line" "$info_line"
    else
        printf '%*s  %s\n' "$IMG_COLS" "" "$info_line"
    fi
done
echo ""
