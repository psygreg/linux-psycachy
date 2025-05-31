#!/bin/bash
# Description: Script to compile a custom Linux kernel and package it into a .deb file for CachyOS
# Maintainer: Laio O. Seman <laio@iee.org>

# Initialize variables to store user choices -- defaults
_cachyos_config="none"
_cpusched_selection="cachyos"
_llvm_lto_selection="thin"
_tick_rate="1000"
_numa="enable"
_hugepage="always"
_lru_config="standard"
_o3_optimization="yes"
_performance_governor="no"
_nr_cpus="320"
_bbr3="yes"
_march="native"
_preempt="preempt"
_tick_type="nohz_full"

check_deps() {

    # List of dependencies to check
    dependencies=(whiptail gcc git libncurses-dev curl gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm bc rsync)

    # Iterate over dependencies and check each one
    for dep in "${dependencies[@]}"; do
        if dpkg -s "$dep" 2>/dev/null 1>&2; then
            #echo "Package $dep is installed."
            continue
        else
            #echo "Package $dep is NOT installed."
            sudo apt install -y "$dep"
        fi
    done

}

# Check if GCC is installed
check_gcc() {
    if ! [ -x "$(command -v gcc)" ]; then
        # Display error message if GCC is not installed
        echo "Error: GCC is not installed. Please install GCC and try again." >&2
        exit 1
    fi
}

# Original function used in the CachyOS mainline
init_script() {
    # Call the function before running the rest of the script
    check_gcc

    # Get CPU type from GCC and convert to uppercase
    MARCH=$(gcc -Q -march=native --help=target | grep -m1 march= | awk '{print toupper($2)}')

    # Check for specific CPU types and set MARCH variable accordingly
    case $MARCH in
    ZNVER1) MARCH="ZEN" ;;
    ZNVER2) MARCH="ZEN2" ;;
    ZNVER3) MARCH="ZEN3" ;;
    ZNVER4) MARCH="ZEN4" ;;
    BDVER1) MARCH="BULLDOZER" ;;
    BDVER2) MARCH="PILEDRIVER" ;;
    BDVER3) MARCH="STEAMROLLER" ;;
    BDVER4) MARCH="EXCAVATOR" ;;
    BTVER1) MARCH="BOBCAT" ;;
    BTVER2) MARCH="JAGUAR" ;;
    AMDFAM10) MARCH="MK10" ;;
    K8-SSE3) MARCH="K8SSE3" ;;
    BONNELL) MARCH="ATOM" ;;
    GOLDMONT-PLUS) MARCH="GOLDMONTPLUS" ;;
    SKYLAKE-AVX512) MARCH="SKYLAKEX" ;;
    MIVYBRIDGE)
        scripts/config --disable CONFIG_AGP_AMD64
        scripts/config --disable CONFIG_MICROCODE_AMD
        MARCH="MIVYBRIDGE"
        ;;
    ICELAKE-CLIENT) MARCH="ICELAKE" ;;
    esac

    # Add "M" prefix to MARCH variable
    MARCH2=M${MARCH}

    # show whiptail screen for the found CPU and ask if it is correct
    whiptail --title "CPU Architecture" --yesno "Detected CPU (MARCH) : ${MARCH2}\nIs this correct?" 10 60
    if [ $? -eq 1 ]; then
        # if not correct, ask for the CPU type
        MARCH2=$(whiptail --title "CPU Architecture" --inputbox "Enter CPU type (MARCH):" 10 60 "$MARCH2" 3>&1 1>&2 2>&3)
    fi

    # Display detected CPU and apply optimization
    echo "----------------------------------"
    echo "| APPLYING AUTO-CPU-OPTIMIZATION |"
    echo "----------------------------------"
    echo "[*] DETECTED CPU (MARCH) : ${MARCH2}"

    # define _march as MARCH2
    _march=$MARCH2
}

export NEWT_COLORS='
    root=white,blue
    border=black,lightgray
    window=black,lightgray
    shadow=black,gray
    title=black,lightgray
    button=black,cyan
    actbutton=white,blue
    checkbox=black,lightgray
    actcheckbox=black,cyan
    entry=black,lightgray
    label=black,lightgray
    listbox=black,lightgray
    actlistbox=black,cyan
    textbox=black,lightgray
    acttextbox=black,cyan
    helpline=white,blue
    roottext=black,lightgray
