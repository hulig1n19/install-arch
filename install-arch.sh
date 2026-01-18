#!/usr/bin/env bash
set -euo pipefail

###############################################
# Kolory + funkcje komunikatów + pasek postępu
###############################################

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()      { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; }

progress_bar() {
    local duration=$1
    local i=0
    local bar=""
    while [ $i -le $duration ]; do
        bar=$(printf "%-${i}s" "#" | tr ' ' '#')
        printf "\r${CYAN}[%s%-${duration}s]${RESET}" "$bar" ""
        sleep 0.05
        i=$((i+1))
    done
    echo ""
}

###############################################
# Banner ARCH LINUX (minimalistyczny)
###############################################

arch_logo() {
    echo -e "${CYAN}"

    echo "=================================="
    echo "     ARCH LINUX - KDE Plasma      "
    echo "     Skrypt Instalacyjny 2026     "
    echo "=================================="

    echo ""
    echo -e "${YELLOW}Autor Skryptu: Krzysztof Wierciuch${RESET}"
    echo ""
    echo -e "${RED}Godzina Utworzenia Skryptu: 01:45${RESET}"
    echo ""
    echo -e "${GREEN}Data Utworzenia Skryptu: 17.01.2026${RESET}"
    echo ""
}

arch_logo
sleep 1

###############################################
# 1. Aktualizacja systemu
###############################################

info "Aktualizacja systemu..."
progress_bar 20
sudo pacman -Syu --noconfirm
ok "System zaktualizowany."


###############################################
# 2. Instalacja Plasma Desktop + SDDM (bez duplikatów)
###############################################

info "Instaluję Plasma Desktop i komponenty KDE..."

PLASMA_PKGS=(
  plasma-desktop
  kde-gtk-config
  konsole
  dolphin
  kate
  nano
  kscreen
  sddm
  sddm-kcm
)

for pkg in "${PLASMA_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    info "Instaluję: $pkg"
    sudo pacman -S --noconfirm "$pkg"
  else
    warn "Pominięto — $pkg już jest."
  fi
done

ok "Plasma Desktop i komponenty KDE zainstalowane."


###############################################
# 3. Włączenie menedżera logowania SDDM
###############################################

info "Włączam SDDM..."

if ! systemctl is-enabled --quiet sddm 2>/dev/null; then
    sudo systemctl enable sddm
    ok "SDDM włączony."
else
    warn "SDDM już jest włączony."
fi


###############################################
# 4. Instalacja pakietów pacman (bez duplikatów)
###############################################

PACMAN_PKGS=(
  git base-devel less wget discover flatpak power-profiles-daemon
  plasma-nm plasma-pa bluedevil plasma-workspace-wallpapers plasma-browser-integration
  ark p7zip unrar unzip lrzip lzop zip papirus-icon-theme capitaine-cursors
  kdeplasma-addons kdeconnect sshfs noto-fonts-cjk noto-fonts-extra cantarell-fonts hunspell-pl
  lact lib32-mesa lib32-vulkan-radeon clinfo firefox firefox-i18n-pl kwalletmanager
  openrgb steam qbittorrent obs-studio elisa thunderbird putty okular filezilla gsmartcontrol
  teamspeak3 gwenview kdegraphics-thumbnailers ffmpegthumbs reaper mangohud occt btop spectacle timeshift
  kolourpaint gnome-maps gnome-calendar kcalc sweeper vlc vlc-plugins-all scrcpy libreoffice-fresh
  libreoffice-fresh-pl gnome-disk-utility ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs f2fs-tools
  wine dosbox gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly libgphoto2 samba sane unixodbc wine-gecko wine-mono
  qt5-virtualkeyboard linux-lts-headers pacman-contrib gamemode gamescope breeze-gtk dolphin-plugins kfind ttf-jetbrains-mono ttf-fira-code dunst cmake ninja kclock
)

info "Instalacja pakietów pacman..."
for pkg in "${PACMAN_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    info "Instaluję: $pkg"
    sudo pacman -S --noconfirm "$pkg"
  else
    warn "Pominięto — $pkg już jest."
  fi
done
ok "Pakiety pacman zainstalowane."


###############################################
# 5. Flatpak + Flathub
###############################################

