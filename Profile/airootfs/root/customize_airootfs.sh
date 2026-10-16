#!/usr/bin/env bash
set -e

# Configure Plymouth boot theme
plymouth-set-default-theme -R arcade

# Setup default splash
SPLASH_SRC="/usr/share/plasma/look-and-feel/arcade-splash"
if [[ ! -d "$SPLASH_SRC" && -d "/home/arcade/.local/share/plasma/look-and-feel/arcade-splash" ]]; then
	mkdir -p "$(dirname "$SPLASH_SRC")"
	cp -a "/home/arcade/.local/share/plasma/look-and-feel/arcade-splash" "$SPLASH_SRC"
fi

# Ensure user permissions
chown -R arcade:arcade /home/arcade 2>/dev/null || true
