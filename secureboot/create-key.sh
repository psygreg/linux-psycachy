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
    wget https://codeberg.org/psygreg/linux-psycachy/raw/branch/main/secureboot/mokconfig.cnf || { echo "Download failed"; exit 1; }
    # create MOK keypair
    openssl req -config ./mokconfig.cnf \
            -new -x509 -newkey rsa:2048 \
            -nodes -days 3650 -outform DER \
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

# Ubuntu signing check
ubuntu_signing () {
    local ubuntu_versions=($(echo "$releases" | jq -r '.[].tag_name' | grep -i '^Ubuntu-' | sed 's/^Ubuntu-//' | sort -Vr))
    for ver in "${ubuntu_versions[@]}"; do
        if [[ -f "/boot/vmlinuz-${ver}-psycachy" ]]; then
            kver_sign="${ver}-psycachy"
            signing
        fi
    done
    echo "No matching Ubuntu PsyCachy kernels found in /boot."
    exit 1
}

# run proper iteration
signing () {
    if [[ -f $HOME/.sb/MOK.pem ]]; then
        cd $HOME/.sb
        # check if key is less than 7 months from expiring
        local expiry_date=$(openssl x509 -enddate -noout -in MOK.pem | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local threshold_epoch=$(date -d "+7 months" +%s)
        if [[ $expiry_epoch -lt $threshold_epoch ]]; then
            whiptail --title "MOK Expiry" --msgbox "Your Machine Owner Key is expiring soon (less than 7 months). A new key will be generated and enrolled." 12 78
            mok_creator
        fi
        sign_upd
        exit 0
    else
        mok_creator
        sign_upd
        exit 0
    fi
}

# runtime
source <(curl -s https://codeberg.org/psygreg/linuxtoys/raw/branch/master/p3/libs/linuxtoys.lib) || { echo "Unable to source lib."; exit 2; }
depcheck
# version checkers
releases=$(curl -s "https://codeberg.org/api/v1/repos/psygreg/linux-psycachy/releases")
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
    --ubuntu | -u)
        ubuntu_signing
        ;;
    esac
fi

# menu
while :; do
    CHOICE=$(whiptail --title "Secure Boot" --menu "Select your kernel edition:" 25 78 16 \
        "PsyCachy" "$kver_psycachy" \
        "PsyCachy-LTS" "$kver_lts" \
        "PsyCachy for Ubuntu" "DKMS-supported" \
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
    "PsyCachy for Ubuntu") ubuntu_signing;;
    CachyOS) kver_sign="$ver_cachy" && signing;;
    Cancel | q) break ;;
    *) echo "Invalid Option" ;;
    esac
done
