#!/bin/

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
wget https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.14.11.tar.gz
tar -xvzf linux-6.14.11.tar.gz
cp config linux-6.14.11/.config
cd linux-6.14.11
for patch in ../*.patch; do
    echo "Applying patch: $patch"
    patch -Np1 < "$patch"
done

# kernel build
make CC=gcc bindeb-pkg -j"$(($(nproc) - 1))" LOCALVERSION=-"psycachy" KDEB_PKGVERSION="$(make kernelversion)-3"
echo "Kernel build complete."