info "Konfiguruję Flatpak..."
if ! flatpak remote-list | grep -q '^flathub'; then
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  ok "Dodano Flathub."
else
  warn "Flathub już istnieje."
fi


###############################################
# 6. Usługi (tylko jeśli nieaktywne)
###############################################

info "Sprawdzam usługi..."

if ! systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then
  sudo systemctl enable --now power-profiles-daemon
  ok "power-profiles-daemon uruchomiony."
else
  warn "power-profiles-daemon już działa."
fi

if ! systemctl is-active --quiet lactd 2>/dev/null; then
  sudo systemctl enable --now lactd
  ok "lactd uruchomiony."
else
  warn "lactd już działa."
fi


###############################################
# 7. Instalacja yay
###############################################

info "Sprawdzam yay..."
if ! command -v yay >/dev/null 2>&1; then
  info "Instaluję yay..."
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay
  makepkg -si --noconfirm
  cd -
  ok "yay zainstalowany."
else
  warn "yay już jest."
fi


###############################################
# 8. Instalacja AUR (bez duplikatów)
###############################################

AUR_PKGS=(
  heroic-games-launcher opencl-amd xone-dkms arch-update
)

for pkg in "${AUR_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    yay -S --noconfirm "$pkg"
  fi
done


###############################################
# 9. Autostart arch-update (ikona w trayu)
###############################################

info "Konfiguruję autostart arch-update..."

AUTOSTART_FILE="$HOME/.config/autostart/arch-update.desktop"

# Upewnij się, że katalog istnieje
mkdir -p "$HOME/.config/autostart"

# Tworzymy autostart tylko jeśli nie istnieje
if [ ! -f "$AUTOSTART_FILE" ]; then
cat <<EOF > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Exec=arch-update --tray
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Arch Update
Comment=Powiadomienia o aktualizacjach systemu (pacman + AUR)
EOF

    ok "Dodano autostart arch-update."
else
    warn "Autostart arch-update już istnieje — pomijam."
fi


###############################################
# 10. SDDM — dodanie bloku tylko jeśli go nie ma
###############################################

info "Konfiguruję SDDM..."

SDDM_FILE="/etc/sddm.conf"
SDDM_BLOCK=$'[General]\nInputMethod=qtvirtualkeyboard\n\n[Theme]\nCurrent=breeze'

sudo touch "$SDDM_FILE"

if grep -Fq "[General]" "$SDDM_FILE" &&
   grep -Fq "InputMethod=qtvirtualkeyboard" "$SDDM_FILE" &&
   grep -Fq "[Theme]" "$SDDM_FILE" &&
   grep -Fq "Current=breeze" "$SDDM_FILE"; then
    warn "Blok SDDM już istnieje."
else
    info "Dodaję blok SDDM..."
    sudo sed -i ':a;/^\s*$/{$d;N;ba}' "$SDDM_FILE"
    printf "%s\n" "$SDDM_BLOCK" | sudo tee -a "$SDDM_FILE" >/dev/null
    ok "Blok SDDM dodany."
fi


###############################################
# 11. mkinitcpio — dodanie amdgpu bez duplikatów
###############################################

info "Konfiguruję mkinitcpio..."

MKCONF="/etc/mkinitcpio.conf"
sudo touch "$MKCONF"

INITRAMFS_CHANGED=0

if grep -q "^MODULES=" "$MKCONF"; then
    if grep -q "^MODULES=.*amdgpu" "$MKCONF"; then
        warn "amdgpu już jest."
    else
        info "Dodaję amdgpu do MODULES..."
        sudo sed -i \
          -e 's/^MODULES=(\s*\(.*\))/MODULES=(\1 amdgpu)/' \
          -e 's/^MODULES=(\s*/MODULES=(/' \
          "$MKCONF"
        INITRAMFS_CHANGED=1
    fi
else
    info "Dodaję nową linię MODULES=(amdgpu)..."
    LINE=$(grep -n "^# MODULES" "$MKCONF" | cut -d: -f1 || true)
    if [ -n "$LINE" ]; then
        sudo sed -i "$((LINE+1)) i MODULES=(amdgpu)" "$MKCONF"
    else
        printf "\n# MODULES\nMODULES=(amdgpu)\n" | sudo tee -a "$MKCONF" >/dev/null
    fi
    INITRAMFS_CHANGED=1
