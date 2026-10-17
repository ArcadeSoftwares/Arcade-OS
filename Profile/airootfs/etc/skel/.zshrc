# Load Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# AnimeTerminal style fastfetch banner
if [[ -o interactive ]] && [ -f "$HOME/.config/fastfetch/fetch.sh" ]; then
    bash "$HOME/.config/fastfetch/fetch.sh"
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fastfetch='bash ~/.config/fastfetch/fetch.sh'
