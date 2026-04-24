#!/usr/bin/env bash
set -euo pipefail

#######################################################################
# Kolory + funkcje komunikatów + pasek postępu
#######################################################################
WHITE="\e[97m"; RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
BLUE="\e[34m"; CYAN="\e[36m"; MAGENTA="\e[35m"; RESET="\e[0m"

info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

progress_bar() {
    local duration=$1
    local i=0
    while [ $i -le $duration ]; do
        local bar=$(printf "%-${i}s" "#" | tr ' ' '#')
        printf "\r${CYAN}[%s%-${duration}s]${RESET}" "$bar" ""
        sleep 0.05
        i=$((i+1))
    done
    echo ""
}

if [ "$EUID" -eq 0 ]; then
    error "Uruchom skrypt BEZ sudo (skrypt sam o nie poprosi)."
    exit 1
fi

#######################################################################
# Banner ARCH LINUX - STEAM DECK EDITION
#######################################################################
clear
echo -e "${CYAN}=================================="
echo "    ARCH LINUX - STEAM DECK LCD   "
echo "    Skrypt Instalacyjny 2026      "
echo -e "==================================${RESET}"
echo -e "${YELLOW}Autor: Krzysiek Wierciuch (Hulig1n19)${RESET}"
echo -e "${WHITE}Przeznaczenie: Steam Deck LCD 512GB${RESET}\n"

