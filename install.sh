#!/bin/bash

if [ "$(id -u)" = 0 ]; then
    echo ":: This script shouldn't be run as root."
    exit 1
fi

clear
GREEN='\033[0;32m'
RED='\033[1;31m'
NONE='\033[0m'

_on_error() {
    local line="$1" cmd="$2"
    echo
    echo -e "${RED}"
    echo "  !! INSTALL FAILED !!"
    echo "  Stopped at line ${line}: ${cmd}"
    echo "  Fix the issue above and re-run the script."
    echo -e "${NONE}"
    echo
}
trap '_on_error $LINENO "$BASH_COMMAND"' ERR

# -----------------------------------------------------
# functions
# -----------------------------------------------------

# gum wrapper: renders UI on /dev/tty so highlighting works even when stdout
# is piped through tee for logging
_gum() {
    local tmp exit_code
    tmp=$(mktemp)
    gum "$@" >"$tmp" 2>/dev/tty
    exit_code=$?
    cat "$tmp"
    rm -f "$tmp"
    return $exit_code
}

# check if package is installed (any version)
_isInstalledPacman() {
    pacman -Q "$1" &>/dev/null && echo 0 || echo 1
}

# install required packages
_installPackagesPacman() {
    toInstall=();
    for pkg; do
        if [[ $(_isInstalledPacman "${pkg}") == 0 ]]; then
            echo "${pkg} is already installed.";
            continue;
        fi;
        toInstall+=("${pkg}");
    done;
    if [[ "${toInstall[@]}" == "" ]] ; then
        # echo "All pacman packages are already installed.";
        return;
    fi;
    printf "Package not installed:\n%s\n" "${toInstall[@]}";
    sudo pacman --noconfirm -S "${toInstall[@]}";
}

# install AUR packages, one at a time with up to 3 retries each
_installPackagesYay() {
    for pkg; do
        if [[ $(_isInstalledPacman "${pkg}") == 0 ]]; then
            echo "${pkg} is already installed."
            continue
        fi
        local attempt=0
        until yay --noconfirm -S "${pkg}"; do
            attempt=$((attempt + 1))
            if [ $attempt -ge 3 ]; then
                echo ":: WARNING: Failed to install ${pkg} after 3 attempts, skipping."
                break
            fi
            echo ":: Retry ${attempt}/3 for ${pkg} in 5s..."
            sleep 5
        done
    done
}

# required packages for the installer
installer_packages=(
    "wget"
    "unzip"
    "gum"
    "figlet"
)

# -----------------------------------------------------
# synchronizing package databases
# -----------------------------------------------------
sudo pacman -Sy
echo

# -----------------------------------------------------
# install required packages
# -----------------------------------------------------
echo ":: Checking that required packages are installed..."
_installPackagesPacman "${installer_packages[@]}";
echo

if _gum confirm "Have you checked the installation script before running?" ;then
    echo
    echo ":: Installing Hyprland and additional packages"
    echo
elif [ $? -eq 130 ]; then
    exit 130
else
    echo
    echo ":: Installation canceled."
    exit;
fi

echo -e "${GREEN}"
cat <<"EOF"
 _   _                  _                 _
