#!/bin/bash

# Fonction pour vérifier si un paquet est installé
is_installed() {
    dpkg -l | grep -q "^ii  $1 "
}

# Mettre à jour les paquets
sudo apt update

# Installer sudo si ce n'est pas déjà fait
if ! is_installed sudo; then
    apt install -y sudo
fi

# Installer gpg si ce n'est pas déjà fait
if ! is_installed gpg; then
    sudo apt install -y gpg
fi

# Installer zsh si ce n'est pas déjà fait
if ! is_installed zsh; then
    sudo apt install -y zsh
fi

# Installer git si ce n'est pas déjà fait
if ! is_installed git; then
    sudo apt install -y git
fi

# Installer Oh My Zsh si ce n'est pas déjà fait
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Ajouter le dépôt pour eza si le fichier GPG n'est pas déjà présent
GPG_FILE="/etc/apt/keyrings/gierens.gpg"
if [ ! -f "$GPG_FILE" ]; then
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o $GPG_FILE
    echo "deb [signed-by=$GPG_FILE] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 $GPG_FILE /etc/apt/sources.list.d/gierens.list
    sudo apt update
fi

# Installer eza si ce n'est pas déjà fait
if ! is_installed eza; then
    sudo apt install -y eza
fi

# Cloner les plugins zsh si ce n'est pas déjà fait
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
fi

if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autocomplete" ]; then
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git $ZSH_CUSTOM/plugins/zsh-autocomplete
fi

# Cloner eza dans un sous-dossier de $ZSH_CUSTOM
if [ ! -d "$ZSH_CUSTOM/plugins/eza" ]; then
    git clone https://github.com/eza-community/eza.git $ZSH_CUSTOM/plugins/eza
fi

# Installer fastfetch en fonction de l'architecture
if ! is_installed fastfetch; then
    # Déterminer l'architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DEB_URL=$(wget -qO- https://api.github.com/repos/LinusDierheimer/fastfetch/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)
            ;;
        aarch64)
            DEB_URL=$(wget -qO- https://api.github.com/repos/LinusDierheimer/fastfetch/releases/latest | grep "browser_download_url.*arm64.deb" | cut -d '"' -f 4)
            ;;
        *)
            echo "Architecture non supportée: $ARCH"
            exit 1
            ;;
    esac

    # Télécharger et installer le fichier .deb
    wget -qO fastfetch.deb $DEB_URL
    sudo dpkg -i fastfetch.deb
    rm fastfetch.deb
fi

# Modifier le fichier .zshrc pour inclure les plugins
ZSHRC=$HOME/.zshrc

# Vérifier si la ligne plugins existe déjà
if grep -q "^plugins=" $ZSHRC; then
    # Extraire les plugins existants
    existing_plugins=$(grep "^plugins=" $ZSHRC | sed 's/plugins=(\(.*\))/\1/')

    # Ajouter les nouveaux plugins s'ils ne sont pas déjà présents
    new_plugins="git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete"
    for plugin in $new_plugins; do
        if ! echo $existing_plugins | grep -q "\<$plugin\>"; then
            existing_plugins="$existing_plugins $plugin"
        fi
    done

    # Remplacer la ligne plugins existante
    sed -i "/^plugins=/c\plugins=($existing_plugins)" $ZSHRC
else
    # Ajouter la ligne plugins si elle n'existe pas
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)' >> $ZSHRC
fi

# Ajouter le chemin de complétion pour eza
if ! grep -q "export FPATH" $ZSHRC; then
    echo 'export FPATH="'$ZSH_CUSTOM'/plugins/eza/completions/zsh:$FPATH"' >> $ZSHRC
fi

# Ajouter la commande fastfetch à la fin du fichier .zshrc
if ! grep -q "fastfetch" $ZSHRC; then
    echo 'fastfetch' >> $ZSHRC
fi

# Créer le fichier ~/.zsh/aliases.zsh s'il n'existe pas
ALIASES_FILE=$HOME/.zsh/aliases.zsh
if [ ! -f "$ALIASES_FILE" ]; then
    mkdir -p $HOME/.zsh
    cat <<EOF > $ALIASES_FILE
# alias
# ---
#
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first -l"
alias history="history -f"
EOF
else
    # Ajouter les alias s'ils n'existent pas déjà
    if ! grep -q "alias ls=" $ALIASES_FILE; then
        echo 'alias ls="eza --icons --group-directories-first"' >> $ALIASES_FILE
    fi
    if ! grep -q "alias ll=" $ALIASES_FILE; then
        echo 'alias ll="eza --icons --group-directories-first -l"' >> $ALIASES_FILE
    fi
    if ! grep -q "alias history=" $ALIASES_FILE; then
        echo 'alias history="history -f"' >> $ALIASES_FILE
    fi
fi

# Ajouter la ligne pour sourcer le fichier d'alias dans .zshrc si elle n'existe pas déjà
if ! grep -q "source ~/.zsh/aliases.zsh" $ZSHRC; then
    echo '[[ -f ~/.zsh/aliases.zsh ]] && source ~/.zsh/aliases.zsh' >> $ZSHRC
fi

# Changer le shell par défaut à zsh
if [ "$(basename "$SHELL")" != "zsh" ]; then
    chsh -s $(which zsh)
fi

echo "Installation terminée. Veuillez redémarrer votre terminal ou exécuter 'source ~/.zshrc' pour appliquer les changements."
