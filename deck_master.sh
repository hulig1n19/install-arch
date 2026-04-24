#!/usr/bin/env bash
set -euo pipefail

#######################################################################
# Kolory + funkcje komunikatów + pasek postępu
#######################################################################
WHITE="\e[97m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"

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
echo -e "${CYAN}"
echo "=================================="
echo "    ARCH LINUX - STEAM DECK LCD   "
echo "    Skrypt Instalacyjny 2026      "
echo "=================================="
echo -e "${YELLOW}Autor: Krzysiek Wierciuch (Hulig1n19)${RESET}"
echo -e "${WHITE}Przeznaczenie: Steam Deck LCD 512GB${RESET}\n"

#######################################################################
# 1. Wybór sesji Pulpitu
#######################################################################
info "Sprawdzam dostępne sesje..."
available_desktops=$(ls /usr/share/wayland-sessions/*.desktop 2>/dev/null | sed 's|/usr/share/wayland-sessions/||' | sed 's/\.desktop$//' | grep -v 'gamescope' || echo "")

if [ -z "$available_desktops" ]; then
    warn "Brak zainstalowanego środowiska. Zainstaluję KDE Plasma..."
    sudo pacman -S --noconfirm plasma-desktop sddm konsole dolphin
    available_desktops="plasma"
fi

echo -e "\n${MAGENTA}Wykryte sesje Wayland (Pulpit):${RESET}"
echo "$available_desktops"
echo -e "${YELLOW}Wpisz nazwę sesji, do której system ma wracać z trybu gry (zazwyczaj: plasma):${RESET}"
read -p "Nazwa sesji: " selected_de

#######################################################################
# 2. Optymalizacja Mirrorów i Systemu
#######################################################################
info "Aktualizacja mirrorów przez Reflector (Polska + Niemcy)..."
if ! pacman -Qi reflector >/dev/null 2>&1; then
    sudo pacman -S --noconfirm reflector
fi
sudo reflector --country Poland,Germany --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

info "Pełna aktualizacja systemu..."
progress_bar 20
sudo pacman -Syu --noconfirm

#######################################################################
# 3. Instalacja Pakietów (Twoja lista + Pakiety Decka)
#######################################################################
PACMAN_PKGS=(
    git base-devel less wget firefox firefox-i18n-pl flatpak
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

info "Instalacja Twoich pakietów i narzędzi systemowych..."
for pkg in "${PACMAN_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
        info "Pobieranie: $pkg"
        sudo pacman -S --noconfirm "$pkg"
    fi
done

#######################################################################
# 4. Instalacja YAY (AUR)
#######################################################################
info "Sprawdzam yay..."
if ! command -v yay >/dev/null 2>&1; then
    info "Instaluję yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd -
fi

info "Instalacja sesji SteamOS oraz sterowników padów z AUR..."
yay -S --noconfirm gamescope-session-steam-git xone-dkms

#######################################################################
# 5. Konfiguracja SDDM (Klawiatura ekranowa + Autologowanie)
#######################################################################
info "Konfiguruję SDDM..."
SDDM_FILE="/etc/sddm.conf"

sudo tee "$SDDM_FILE" > /dev/null <<EOF
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

[Users]
MaximumUid=60513
MinimumUid=1000
EOF

sudo systemctl enable sddm.service
ok "SDDM skonfigurowany pod autologowanie do Gaming Mode."

#######################################################################
# 6. Tworzenie Skryptów Przełączania Sesji (Deckify Logic)
#######################################################################
info "Tworzenie /usr/bin/steamos-session-select..."
echo "#!/usr/bin/bash
CONFIG_FILE=\"/etc/sddm.conf\"
if [ \"\$1\" == \"plasma\" ] || [ \"\$1\" == \"desktop\" ]; then
    echo \"Przełączanie na Pulpit: $selected_de\"
    sudo sed -i \"s/^Session=.*/Session=$selected_de/\" \"\$CONFIG_FILE\"
    steam -shutdown
elif [ \"\$1\" == \"gamescope\" ]; then
    echo \"Przełączanie na Gaming Mode\"
    sudo sed -i \"s/^Session=.*/Session=gamescope-session-steam/\" \"\$CONFIG_FILE\"
    loginctl terminate-session \$XDG_SESSION_ID
fi" | sudo tee /usr/bin/steamos-session-select > /dev/null

sudo chmod +x /usr/bin/steamos-session-select

# Dodanie reguły do sudoers, aby zmiana sesji nie wymagała hasła
echo "ALL ALL=(ALL) NOPASSWD: /usr/bin/sed -i s/^Session=*/Session=*/ /etc/sddm.conf" | sudo tee /etc/sudoers.d/sddm_config_edit > /dev/null
sudo chmod 440 /etc/sudoers.d/sddm_config_edit

#######################################################################
# 7. Hardware: mkinitcpio + Backlight + Boot Timeout
#######################################################################
info "Optymalizacje sprzętowe Decka..."

# Early KMS dla amdgpu
if ! grep -q "amdgpu" /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(/MODULES=(amdgpu /' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
fi

# Uprawnienia do podświetlenia ekranu
sudo usermod -a -G video $(whoami)
echo 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"' | sudo tee /etc/udev/rules.d/backlight.rules > /dev/null

# Timeout bootloadera 3s (bezpiecznik)
if [ -f /boot/loader/loader.conf ]; then
    sudo sed -i 's/^[[:space:]]*timeout.*/timeout 3/' /boot/loader/loader.conf
fi

# Bluetooth
sudo systemctl enable --now bluetooth

#######################################################################
# 8. Konfiguracja Gamemode (Twoje ustawienia)
#######################################################################
info "Konfiguruję gamemode..."
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
# 9. Skróty Pulpitu i Narzędzia Deckify
#######################################################################
info "Tworzenie skrótów na pulpicie..."
mkdir -p ~/arch-deckify
wget -P ~/arch-deckify/ https://raw.githubusercontent.com/unlbslk/arch-deckify/refs/heads/main/icons/steam-gaming-return.png

# Ikona Powrotu do trybu gry
echo "[Desktop Entry]
Name=Return to Gaming Mode
Exec=steamos-session-select gamescope
Icon=$HOME/arch-deckify/steam-gaming-return.png
Terminal=false
Type=Application
StartupNotify=false" > "$(xdg-user-dir DESKTOP)/Return_to_Gaming_Mode.desktop"
chmod +x "$(xdg-user-dir DESKTOP)/Return_to_Gaming_Mode.desktop"

#######################################################################
# 10. Flatpak + Czyszczenie
#######################################################################
info "Instalacja ProtonPlus (Flatpak)..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.vysp3r.ProtonPlus

info "Czyszczenie cache..."
sudo pacman -Sc --noconfirm
yay -Sc --noconfirm
flatpak uninstall --unused -y

echo -e "\n${GREEN}=== INSTALACJA ZAKOŃCZONA ===${RESET}"
info "System zrestartuje się automatycznie za 10 sekund."
info "Uruchomi się w Gaming Mode. Aby wrócić na pulpit, użyj menu Steama."

for i in {10..1}; do
    echo "Restart za $i..."
    sleep 1
done

sudo systemctl reboot