| | | |_   _ _ __  _ __| | __ _ _ __   __| |
| |_| | | | | '_ \| '__| |/ _` | '_ \ / _` |
|  _  | |_| | |_) | |  | | (_| | | | | (_| |
|_| |_|\__, | .__/|_|  |_|\__,_|_| |_|\__,_|
       |___/|_|

EOF
echo -e "${NONE}"

echo "Are you using systemd boot or grub?"
boot=$(_gum choose systemd grub)
echo "What is the resolution and refresh rate of your monitor?"
echo "Answer in the following format eg. 3440x1440@144"
resolution=$(_gum input --placeholder "Resolution and refresh rate..." --value "1920x1080@60")
echo "Which key do you want to use as the mod key?"
mod=$(_gum choose SUPER ALT)
echo "Resolution and refresh rate: ${resolution}"

if _gum confirm "Are you using Nvidia GPU?" ;then
    nvidia=true
    intel=false
    echo
    echo ":: Nvidia GPU is not officially supported by Hyprland. If you face any problems, please check Hyprland Wiki"
    echo ":: https://wiki.hyprland.org/Nvidia/"
    echo
    if _gum confirm "Continue?" ;then
        echo
        echo ":: Starting the installation"
        echo
    elif [ $? -eq 130 ]; then
        exit 130
    else
        echo
        echo ":: Installation canceled."
        exit;
    fi
else
    nvidia=false
    if _gum confirm "Are you using Intel GPU?" ;then
        intel=true
    else
        intel=false
    fi
fi

# -----------------------------------------------------
# installation plan
# -----------------------------------------------------

echo
echo "The following steps will be performed:"
echo
echo "   1.  Core packages    — Hyprland, waybar, rofi, SDDM, fonts, themes"
echo "   2.  Git              — Configure global user name and email"
echo "   3.  SSH key          — Generate a new ed25519 key pair"
echo "   4.  Java             — JDK 25, Maven, google-java-format"
echo "   5.  Python           — pip"
echo "   6.  Node.js          — NVM + LTS Node"
echo "   7.  Docker           — Docker + docker-compose, add user to docker group"
echo "   8.  VSCode + Bruno   — Visual Studio Code, Bruno REST client"
echo "   9.  Neovim           — Neovim + NvChad / AstroNvim / LazyVim starters"
echo "  10.  GUI apps         — browsers, office, media, utilities"
echo "  11.  Terminal utils   — tmux, yazi, fastfetch, htop, fzf, zoxide"
echo "  12.  Dotfiles         — copy configs and themes to ~/.config"
echo "  13.  SDDM theme       — sddm-astronaut-theme"
echo "  14.  Wallpapers       — copy to ~/Pictures"
echo "  15.  System           — enable bluetooth, fstrim, swapfile"
echo "  16.  Zen kernel       — linux-zen + headers, rebuild bootloader"
if $nvidia; then
echo "  17.  Nvidia drivers   — nvidia-dkms, configure DRM and dracut"
elif $intel; then
echo "  17.  Intel drivers    — intel-media-driver, libva-utils"
fi
echo

# make yay faster - do not use compression
sudo sed -i "s/PKGEXT=.*/PKGEXT='.pkg.tar'/g" /etc/makepkg.conf
sudo sed -i "s/SRCEXT=.*/SRCEXT='.src.tar'/g" /etc/makepkg.conf

# -----------------------------------------------------
# core packages
# -----------------------------------------------------

echo -e "${GREEN}"
figlet "CorePackages"
echo -e "${NONE}"

# packages
sudo pacman -Sy --needed hyprland rofi-wayland dunst hyprpaper hyprlock hypridle xdg-desktop-portal-hyprland sddm \
                alacritty kitty ghostty vim zsh starship picom qt5-wayland qt6-wayland cliphist \
                thunar gvfs thunar-volman tumbler thunar-archive-plugin ark \
                network-manager-applet blueman brightnessctl \
                slurp grim xclip swappy \
                ttf-font-awesome otf-font-awesome ttf-fira-sans ttf-fira-code   \
                ttf-firacode-nerd gnome-themes-extra gtk-engine-murrine nwg-look \
                --noconfirm
_installPackagesYay waybar-git wlogout waypaper hyprland-qtutils qogir-gtk-theme qogir-icon-theme

# -----------------------------------------------------
# development
# -----------------------------------------------------

# development
echo -e "${GREEN}"
figlet "Git"
echo -e "${NONE}"
echo ":: Sets your global git identity (stored in ~/.gitconfig)."
echo ":: This is used to tag all commits you make on this machine."
git_name=$(_gum input --placeholder "Enter git name...")
echo "Name: ${git_name}"
git_email=$(_gum input --placeholder "Enter git email...")
echo "Email: ${git_email}"
git config --global user.name "${git_name}"
git config --global user.email "${git_email}"
git config --global pull.ff only

echo -e "${GREEN}"
figlet "SSHKey"
echo -e "${NONE}"
echo ":: Generates a new ed25519 SSH key pair (~/.ssh/id_ed25519)."
echo ":: You will be prompted for a file location and passphrase."
echo ":: Upload the public key (~/.ssh/id_ed25519.pub) to GitHub/GitLab afterwards."
if _gum confirm "Generate SSH key now?" ;then
    ssh-keygen -t ed25519 -C "${git_email}"
else
    echo ":: Skipping SSH key generation."
fi

# java
echo -e "${GREEN}"
figlet "Java"
echo -e "${NONE}"
echo ":: Installs JDK 25, Maven, and google-java-format for Java development."
if _gum confirm "Install Java development tools?" ;then
    sudo pacman -Sy --needed jdk25-openjdk maven --noconfirm
    _installPackagesYay google-java-format
else
    echo ":: Skipping Java."
fi

# python
echo -e "${GREEN}"
figlet "Python"
echo -e "${NONE}"
sudo pacman -Sy --needed python-pip --noconfirm

# node
echo -e "${GREEN}"
figlet "Node"
echo -e "${NONE}"
_installPackagesYay nvm
source /usr/share/nvm/init-nvm.sh
nvm install --lts

# docker
echo -e "${GREEN}"
figlet "Docker"
echo -e "${NONE}"
sudo pacman -Sy --needed docker --noconfirm
sudo systemctl enable --now docker.service
sudo usermod -aG docker $USER
sudo pacman -Sy --needed docker-compose --noconfirm

# vscode
echo -e "${GREEN}"
figlet "VSCode"
echo -e "${NONE}"
sudo pacman -Sy --needed gnome-keyring --noconfirm
_installPackagesYay visual-studio-code-bin

# rest client
_installPackagesYay bruno-bin

# neovim
echo -e "${GREEN}"
figlet "Neovim"
echo -e "${NONE}"
sudo pacman -Sy --needed neovim ripgrep fd --noconfirm
_installPackagesYay vim-plug
[ -d ~/.config/nvchad ]    || git clone https://github.com/NvChad/starter ~/.config/nvchad
[ -d ~/.config/astronvim ] || git clone --depth 1 https://github.com/AstroNvim/template ~/.config/astronvim
[ -d ~/.config/lazyvim ]   || git clone https://github.com/LazyVim/starter ~/.config/lazyvim

# -----------------------------------------------------
# apps
# -----------------------------------------------------

# gui apps
echo -e "${GREEN}"
figlet "GUI Apps"
echo -e "${NONE}"
sudo pacman -Sy --needed okular feh gwenview mpv qbittorrent bitwarden qalculate-gtk veracrypt discord --noconfirm
_installPackagesYay onlyoffice-bin brave-bin librewolf-bin zen-browser-bin ventoy-bin

# set default browser
unset BROWSER
xdg-settings set default-web-browser zen-browser.desktop

# terminal utils
echo -e "${GREEN}"
figlet "TerminalUtils"
echo -e "${NONE}"
sudo pacman -Sy --needed tmux yazi fastfetch htop fzf zoxide --noconfirm


# -----------------------------------------------------
# configs and themes
# -----------------------------------------------------

# dotfiles
echo -e "${GREEN}"
figlet "Dotfiles"
echo -e "${NONE}"

if $nvidia ;then
    echo \
"-- Environment Variables
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- https://wiki.hyprland.org/Nvidia/

hl.env(\"LIBVA_DRIVER_NAME\", \"nvidia\")
hl.env(\"XDG_SESSION_TYPE\", \"wayland\")
hl.env(\"GBM_BACKEND\", \"nvidia-drm\")
hl.env(\"__GLX_VENDOR_LIBRARY_NAME\", \"nvidia\")
hl.env(\"NVD_BACKEND\", \"direct\")
hl.env(\"ELECTRON_OZONE_PLATFORM_HINT\", \"auto\")

hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
})" > ./config/hypr/conf/environment.lua

grep -qF 'electron-flickering-fix' ./config/hypr/hyprland.lua || echo \
"
-- Flickering fix
require(\"conf/electron-flickering-fix\")" >> ./config/hypr/hyprland.lua
fi

if $intel ;then
    grep -qF 'LIBVA_DRIVER_NAME' ./config/hypr/conf/environment.lua || echo \
"
-- Intel GPU
-- https://wiki.hyprland.org/FAQ/
hl.env(\"LIBVA_DRIVER_NAME\", \"iHD\")
hl.env(\"VDPAU_DRIVER\", \"va_gl\")" >> ./config/hypr/conf/environment.lua
fi

echo \
"-- Monitor Setup
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
    output   = \"\",
    mode     = \"${resolution}\",
    position = \"auto\",
    scale    = 1,
})" > ./config/hypr/conf/monitor.lua

sed -i "s/^local mainMod = .*/local mainMod = \"$mod\"/" ./config/hypr/conf/keybinding.lua

cp -rf ./config/.gtkrc-2.0 ./config/.Xresources ./config/.bashrc ./config/.zshrc ~/
mkdir -p ~/.config/qBittorrent && cp -rf ./config/qbittorrent/qbittorrent.qbtheme ~/.config/qBittorrent
cp -rf ./config/alacritty ./config/dunst ./config/gtk-3.0 ./config/gtk-4.0 ./config/hypr ./config/picom \
    ./config/kitty ./config/scripts ./config/Thunar ./config/wal ./config/waybar \
    ./config/wlogout ./config/fastfetch ./config/ghostty ./config/starship.toml \
    ~/.config
sudo sed -i "s/Inherits=.*/Inherits=Qogir-Dark/g" /usr/share/icons/default/index.theme

# rofi
echo -e "${GREEN}"
figlet "Rofi"
echo -e "${NONE}"
if [ ! -d ~/.config/rofi ]; then
    git clone --depth=1 https://github.com/adi1090x/rofi.git ~/rofi
    (cd ~/rofi && chmod +x setup.sh && sh setup.sh)
    rm -rf ~/rofi
else
    echo ":: Rofi themes already installed, skipping."
fi

# sddm
echo -e "${GREEN}"
figlet "SDDM"
echo -e "${NONE}"
sudo systemctl enable sddm
if [ ! -d /usr/share/sddm/themes/sddm-astronaut-theme ]; then
    sudo git clone https://github.com/keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/sddm-astronaut-theme
    sudo cp /usr/share/sddm/themes/sddm-astronaut-theme/Fonts/* /usr/share/fonts/
fi
echo "[Theme]
Current=sddm-astronaut-theme" | sudo tee /etc/sddm.conf

# wallpapers and screenshots
echo -e "${GREEN}"
figlet "WallpapersScreenshots"
echo -e "${NONE}"
mkdir -p ~/Pictures/screenshots
[ ! -f ~/Pictures/wallpaper1.jpg ] && cp -r wallpapers/** ~/Pictures

# system configs
echo -e "${GREEN}"
figlet "SystemConfigs"
echo -e "${NONE}"
sudo systemctl enable bluetooth
sudo systemctl enable fstrim.timer

# swapfile
echo -e "${GREEN}"
figlet "Swapfile"
echo -e "${NONE}"
if [ ! -f /swapfile ]; then
    sudo mkswap -U clear --size 8G --file /swapfile
    sudo swapon /swapfile
    echo "/swapfile				  swap		 swap	 defaults   0 0" | sudo tee -a /etc/fstab
else
    echo ":: Swapfile already exists, skipping."
fi


# -----------------------------------------------------
# kernel and drivers
# -----------------------------------------------------

# check for LUKS encryption and ensure dracut crypt module is present
if lsblk -o TYPE | grep -q "crypt"; then
    echo ":: Encrypted drive detected."
    if ! grep -rq 'add_dracutmodules.*crypt' /etc/dracut.conf.d/ 2>/dev/null; then
        echo ":: Adding crypt module to dracut config..."
        echo 'add_dracutmodules+=" crypt "' | sudo tee /etc/dracut.conf.d/crypt.conf
    else
        echo ":: dracut crypt module already configured."
    fi
fi

# zen kernel
echo -e "${GREEN}"
figlet "ZenKernel"
echo -e "${NONE}"
sudo pacman -Sy linux-zen linux-zen-headers --noconfirm
if [[ "$boot" == "systemd" ]]; then
  sudo reinstall-kernels
elif [[ "$boot" == "grub" ]]; then
  sudo dracut-rebuild
  sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# nvidia drivers
if $nvidia ;then
    echo -e "${GREEN}"
    figlet "Nvidia"
    echo -e "${NONE}"
    sudo pacman -Sy --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings libva-nvidia-driver --noconfirm
    grep -qF 'nvidia_drm' /etc/dracut.conf.d/nvidia.conf 2>/dev/null || echo "force_drivers+=\" nvidia nvidia_modeset nvidia_uvm nvidia_drm \"" | sudo tee -a /etc/dracut.conf.d/nvidia.conf
    grep -qF 'nvidia_drm' /etc/modprobe.d/nvidia.conf 2>/dev/null || echo "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a /etc/modprobe.d/nvidia.conf
    if [[ "$boot" == "systemd" ]]; then
      sudo reinstall-kernels
    elif [[ "$boot" == "grub" ]]; then
      sudo dracut-rebuild
      sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
fi

# intel drivers
if $intel ;then
    echo -e "${GREEN}"
    figlet "Intel"
    echo -e "${NONE}"
    sudo pacman -Sy --needed intel-media-driver libva-utils --noconfirm
fi

# cleanup
echo -e "${GREEN}"
figlet "Cleanup"
echo -e "${NONE}"
orphans=$(pacman -Qtdq 2>/dev/null) && sudo pacman -Rns $orphans --noconfirm || echo ":: No orphaned packages to remove."
yay -Sc --noconfirm

# default shell
chsh -s $(which zsh)

echo -e "${GREEN}"
figlet "Done"
echo -e "${NONE}"

echo
echo "DONE! Please reboot your system!"
