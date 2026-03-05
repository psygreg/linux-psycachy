#!/bin/bash
# Read version from command line argument
if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 6.17.13"
    exit 1
fi
v_full="$1"
v_base="v$(echo "$v_full" | cut -d. -f1).x"

# dependency handling
dep_miss=()
dependencies=(libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm gcc)
for dep in "${dependencies[@]}"; do
    if ! dpkg -s "$dep" &> /dev/null; then
        dep_miss+=("$dep")
    else
        echo "Dependency already installed: $dep"
    fi
done
if [ ${#dep_miss[@]} -ne 0 ]; then
    echo "Installing missing dependencies: ${dep_miss[*]}"
    sudo apt-get update
    sudo apt-get install -y "${dep_miss[@]}"
fi

# kernel patching
cd src
wget "https://www.kernel.org/pub/linux/kernel/$v_base/linux-$v_full.tar.gz"
tar -xvzf "linux-$v_full.tar.gz"
cp config "linux-$v_full/.config"
cd "linux-$v_full"
for patch in ../*.patch; do
    echo "Applying patch: $patch"
    patch -Np1 < "$patch"
done

# kernel build
cp ../config .config
make olddefconfig
make CC=gcc bindeb-pkg -j"$(($(nproc) - 2))" LOCALVERSION=-"psycachy" KDEB_PKGVERSION="$(make kernelversion)-3"
echo "Kernel build complete."
