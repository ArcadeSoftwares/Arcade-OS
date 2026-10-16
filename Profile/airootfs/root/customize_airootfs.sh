#!/usr/bin/env bash
set -e

# Configure Plymouth boot theme
plymouth-set-default-theme -R arcade

# Setup default splash
install -d -m 0755 /etc/xdg
cat > /etc/xdg/ksplashrc << 'EOS'
[KSplash]
Engine=KSplashQML
Theme=com.github.ProjectArcade.Arcade
EOS

install -d -m 0755 /home/arcade/.config
cat > /home/arcade/.config/ksplashrc << 'EOS'
[KSplash]
Engine=KSplashQML
Theme=com.github.ProjectArcade.Arcade
EOS

chown -R arcade:arcade /home/arcade 2>/dev/null || true
