#!/bin/bash
# Arcade Launcher install script

WIDGET_DIR="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.arcadelauncher"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/org.kde.plasma.arcadelauncher"

echo "Installing Arcade Launcher..."

rm -rf "$WIDGET_DIR"
mkdir -p "$WIDGET_DIR"
cp -r "$SOURCE_DIR"/* "$WIDGET_DIR/"

echo "Restarting plasmashell..."
plasmashell --replace &

echo "Done. Add the widget from the panel widgets menu."
echo "To add via script run:"
echo "  qdbus org.kde.plasmashell /PlasmaShell evaluateScript 'panels()[0].addWidget(\"org.kde.plasma.arcadelauncher\")'"
