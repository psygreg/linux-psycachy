#!/bin/bash
# dependency check
depcheck () {

    local _packages=(mokutil sbsigntool wget curl openssl)
    _install_

}

# create MOK
mok_creator () {

    mkdir -p $HOME/.sb
    sleep 1
    cd $HOME/.sb
    wget https://raw.githubusercontent.com/psygreg/linux-cachyos-deb/master/secureboot/mokconfig.cnf || { echo "Download failed"; exit 1; }
    # create MOK keypair
    openssl req -config ./mokconfig.cnf \
            -new -x509 -newkey rsa:2048 \
            -nodes -days 36500 -outform DER \
            -keyout "MOK.priv" \
            -out "MOK.der"
    # create PEM
    openssl x509 -in MOK.der -inform DER -outform PEM -out MOK.pem
    # enroll MOK
    whiptail --title "MOK" --msgbox "Your Machine Owner Key will be imported to Secure Boot now. It will require you to create a password. Make sure it is stored somewhere safe!" 12 78
    sudo mokutil --import MOK.der

}

# sign kernel
sign_upd () {

    local kernel_path="/boot/vmlinuz-${kver_sign}"
    [[ -f "$kernel_path" ]] || { echo "Kernel not found: $kernel_path"; exit 3; }
    sudo sbsign --key MOK.priv --cert MOK.pem /boot/vmlinuz-${kver_sign} --output /boot/vmlinuz-${kver_sign}.signed
    sudo cp /boot/initrd.img-${kver_sign}{,.signed}
    sleep 1
    sudo mv /boot/vmlinuz-${kver_sign}{.signed,}
    sudo mv /boot/initrd.img-${kver_sign}{.signed,}
    sleep 1
    sudo update-grub

}

# run proper iteration
signing () {

    if [[ -f $HOME/.sb/MOK.pem ]]; then
        cd $HOME/.sb
        sign_upd
        exit 0
    else
        mok_creator
        sign_upd
        exit 0
    fi

}

# runtime -- FIX SOURCE WHEN LT5 IS OUT!!
source <(curl -s https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/linuxtoys.lib) || { echo "Unable to source lib."; exit 2; }
depcheck
# version checkers
releases=$(curl -s "https://api.github.com/repos/psygreg/linux-psycachy/releases")
lts_tag=$(echo "$releases" | jq -r '.[].tag_name' | grep -i '^LTS-' | sort -Vr | head -n 1)
std_tag=$(echo "$releases" | jq -r '.[].tag_name' | grep -i '^STD-' | sort -Vr | head -n 1)
kver_lts="${lts_tag#LTS-}"
kver_psycachy="${std_tag#STD-}"
kver_url_latest=$(curl -s https://www.kernel.org | grep -A 1 'id="latest_link"' | awk 'NR==2' | grep -oP 'href="\K[^"]+')
kver_latest=$(echo $kver_url_latest | grep -oP 'linux-\K[^"]+')
# remove .tar.xz from version name
kver_latest=$(basename $kver_latest .tar.xz)
ver_psy="$kver_psycachy-psycachy"
ver_cachy="$kver_latest-cachyos"
ver_psy_lts="$kver_lts-psycachy-lts"

# flag for linuxtoys bypass
if [ -n "$1" ]; then
    case "$1" in
    --help | -h)
        echo "Usage: $0"
        echo "Sign your custom kernel for Secure Boot"
        exit 0
        ;;
    --linuxtoys | -l)
        kver_sign="$ver_psy" && signing
        ;;
    --lts)
        kver_sign="$ver_psy_lts" && signing
        ;;
    esac
fi

# menu
while :; do

    CHOICE=$(whiptail --title "Secure Boot" --menu "Select your kernel edition:" 25 78 16 \
        "PsyCachy" "$kver_psycachy" \
        "PsyCachy-LTS" "$kver_lts" \
        "CachyOS" "Latest" \
        "Cancel" "" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus != 0 ]; then
        # Exit the script if the user presses Esc
        break
     fi

    case $CHOICE in
    PsyCachy) kver_sign="$ver_psy" && signing;;
    PsyCachy-LTS) kver_sign="$ver_psy_lts" && signing;;
    CachyOS) kver_sign="$ver_cachy" && signing;;
    Cancel | q) break ;;
    *) echo "Invalid Option" ;;
    esac

done
