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

#######################################################################
# Banner STEAM DECK - ARCH LINUX
#######################################################################

arch_logo() {
    echo -e "${CYAN}"
    echo "=================================="
    echo "     ARCH LINUX - STEAM DECK      "
    echo "    KDE Plasma + Gaming Mode      "
    echo "=================================="
    echo ""
    echo -e "${YELLOW}Autor Skryptu: Krzysiek Wierciuch (Hulig1n19)${RESET}"
    echo ""
    echo -e "${WHITE}Dostosowano Specjalnie Dla: Konsoli Steam Deck${RESET}"
    echo ""
}

arch_logo
sleep 1

#######################################################################
# 0. Dodanie repozytorium Valve (JUPITER) i kluczy
#######################################################################

info "Konfiguracja repozytorium jupiter-main od Valve..."

if ! grep -q "\[jupiter-main\]" /etc/pacman.conf; then
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[jupiter-main]
Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/\$repo/os/\$arch
SigLevel = Never
EOF'
    ok "Repozytorium jupiter-main dodane do pacman.conf."
else
    warn "Repozytorium jupiter-main już istnieje."
fi

#######################################################################
# 1. Aktualizacja baz danych i systemu
#######################################################################

info "Aktualizacja baz danych pacmana i systemu..."
progress_bar 20
sudo pacman -Sy
sudo pacman -Syu --noconfirm
ok "System zaktualizowany."

#######################################################################
# 3. Instalacja Plasma Desktop + SDDM (bez duplikatów)
#######################################################################

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

#######################################################################
# 4. Włączenie menedżera logowania SDDM
#######################################################################

info "Włączam SDDM..."
if ! systemctl is-enabled --quiet sddm 2>/dev/null; then
    sudo systemctl enable sddm
    ok "SDDM włączony."
else
    warn "SDDM już jest włączony."
fi

#######################################################################
# 5. Instalacja pakietów pacman (Dostosowane pod Steam Decka)
#######################################################################

PACMAN_PKGS=(
  git base-devel less wget firefox firefox-i18n-pl flatpak
  plasma-nm plasma-pa bluedevil plasma-workspace-wallpapers plasma-browser-integration
  ark p7zip unrar unzip lrzip lzop zip papirus-icon-theme capitaine-cursors discover opencl-mesa
  kdeplasma-addons kdeconnect sshfs noto-fonts-cjk noto-fonts-extra cantarell-fonts hunspell-pl
  lib32-mesa lib32-vulkan-radeon clinfo kwallet-pam kwalletmanager vim kclock cmake ninja
  steam okular
  gwenview kdegraphics-thumbnailers ffmpegthumbs mangohud btop spectacle qt5-virtualkeyboard
  kcalc sweeper gnome-disk-utility ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs f2fs-tools
  wine dosbox gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly libgphoto2 samba sane
  unixodbc wine-gecko wine-mono gamemode gamescope breeze-gtk
  dolphin-plugins kfind ttf-jetbrains-mono ttf-fira-code dunst
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

#######################################################################
# 6. Flatpak + Flathub + Globalny język polski dla Flatpaków
#######################################################################

info "Konfiguruję Flatpak..."
if ! flatpak remote-list | grep -q '^flathub'; then
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  ok "Dodano Flathub."
else
  warn "Flathub już istnieje."
fi

info "Wymuszam język polski w aplikacjach Flatpak..."
flatpak config --set languages pl || true

#######################################################################
# 8. Instalacja yay
#######################################################################

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

#######################################################################
# 9. Instalacja sesji Gaming Mode z AUR
#######################################################################

info "Instalacja interfejsu Gaming Mode (gamescope-session) z AUR..."
if ! pacman -Qi gamescope-session-git >/dev/null 2>&1; then
    yay -S --noconfirm gamescope-session-git gamescope-session-steam-git
    ok "Sesja Gamescope (Gaming Mode) zainstalowana."
else
    warn "Sesja Gamescope już istnieje."
fi

#######################################################################
# 10. SDDM — Klawiatura ekranowa + motyw
#######################################################################

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

#######################################################################
# 11. mkinitcpio — dodanie amdgpu dla Steam Decka
#######################################################################

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

info "Generowanie initramfs..."
sudo mkinitcpio -P
ok "Initramfs przebudowany."

#######################################################################
# 12. Bootloader — GRUB lub systemd-boot
#######################################################################

info "Aktualizacja konfiguracji bootloadera..."
if [ -f /boot/loader/loader.conf ]; then
    sudo sed -i \
        -e 's/^[[:space:]]*timeout[[:space:]]*=[[:space:]]*[0-9]\+/timeout 0/' \
        -e 's/^[[:space:]]*timeout[[:space:]]\+[0-9]\+/timeout 0/' \
        /boot/loader/loader.conf
    ok "Timeout systemd-boot ustawiony na 0."
fi

if [ -f /boot/grub/grub.cfg ]; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ok "Konfiguracja GRUB zaktualizowana."
fi

#######################################################################
# 13. Gamemode — konfiguracja
#######################################################################

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

if [ "$HAS_GENERAL" = yes ] && [ "$HAS_RENICE" = yes ] && [ "$HAS_CPU" = yes ] && \
   [ "$HAS_GOV" = yes ] && [ "$HAS_GPU" = yes ] && [ "$HAS_GPU_OPT" = yes ] && [ "$HAS_GPU_DEV" = yes ]; then
    warn "Konfiguracja gamemode już istnieje."
else
    info "Uzupełniam konfigurację gamemode..."
    if [ "$HAS_GENERAL" = no ]; then printf "[general]\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    if [ "$HAS_RENICE" = no ]; then printf "renice=10\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    if [ "$HAS_CPU" = no ]; then printf "\n[cpu]\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    if [ "$HAS_GOV" = no ]; then printf "governor=performance\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    if [ "$HAS_GPU" = no ]; then printf "\n[gpu]\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    if [ "$HAS_GPU_OPT" = no ]; then printf "apply_gpu_optimisations=accept-responsibility\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    if [ "$HAS_GPU_DEV" = no ]; then printf "gpu_device=0\n" | sudo tee -a "$GAMEMODE_CFG" >/dev/null; fi
    ok "Gamemode skonfigurowany."
fi

#######################################################################
# 14. Czyszczenie cache
#######################################################################

info "Czyszczę cache pacmana, i yay..."
sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true
yay -Sc --noconfirm >/dev/null 2>&1 || true
ok "Cache wyczyszczony."

#######################################################################
# 15. Finalna aktualizacja
#######################################################################

info "Finalna aktualizacja systemu..."
sudo pacman -Syu --noconfirm
ok "System gotowy."

echo -e "${GREEN}=== Operacja na Steam Decku zakończona sukcesem ===${RESET}"
echo ""
info "Restart systemu nastąpi za 10 sekund."
echo ""

for i in {10..1}; do
    echo "Restart za $i..."
    sleep 1
done

info "Restartuję system..."
sudo systemctl reboot