'

configure_cachyos() {
    local cachyos_status=$([ "$_cachyos_config" = "CACHYOS" ] && echo "ON" || echo "OFF")
    local selection

    whiptail --title "CachyOS Configuration" --checklist \
        "Select optimizations to enable:" 20 78 1 \
        "CachyOS" "" $cachyos_status \
        3>&1 1>&2 2>&3

    if [[ "$selection" == *"CachyOS"* ]]; then
        _cachyos_config="CACHYOS"
    else
        _cachyos_config="none"
    fi
}

# Function to configure CPU scheduler
configure_cpusched() {
    # Show radiolist and capture user selection
    _cpusched_selection=$(whiptail --title "CPU Scheduler Configuration" --radiolist \
        "Choose CPU Scheduler (use space to select):" 20 70 5 \
        "cachyos" "Default BORE + SCHED-EXT scheduler" $([ "$_cpusched_selection" = "cachyos" ] && echo "ON" || echo "OFF") \
        "bore" "BORE scheduler" $([ "$_cpusched_selection" = "bore" ] && echo "ON" || echo "OFF") \
        "rt" "Real-time preemption patch" $([ "$_cpusched_selection" = "rt" ] && echo "ON" || echo "OFF") \
        "rt-bore" "Real-time preemption with BORE scheduler" $([ "$_cpusched_selection" = "rt-bore" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure CPU scheduler" $([ "$_cpusched_selection" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure LLVM LTO
configure_llvm_lto() {
    _llvm_lto_selection=$(whiptail --title "LLVM LTO Configuration" --radiolist \
        "Choose LLVM LTO (use space to select):" 15 60 3 \
        "thin" "Enable LLVM LTO Thin" $([ "$_llvm_lto_selection" = "thin" ] && echo "ON" || echo "OFF") \
        "full" "Enable LLVM LTO Full" $([ "$_llvm_lto_selection" = "full" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure LLVM LTO" $([ "$_llvm_lto_selection" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure tick rate for 100|250|500|600|750|1000)
configure_tick_rate() {
    _tick_rate=$(whiptail --title "Tick Rate Configuration" --radiolist \
        "Choose Tick Rate (use space to select):" 15 60 3 \
        "100" "100 Hz" $([ "$_tick_rate" = "100" ] && echo "ON" || echo "OFF") \
        "250" "250 Hz" $([ "$_tick_rate" = "250" ] && echo "ON" || echo "OFF") \
        "500" "500 Hz" $([ "$_tick_rate" = "500" ] && echo "ON" || echo "OFF") \
        "600" "600 Hz" $([ "$_tick_rate" = "600" ] && echo "ON" || echo "OFF") \
        "750" "750 Hz" $([ "$_tick_rate" = "750" ] && echo "ON" || echo "OFF") \
        "1000" "1000 Hz" $([ "$_tick_rate" = "1000" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)

}

# Function to configure NR_CPUS
configure_nr_cpus() {
    _nr_cpus=$(whiptail --title "NR_CPUS Configuration" --inputbox "Enter NR_CPUS value:" 10 60 "$_nr_cpus" 3>&1 1>&2 2>&3)
}

# Function to configure Hugepages
configure_hugepages() {
    _hugepage=$(whiptail --title "Hugepages Configuration" --radiolist \
        "Choose Hugepages (use space to select):" 15 60 3 \
        "always" "Always use hugepages" $([ "$_hugepage" = "always" ] && echo "ON" || echo "OFF") \
        "madvise" "Use hugepages with madvise" $([ "$_hugepage" = "madvise" ] && echo "ON" || echo "OFF") \
        "no" "Do not configure Hugepages" $([ "$_hugepage" = "no" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure LRU
configure_lru() {
    _lru_config=$(whiptail --title "LRU Configuration" --radiolist \
        "Choose LRU (use space to select):" 15 60 3 \
        "standard" "Standard LRU" $([ "$_lru_config" = "standard" ] && echo "ON" || echo "OFF") \
        "stats" "LRU with stats" $([ "$_lru_config" = "stats" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure LRU" $([ "$_lru_config" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

# Function to configure tick type
configure_tick_type() {
    _tick_type=$(whiptail --title "Tick Type Configuration" --radiolist \
        "Choose Tick Type (use space to select):" 15 60 3 \
        "periodic" "Periodic tick" $([ "$_tick_type" = "periodic" ] && echo "ON" || echo "OFF") \
        "nohz_full" "Full dynticks" $([ "$_tick_type" = "nohz_full" ] && echo "ON" || echo "OFF") \
        "nohz_idle" "Idle dynticks" $([ "$_tick_type" = "nohz_idle" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

configure_preempt_type() {
    _preempt=$(whiptail --title "Preempt Type Configuration" --radiolist \
        "Choose Preempt Type (use space to select):" 15 60 3 \
        "voluntary" "Voluntary Preemption" $([ "$_preempt" = "voluntary" ] && echo "ON" || echo "OFF") \
        "preempt" "Preemptible Kernel" $([ "$_preempt" = "preempt" ] && echo "ON" || echo "OFF") \
        "none" "Do not configure Preempt Type" $([ "$_preempt" = "none" ] && echo "ON" || echo "OFF") \
        3>&1 1>&2 2>&3)
}

configure_system_optimizations() {
    # Initialize status of each optimization
    local o3_status=$([ "$_o3_optimization" = "yes" ] && echo "ON" || echo "OFF")
    local os_status=$([ "$_os_optimization" = "yes" ] && echo "ON" || echo "OFF")
    local performance_status=$([ "$_performance_governor" = "yes" ] && echo "ON" || echo "OFF")
    local bbr3_status=$([ "$_bbr3" = "yes" ] && echo "ON" || echo "OFF")
    local vma_status=$([ "$_vma" = "yes" ] && echo "ON" || echo "OFF")
    local damon_status=$([ "$_damon" = "yes" ] && echo "ON" || echo "OFF")
    local numa_status=$([ "$_numa" = "enable" ] && echo "ON" || echo "OFF")
    local zfs_status=$([ "$_zfs" = "yes" ] && echo "ON" || echo "OFF")

    # Display checklist
    local selection
    selection=$(whiptail --title "System Optimizations Configuration" --checklist \
        "Select optimizations to enable:" 20 78 6 \
        "O3 Optimization" "" $o3_status \
        "OS Optimization" "" $os_status \
        "Performance Governor" "" $performance_status \
        "TCP BBR3" "" $bbr3_status \
        "VMA" "" $vma_status \
        "DAMON" "" $damon_status \
        "NUMA" "" $numa_status \
        "ZFS" "" $zfs_status \
        3>&1 1>&2 2>&3)

    # Update configurations based on the selection
    if [[ "$selection" == *"O3 Optimization"* ]]; then
        _o3_optimization="yes"
        _os_optimization="no" # Disable OS Optimization if O3 Optimization is selected
    else
        _o3_optimization="no"
    fi

    if [[ "$selection" == *"OS Optimization"* ]]; then
        _os_optimization="yes"
        _o3_optimization="no" # Disable O3 Optimization if OS Optimization is selected
    else
        _os_optimization="no"
    fi

    [[ "$selection" == *"Performance Governor"* ]] && _performance_governor="yes" || _performance_governor="no"
    [[ "$selection" == *"TCP BBR3"* ]] && _bbr3="yes" || _bbr3="no"
    [[ "$selection" == *"VMA"* ]] && _vma="yes" || _vma="no"
    [[ "$selection" == *"DAMON"* ]] && _damon="yes" || _damon="no"
    [[ "$selection" == *"NUMA"* ]] && _numa="enable" || _numa="disable"
}

choose_kernel_option() {

    # menu
    while :; do

        CHOICE=$(whiptail --title "Kernel Version" --menu "Select:" 25 78 16 \
            "Latest" "$_kv_latest" \
            "Stable" "$_kver_stable" \
            "Cancel" "" 3>&1 1>&2 2>&3)

        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            # Exit the script if the user presses Esc
            break
        fi

        case $CHOICE in
        Latest) _kv_name=$_kv_latest && _kv_url=$_kv_url_latest;;
        Stable) _kv_name=$_kver_stable && _kv_url=$_kv_url_stable;;
        Cancel | q) break ;;
        *) echo "Invalid Option" ;;
        esac
    done
    # show kernel version to the user in a box and ask to confirm
    whiptail --title "Kernel Version" --msgbox "The chosen kernel version is $_kv_name" 8 78

}

debing() {
    #!/bin/bash
    # Description: Script to compile a custom Linux kernel and package it into a .deb file for CachyOS
    # Maintainer: Laio O. Seman <laio@iee.org>

    KERNEL_VERSION=$(make kernelversion)
    ARCH=$(dpkg --print-architecture)

    # Kernel package variables
    KERNEL_PKG_NAME=custom-kernel-${KERNEL_VERSION}
    KERNEL_PKG_VERSION=${KERNEL_VERSION}-1
    KERNEL_PKG_DIR=${KERNEL_PKG_NAME}-${KERNEL_PKG_VERSION}

    # Headers package variables
    HEADERS_PKG_NAME=custom-kernel-headers-${KERNEL_VERSION}
    HEADERS_PKG_VERSION=${KERNEL_VERSION}-1
    HEADERS_PKG_DIR=${HEADERS_PKG_NAME}-${HEADERS_PKG_VERSION}

    # Function to create kernel package
    package_kernel() {
        # Create directory structure for kernel package
        mkdir -p ${KERNEL_PKG_DIR}/DEBIAN
        mkdir -p ${KERNEL_PKG_DIR}/boot
        mkdir -p ${KERNEL_PKG_DIR}/lib/modules/${KERNEL_VERSION}
        mkdir -p ${KERNEL_PKG_DIR}/usr/share/doc/${KERNEL_PKG_NAME}

        # Create control file for kernel package
        cat >${KERNEL_PKG_DIR}/DEBIAN/control <<EOF
Package: ${KERNEL_PKG_NAME}
Version: ${KERNEL_PKG_VERSION}
Section: kernel
Priority: optional
Architecture: ${ARCH}
Maintainer: CachyOs
Description: Custom compiled Linux Kernel
 Custom compiled Linux Kernel ${KERNEL_VERSION}
EOF

        # Copy the compiled kernel and modules
        cp arch/x86/boot/bzImage ${KERNEL_PKG_DIR}/boot/vmlinuz-${KERNEL_VERSION}
        cp -a /tmp/kernel-modules/lib/modules/${KERNEL_VERSION}/* ${KERNEL_PKG_DIR}/lib/modules/${KERNEL_VERSION}/
        cp System.map ${KERNEL_PKG_DIR}/boot/System.map-${KERNEL_VERSION}
        cp .config ${KERNEL_PKG_DIR}/boot/config-${KERNEL_VERSION}

        # Package the kernel
        fakeroot dpkg-deb --build ${KERNEL_PKG_DIR}

        # Clean up kernel package directory
        rm -rf ${KERNEL_PKG_DIR}
    }

    # Function to create headers package
    package_headers() {
        # Create directory structure for headers package
        mkdir -p ${HEADERS_PKG_DIR}/DEBIAN
        mkdir -p ${HEADERS_PKG_DIR}/usr/src/linux-headers-${KERNEL_VERSION}

        # Create control file for headers package
        cat >${HEADERS_PKG_DIR}/DEBIAN/control <<EOF
Package: ${HEADERS_PKG_NAME}
Version: ${HEADERS_PKG_VERSION}
Section: kernel
Priority: optional
Architecture: ${ARCH}
Maintainer: CachyOs
Description: Headers for custom compiled Linux Kernel ${KERNEL_VERSION}
EOF

        # Copy the kernel headers
        make headers_install INSTALL_HDR_PATH=${HEADERS_PKG_DIR}/usr/src/linux-headers-${KERNEL_VERSION}

        # Package the headers
        fakeroot dpkg-deb --build ${HEADERS_PKG_DIR}

        # Clean up headers package directory
        rm -rf ${HEADERS_PKG_DIR}
    }

    package_zfs() {

        ZFS_PKG_DIR=zfs-${KERNEL_VERSION}

        # Create directory structure for ZFS package
        mkdir -p ${ZFS_PKG_DIR}/DEBIAN

        # Create control file for ZFS package
        cat >zfs-${KERNEL_VERSION}/DEBIAN/control <<EOF
Package: zfs-${KERNEL_VERSION}
Version: ${KERNEL_PKG_VERSION}
Section: kernel
Priority: optional
Architecture: ${ARCH}
Maintainer: CachyOs
Description: ZFS for custom compiled Linux Kernel ${KERNEL_VERSION}
EOF

        # Copy the ZFS modules
        install -m644 module/*.ko "${ZFS_PKG_DIR}/lib/modules/${KERNEL_VERSION}/extra"
        find "$ZFS_PKG_DIR" -name '*.ko' -exec zstd --rm -10 {} +

        # Package the ZFS modules
        fakeroot dpkg-deb --build ${ZFS_PKG_DIR}

        # Clean up ZFS package directory
        rm -rf ${ZFS_PKG_DIR}
    }


    # Compile the kernel and modules
    make -j$(nproc)
    mkdir -p /tmp/kernel-modules
    make modules_install INSTALL_MOD_PATH=/tmp/kernel-modules

    if [ "$_zfs" == "yes" ]; then
        LINUX_DIR=$(pwd)
        git clone https://github.com/openzfs/zfs --depth 1
        cd zfs

        ./autogen.sh
        ./configure --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin \
            --libdir=/usr/lib --datadir=/usr/share --includedir=/usr/include \
            --with-udevdir=/lib/udev --libexecdir=/usr/lib/zfs --with-config=kernel \
            --with-linux=$(LINUX_DIR)
        make -j$(nproc)
        cd $LINUX_DIR
    fi

    # Package the kernel
    package_kernel

    # Package the headers
    package_headers
    if [ "$_zfs" == "yes" ]; then
        package_zfs
    fi
    
}


do_things() {

    # create btrfs snapshot if functionality available
    if [ "$(findmnt -n -o FSTYPE /)" = "btrfs" ]; then
        if command -v snapper &> /dev/null; then
            snapper -c root create -c pre --description kernel update
        fi
    fi

    # define _major as the first two digits of the kernel version
    _major=$(echo $_kv_name | grep -oP '^\K[^\.]+')

    # middle number
    _mid=$(echo $_kv_name | grep -oP '^\d+\.\K[^\.]+')

    # download kernel to linux.tar.xz
    wget -c $_kv_url -O linux.tar.xz
    # extract kernel
    tar -xf linux.tar.xz
    # enter kernel directory

    cd linux-$_kv_name

    # get cachyos .config
    wget -c https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos/config -O .config

    local _patchsource="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${_major}.${_mid}"

    # create empty source array of patches
    declare -a patches=()

    # Apply CachyOS configuration
    if [ "$_cachyos_config" == "CACHYOS" ]; then
        scripts/config -e CACHYOS
        patches+=("${_patchsource}/all/0001-cachyos-base-all.patch")
    fi

    ## List of CachyOS schedulers
    case "$_cpusched_selection" in
    cachyos) # CachyOS Scheduler (BORE + SCHED-EXT)
        patches+=("${_patchsource}/sched/0001-bore-cachy.patch") ;;
    bore) ## BORE Scheduler
        patches+=("${_patchsource}/sched/0001-bore.patch") ;;
    rt) ## EEVDF with RT patches
        patches+=("${_patchsource}/misc/0001-rt-i915.patch"
            linux-cachyos-rt.install) ;;
    rt-bore) ## RT with BORE Scheduler
        patches+=("${_patchsource}/misc/0001-rt-i915.patch"
            "${_patchsource}/sched/0001-bore.patch"
            linux-cachyos-rt.install) ;;
    esac

    # download and apply patches on source
    for i in "${patches[@]}"; do
        echo "Downloading and applying $i"
        wget -c $i
        patch -p1 <$(basename $i)
    done

    # set architecture
    scripts/config -k --disable CONFIG_GENERIC_CPU
    scripts/config -k --enable CONFIG_${MARCH2}

    case "$_cpusched_config" in
    cachyos) scripts/config -e SCHED_BORE -e SCHED_CLASS_EXT ;;
    bore | hardened) scripts/config -e SCHED_BORE ;;
    eevdf) ;;
    rt) scripts/config -e PREEMPT_COUNT -e PREEMPTION -d PREEMPT_VOLUNTARY -d PREEMPT -d PREEMPT_NONE -e PREEMPT_RT -d PREEMPT_DYNAMIC -d PREEMPT_BUILD ;;
    rt-bore) scripts/config -e SCHED_BORE -e PREEMPT_COUNT -e PREEMPTION -d PREEMPT_VOLUNTARY -d PREEMPT -d PREEMPT_NONE -e PREEMPT_RT -d PREEMPT_DYNAMIC -d PREEMPT_BUILD ;;
    sched-ext) scripts/config -e SCHED_CLASS_EXT ;;
    esac

    case "$_preempt" in
    full) scripts/config -e PREEMPT_BUILD -d PREEMPT_NONE -d PREEMPT_VOLUNTARY -e PREEMPT -e PREEMPT_COUNT -e PREEMPTION -e PREEMPT_DYNAMIC ;;
    voluntary) scripts/config -e PREEMPT_BUILD -d PREEMPT_NONE -e PREEMPT_VOLUNTARY -d PREEMPT -e PREEMPT_COUNT -e PREEMPTION -d PREEMPT_DYNAMIC ;;
    server) scripts/config -e PREEMPT_NONE_BUILD -e PREEMPT_NONE -d PREEMPT_VOLUNTARY -d PREEMPT -d PREEMPTION -d PREEMPT_DYNAMIC ;;
    esac

    # Apply LLVM LTO configuration
    case "$_llvm_lto_selection" in
    thin) scripts/config -e LTO_CLANG_THIN ;;
    full) scripts/config -e LTO_CLANG_FULL ;;
    none) scripts/config -d LTO_CLANG_THIN -d LTO_CLANG_FULL ;;
    esac

    # Apply tick rate configuration
    case "$_tick_rate" in
    100 | 250 | 500 | 600 | 750 | 1000)
        scripts/config -d HZ_300 -e "HZ_${_tick_rate}" --set-val HZ "${_tick_rate}"
        ;;
    300)
        scripts/config -e HZ_300 --set-val HZ 300
        ;;
    esac

    case "$_tick_type" in
    perodic) scripts/config -d NO_HZ_IDLE -d NO_HZ_FULL -d NO_HZ -d NO_HZ_COMMON -e HZ_PERIODIC ;;
    idle) scripts/config -d HZ_PERIODIC -d NO_HZ_FULL -e NO_HZ_IDLE -e NO_HZ -e NO_HZ_COMMON ;;
    full) scripts/config -d HZ_PERIODIC -d NO_HZ_IDLE -d CONTEXT_TRACKING_FORCE -e NO_HZ_FULL_NODEF -e NO_HZ_FULL -e NO_HZ -e NO_HZ_COMMON -e CONTEXT_TRACKING ;;
    esac

    # Apply NUMA configuration
    case "$_numa" in
    enable) scripts/config -e NUMA ;;
    disable) scripts/config -d NUMA ;;
    none) ;; # Do nothing for 'none'
    esac

    # Apply Hugepages configuration
    case "$_hugepage" in
    always) scripts/config -d TRANSPARENT_HUGEPAGE_MADVISE -e TRANSPARENT_HUGEPAGE_ALWAYS ;;
    madvise) scripts/config -d TRANSPARENT_HUGEPAGE_ALWAYS -e TRANSPARENT_HUGEPAGE_MADVISE ;;
    no) ;; # Do nothing for 'no'
    esac

    # setting nr_cpus
    scripts/config --set-val NR_CPUS "$_nr_cpus"

    # Apply LRU configuration
    case "$_lru_config" in
    standard) scripts/config -e LRU_GEN -e LRU_GEN_ENABLED -d LRU_GEN_STATS ;;
    stats) scripts/config -e LRU_GEN -e LRU_GEN_ENABLED -e LRU_GEN_STATS ;;
    none) scripts/config -d LRU_GEN ;;
    esac

    # Apply O3 optimization
    if [ "$_o3_optimization" == "yes" ]; then
        scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3
    fi

    # Apply performance governor
    if [ "$_performance_governor" == "yes" ]; then
        scripts/config -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL -e CPU_FREQ_DEFAULT_GOV_PERFORMANCE
    fi

    echo "Configurations applied."

    # Make the kernel calling debing
    debing

    # Install compiled kernel
    sudo dpkg -i $HOME/cachyos-deb/linux-$_kv_name/custom-kernel-$KERNEL_VERSION-$KERNEL_VERSION-1.deb $HOME/cachyos-deb/linux-$_kv_name/custom-kernel-headers-$KERNEL_VERSION-$KERNEL_VERSION-1.deb

    # Create boot image and update grub
    sudo update-initramfs -c -k $KERNEL_VERSION
    sudo update-grub2

}

# Write settings to file on first installation
first_install () {

    cd $HOME
    mkdir cachyos-deb
    cd cachyos-deb
    do_things
    {   
        echo "_cachyos_config=${_cachyos_config}"
        echo "_cpusched_selection=${_cpusched_selection}"
        echo "_llvm_lto_selection=${_llvm_lto_selection}"
        echo "_tick_rate=${_tick_rate}"
        echo "_numa=${_numa}"
        echo "_hugepage=${_hugepage}"
        echo "_lru_config=${_lru_config}"
        echo "_o3_optimization=${_o3_optimization}"
        echo "_performance_governor=${_performance_governor}"
        echo "_nr_cpus=${_nr_cpus}"
        echo "_bbr3=${_bbr3}"
        echo "_march=${_march}"
        echo "_preempt=${_preempt}"
        echo "_tick_type=${_tick_type}"
    } > $HOME/.local/kernelsetting

}

# Source settings from existing file for updates
kernel_upd () {

    if [ "$(uname -r)" != $_kv_name ]; then
        if [ -f "$HOME/.local/kernelsetting" ]; then
            source $HOME/.local/kernelsetting
            cd $HOME
            mkdir cachyos-deb
            cd cachyos-deb
            do_things
            cd ..
            rm -rf cachyos-deb
        else
            whiptail --title "Update failed." --msgbox "Settings file missing. Did you install this kernel previously?" 8 78
        fi
    else
        whiptail --title "Update failed." --msgbox "Your kernel is already up to date." 8 78
    fi

}

# check if any argument was passed

if [ -n "$1" ]; then
    case "$1" in
    --help | -h)
        echo "Usage: $0"
        echo "Compile a custom Linux kernel and package it into a .deb file for CachyOS"
        exit 0
        ;;
    --build | -b)
        debing
        exit 0
        ;;
    esac
fi

_kv_url_latest=$(curl -s https://www.kernel.org | grep -A 1 'id="latest_link"' | awk 'NR==2' | grep -oP 'href="\K[^"]+')
# extract only the version number
_kv_latest=$(echo $_kv_url_latest | grep -oP 'linux-\K[^"]+')
# remove the .tar.xz extension
_kv_latest=$(basename $_kv_latest .tar.xz)

# initialize variables for stable kernel
_kver_stable_ref="6"
_kver_stable="6.14.9"
_kv_url_stable="https://cdn.kernel.org/pub/linux/kernel/v${_kver_stable_ref}.x/linux-${_kver_stable}.tar.xz"

# set default kernel setting to stable
_kv_name=${_kver_stable}
_kv_url=${_kv_url_stable}

# call init script
# display warning message saying this is a beta version

# run the check_deps function and store the result in dep_status
check_deps

whiptail --title "CachyOS Kernel Configuration" --msgbox "This is a beta version of the CachyOS Kernel Configuration script. Use at your own risk." 8 78

# say that the user will lose the ability to use secure boot and ask for confirmation
whiptail --title "Secure Boot Warning" --yesno "This script will disable secure boot. Do you want to continue?" 8 78

init_script


# Main menu
while :; do

    CHOICE=$(whiptail --title "Kernel Configuration Menu" --menu "Choose an option" 25 78 16 \
        "0" "Choose Kernel Version ($_kv_name)" \
        "1" "Configure CachyOS" \
        "2" "Configure CPU Scheduler" \
        "3" "Configure LLVM LTO" \
        "4" "Configure Tick Rate" \
        "5" "Configure NR_CPUS" \
        "6" "Configure Tick Type" \
        "7" "Configure Preempt Type" \
        "8" "Configure LRU" \
        "9" "Configure Hugepages" \
        "10" "Configure System Optimizations" \
        "11" "COMPILE AND INSTALL KERNEL" \
        "12" "UPDATE KERNEL" \
        "13" "Exit" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus != 0 ]; then
        # Exit the script if the user presses Esc
        break
    fi

    case $CHOICE in
    0) choose_kernel_option ;;
    1) configure_cachyos ;;
    2) configure_cpusched ;;
    3) configure_llvm_lto ;;
    4) configure_tick_rate ;;
    5) configure_nr_cpus ;;
    6) configure_tick_type ;;
    7) configure_preempt_type ;;
    8) configure_lru ;;
    9) configure_hugepages ;;
    10) configure_system_optimizations ;;
    11) first_install ;;
    12) kernel_upd ;;
    13 | q) cd $HOME
            rm -rf cachyos-deb
            break ;;
    *) echo "Invalid Option" ;;
    esac
done
