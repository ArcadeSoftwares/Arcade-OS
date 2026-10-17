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

# Ensure Arcade user shell dotfiles
if [[ -f "/home/arcade/.zshrc" ]]; then
    # Add starship and fetch to /etc/zsh/zshrc.local so it loads cleanly alongside grml
    mkdir -p /etc/zsh
    cat << 'EOS' > /etc/zsh/zshrc.local
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
if [[ -o interactive ]] && [ -f "$HOME/.config/fastfetch/fetch.sh" ]; then
    bash "$HOME/.config/fastfetch/fetch.sh"
fi
alias fastfetch='bash ~/.config/fastfetch/fetch.sh'
EOS
fi

# Ensure bash loads starship and fastfetch for all users
cat << 'EOS' > /etc/bash.bashrc.local
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi
if [[ $- == *i* ]] && [ -f "$HOME/.config/fastfetch/fetch.sh" ]; then
    bash "$HOME/.config/fastfetch/fetch.sh"
fi
alias fastfetch='bash ~/.config/fastfetch/fetch.sh'
EOS

if ! grep -q "bash.bashrc.local" /etc/bash.bashrc 2>/dev/null; then
    echo '[ -f /etc/bash.bashrc.local ] && . /etc/bash.bashrc.local' >> /etc/bash.bashrc 2>/dev/null || true
fi
