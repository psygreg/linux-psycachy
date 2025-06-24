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
    # write country, province and locality with locale
    local COUNTRY_CODE=$(locale | grep -i "^lc_" | grep -m1 -oP "[A-Z]{2}(?=\b)" || echo "US")
    sed -i \
        -e "s|countryName\s\+=\s\+<YOURcountrycode>|countryName             = ${COUNTRY_CODE}|" \
        -e "s|stateOrProvinceName\s\+=\s\+<YOURstate>|stateOrProvinceName     = ${COUNTRY_CODE}|" \
        -e "s|localityName\s\+=\s\+<YOURcity>|localityName            = ${COUNTRY_CODE}|" \
        "mokconfig.cnf"
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

    kver_sign=$(curl -s https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/psy-krn)
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

source <(curl -s https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/linuxtoys.lib) || { echo "Unable to source lib."; exit 2; }
depcheck
if [[ -f $HOME/.sb/MOK.pem ]]; then
    cd $HOME/.sb
    sign_upd
    exit 0
else
    mok_creator
    sign_upd
    exit 0
fi