fi

if [ "$INITRAMFS_CHANGED" = "1" ]; then
    info "Przebudowuję initramfs..."
    sudo mkinitcpio -P
    ok "Initramfs przebudowany."
else
    warn "Initramfs bez zmian."
fi


###############################################
# 12. systemd-boot — ustawienie timeout 0
###############################################

info "Ustawiam timeout 0 w systemd-boot..."

if [ -f /boot/loader/loader.conf ]; then
    sudo sed -i \
        -e 's/^[[:space:]]*timeout[[:space:]]*=[[:space:]]*[0-9]\+/timeout 0/' \
        -e 's/^[[:space:]]*timeout[[:space:]]\+[0-9]\+/timeout 0/' \
        /boot/loader/loader.conf
    ok "Timeout ustawiony."
else
    warn "Plik loader.conf nie istnieje — pomijam."
fi


###############################################
# 13. Gamemode — konfiguracja
###############################################

info "Konfiguruję gamemode..."

GAMEMODE_CFG="/etc/gamemode.ini"

sudo touch "$GAMEMODE_CFG"
sudo sed -i '1{/^[[:space:]]*$/d}' "$GAMEMODE_CFG"

HAS_GENERAL=$(grep -Fq "[general]" "$GAMEMODE_CFG" && echo yes || echo no)
HAS_RENICE=$(grep -Fq "renice=10" "$GAMEMODE_CFG" && echo yes || echo no)
HAS_CPU=$(grep -Fq "[cpu]" "$GAMEMODE_CFG" && echo yes || echo no)
HAS_GOV=$(grep -Fq "governor=performance" "$GAMEMODE_CFG" && echo yes || echo no)
HAS_GPU=$(grep -Fq "[gpu]" "$GAMEMODE_CFG" && echo yes || echo no)
HAS_GPU_OPT=$(grep -Fq "apply_gpu_optimisations=accept-responsibility" "$GAMEMODE_CFG" && echo yes || echo no)
HAS_GPU_DEV=$(grep -Fq "gpu_device=0" "$GAMEMODE_CFG" && echo yes || echo no)

if [ "$HAS_GENERAL" = yes ] &&
   [ "$HAS_RENICE" = yes ] &&
   [ "$HAS_CPU" = yes ] &&
   [ "$HAS_GOV" = yes ] &&
   [ "$HAS_GPU" = yes ] &&
   [ "$HAS_GPU_OPT" = yes ] &&
   [ "$HAS_GPU_DEV" = yes ]; then

    warn "Konfiguracja gamemode już istnieje."

else
    info "Uzupełniam konfigurację gamemode..."

    if [ "$HAS_GENERAL" = no ]; then
        printf "[general]\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi
    if [ "$HAS_RENICE" = no ]; then
        printf "renice=10\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi

    if [ "$HAS_CPU" = no ]; then
        printf "\n[cpu]\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi
    if [ "$HAS_GOV" = no ]; then
        printf "governor=performance\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi

    if [ "$HAS_GPU" = no ]; then
        printf "\n[gpu]\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi
    if [ "$HAS_GPU_OPT" = no ]; then
        printf "apply_gpu_optimisations=accept-responsibility\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi
    if [ "$HAS_GPU_DEV" = no ]; then
        printf "gpu_device=0\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null
    fi

    ok "Gamemode skonfigurowany."
fi


###############################################
# 14. Czyszczenie cache
###############################################

info "Czyszczę cache pacmana i yay..."
sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true
yay -Sc --noconfirm >/dev/null 2>&1 || true
ok "Cache wyczyszczony."


###############################################
# 15. Finalna aktualizacja
###############################################

info "Finalna aktualizacja systemu..."
sudo pacman -Syu --noconfirm
ok "System gotowy."

echo -e "${GREEN}=== Operacja zakończona sukcesem ===${RESET}"

echo ""
info "Restart systemu nastąpi za 10 sekund."
echo ""

for i in {10..1}; do
    echo "Restart za $i..."
    sleep 1
done

info "Restartuję system..."
sudo systemctl reboot