#######################################################################
# 1. Wybór sesji Pulpitu
#######################################################################
info "Sprawdzam dostępne sesje..."
available_desktops=$(ls /usr/share/wayland-sessions/*.desktop 2>/dev/null | sed 's|/usr/share/wayland-sessions/||; s/\.desktop$//' | grep -v 'gamescope' || echo "")

if [ -z "$available_desktops" ]; then
    warn "Brak zainstalowanego środowiska. Zainstaluję KDE Plasma..."
    sudo pacman -S --noconfirm plasma-desktop sddm konsole dolphin zenity
    available_desktops="plasma"
fi

echo -e "\n${MAGENTA}Wykryte sesje Wayland (Pulpit):${RESET}"
echo "$available_desktops"
read -p "Wpisz nazwę sesji (domyślnie: plasma): " selected_de
selected_de=${selected_de:-plasma}

#######################################################################
# 2. Optymalizacja Mirrorów i Systemu
#######################################################################
info "Aktualizacja mirrorów przez Reflector..."
if ! pacman -Qi reflector >/dev/null 2>&1; then sudo pacman -S --noconfirm reflector; fi
sudo reflector --country Poland,Germany --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

info "Pełna aktualizacja systemu..."
progress_bar 20
sudo pacman -Syu --noconfirm

#######################################################################
# 3. Instalacja Pakietów
#######################################################################
PACMAN_PKGS=(
    git base-devel less wget firefox firefox-i18n-pl flatpak zenity jq
    plasma-nm plasma-pa bluedevil plasma-workspace-wallpapers plasma-browser-integration
    ark p7zip unrar unzip lrzip lzop zip papirus-icon-theme capitaine-cursors discover opencl-mesa
    kdeplasma-addons kdeconnect sshfs noto-fonts-cjk noto-fonts-extra cantarell-fonts hunspell-pl
    lib32-mesa lib32-vulkan-radeon clinfo kwallet-pam kwalletmanager vim kclock cmake ninja
    steam qbittorrent elisa putty okular gsmartcontrol
    gwenview kdegraphics-thumbnailers ffmpegthumbs mangohud btop spectacle qt5-virtualkeyboard
    kolourpaint gnome-maps gnome-calendar kcalc sweeper vlc vlc-plugins-all scrcpy libreoffice-fresh
    libreoffice-fresh-pl gnome-disk-utility ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs f2fs-tools
    wine dosbox gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly libgphoto2 samba sane
    unixodbc wine-gecko wine-mono pacman-contrib gamemode gamescope breeze-gtk
    dolphin-plugins kfind ttf-jetbrains-mono ttf-fira-code dunst lutris bluez bluez-utils
)

info "Instalacja pakietów..."
sudo pacman -S --noconfirm "${PACMAN_PKGS[@]}"

#######################################################################
# 4. Instalacja YAY (AUR)
#######################################################################
if ! command -v yay >/dev/null 2>&1; then
    info "Instaluję yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi
info "Instalacja sesji SteamOS..."
yay -S --noconfirm gamescope-session-steam-git

#######################################################################
# 5. Konfiguracja SDDM
#######################################################################
info "Konfiguruję SDDM..."
sudo tee /etc/sddm.conf > /dev/null <<EOF
[Autologin]
Relogin=true
Session=gamescope-session-steam
User=$(whoami)

[General]
InputMethod=qtvirtualkeyboard
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze
EOF
sudo systemctl enable sddm.service

#######################################################################
# 6. steamos-session-select (Ulepszony o loginctl)
#######################################################################
info "Tworzenie /usr/bin/steamos-session-select..."
sudo tee /usr/bin/steamos-session-select > /dev/null <<EOF
#!/usr/bin/bash
CONFIG_FILE="/etc/sddm.conf"
if [ "\$1" == "plasma" ] || [ "\$1" == "desktop" ]; then
    sudo sed -i "s/^Session=.*/Session=$selected_de/" "\$CONFIG_FILE"
    steam -shutdown
elif [ "\$1" == "gamescope" ]; then
    sudo sed -i "s/^Session=.*/Session=gamescope-session-steam/" "\$CONFIG_FILE"
    loginctl terminate-session \$XDG_SESSION_ID
fi
EOF
sudo chmod +x /usr/bin/steamos-session-select

# Uprawnienia bez hasła do plików konfiguracyjnych i update
sudo tee /etc/sudoers.d/deckify_all > /dev/null <<EOF
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/sed -i s/^Session=*/Session=*/ /etc/sddm.conf
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syu --noconfirm
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/pacman -S *
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart plugin_loader.service
EOF
sudo chmod 440 /etc/sudoers.d/deckify_all

#######################################################################
# 7. Hardware & Gamemode
#######################################################################
info "Optymalizacje sprzętowe..."
sudo systemctl enable --now bluetooth
sudo tee /etc/gamemode.ini > /dev/null <<EOF
[general]
renice=10
[cpu]
governor=performance
[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
EOF

#######################################################################
# 8. Tworzenie Narzędzi (Twój Helper + Update + Decky)
#######################################################################
info "Budowanie centrum narzędzi arch-deckify..."
mkdir -p "$HOME/arch-deckify"

# PLIK 1: system_update.sh (Twoja wersja terminalowa)
cat <<'EOF' > "$HOME/arch-deckify/system_update.sh"
#!/bin/bash
UPDATE_CMD="yay -Syu --noconfirm"
konsole -e bash -c "clear; echo -e '\e[94mAktualizacja systemu...\e[0m'; sudo rm -rf /var/lib/pacman/db.lck; $UPDATE_CMD; flatpak update -y; echo -e '\e[93mGotowe. Zamykanie za 5s...\e[0m'; sleep 5"
EOF

# PLIK 2: gui_helper.sh (Twoje menu Zenity)
cat <<'EOF' > "$HOME/arch-deckify/gui_helper.sh"
#!/bin/bash
PLUGIN_LOADER_PATH="${HOME}/homebrew"
ask_sudo() {
    if sudo -n true 2>/dev/null; then return 0; fi
    PASSWORD=$(zenity --password --title="Autoryzacja")
    echo "$PASSWORD" | sudo -S -v >/dev/null 2>&1
}

while true; do
    allTools=("Run Gamescope" "Tryb Gry w oknie" "Update System" "Aktualizacja wszystkiego" "Install Decky" "Wtyczki Steam")
    SELECTION=$(zenity --title "Deckify Tools" --list --radiolist --height=400 --width=500 \
        --column "" --column "Opcja" --column "Opis" \
        FALSE "${allTools[0]}" "${allTools[1]}" FALSE "${allTools[2]}" "${allTools[3]}" FALSE "${allTools[4]}" "${allTools[5]}")
    [ $? -ne 0 ] && exit 0
    case "$SELECTION" in
        "Run Gamescope") gamescope-session-plus steam ;;
        "Update System") bash "$HOME/arch-deckify/system_update.sh" ;;
        "Install Decky") 
            ask_sudo
            curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
            sudo sed -i 's~TimeoutStopSec=.*$~TimeoutStopSec=2~g' /etc/systemd/system/plugin_loader.service
            sudo systemctl daemon-reload && sudo systemctl restart plugin_loader.service
            zenity --info --text="Decky zainstalowany i zoptymalizowany!" ;;
    esac
done
EOF

chmod +x "$HOME/arch-deckify/"*.sh

#######################################################################
# 9. Skróty Pulpitu
#######################################################################
info "Tworzenie ikon na pulpicie..."
DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"

wget -q -O "$HOME/arch-deckify/icon.png" https://raw.githubusercontent.com/unlbslk/arch-deckify/refs/heads/main/icons/steam-gaming-return.png || true

cat <<EOF > "$DESKTOP_DIR/Return_to_Gaming_Mode.desktop"
[Desktop Entry]
Name=Return to Gaming Mode
Exec=steamos-session-select gamescope
Icon=steam
Terminal=false
Type=Application
EOF

cat <<EOF > "$DESKTOP_DIR/Deckify_Tools.desktop"
[Desktop Entry]
Name=Deckify Tools
Exec=$HOME/arch-deckify/gui_helper.sh
Icon=utilities-terminal
Terminal=false
Type=Application
EOF

chmod +x "$DESKTOP_DIR"/*.desktop

#######################################################################
# 10. Finalizacja
#######################################################################
info "Instalacja ProtonPlus..."
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub com.vysp3r.ProtonPlus

ok "INSTALACJA ZAKOŃCZONA!"
sleep 5
sudo reboot
