# PsyCachy Kernel
This repository contains the releases of the `linux-psycachy` kernel, and the script for building that and custom variants. The script may automate the process of configuring and optimizing the kernel build according to your hardware and preferences.

## For those on GitHub
This is a mirror of the [official repository](https://git.linux.toys/psygreg/linux-psycachy) in which this project is active. If you wish to contribute, consider heading there instead to be credited in the contributors.

# What's this about?
PsyCachy is a kernel with improved settings for compatibility and stability across Debian/Ubuntu Linux distributions derived from linux-cachyos. Releases are made targeting Ubuntu rolling and LTS with *dkms* module compatibility, since it's the most widely used version, but you are free to build it for other kernel versions and distributions for yourself like Debian using the `proto` branch.
### Differences to `linux-cachyos`
- Built with `gcc`, as `clang` caused too many inconsistencies due to `llvm` bugs.
- Doesn't include processor architecture-specific optimizations, as they bring too small gains to justify the time compiling them or the confusion caused to newcomers by multiple kernel versions on release - you can include those by building the kernel yourself running `cachyos-deb.sh` with `-b` option if you wish.
- Doesn't include handheld console drivers, as there isn't much of a point on doing it for Debian/Ubuntu.
- ~~OS/-o2 optimization instead of -o3, which caused quite a few problems with Debian/Ubuntu packages.~~ Now it builds -o3 by default, fixed.

# Recommended usage (for most people)
Install the kernel image of your choice from [Releases](https://github.com/psygreg/linux-psycachy/releases) or through [LinuxToys](https://git.linux.toys/psygreg/linuxtoys). 

## Manual installation
- Download **all three** .deb packages
- Open terminal in the same directory of the packages
- `sudo dpkg -i linux-image-psycachy_6.14.11-1_amd64.deb linux-headers-psycachy_6.14.11-1_amd64.deb linux-libc-dev_6.14.11-1_amd64.deb`, replacing 6.14.11 with your package version
- To install CachyOS SystemD configuration files as well to maximize effectiveness, download and run `cachyconfs.sh` available from *Releases* or [LinuxToys](https://git.linux.toys/psygreg/linuxtoys).

## Secure Boot
You can make the kernel compatible with Secure Boot by signing it using `create-key.sh` available from *Releases*. Remember to store the password you set when the keypair is created carefully as it will be required to import the MOK into BIOS.

# Building
## Prerequisites
Before running the script, ensure you have the following prerequisites installed:

- `libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm gcc rustc`: for compiling the kernel.
- `whiptail`: For displaying dialog boxes in the script.
- `curl`: For fetching the latest kernel version.
- `devscripts` and `debhelper`: For packaging.

You can install these dependencies using your distribution's package manager, or have the build scripts install them for you.

## Features
The builder in `proto` offers a variety of configuration options:

- Auto-detection of CPU architecture for optimization.
- Selection of CachyOS specific optimizations.
- Configuration of CPU scheduler, LLVM LTO, tick rate, and more.
- Support for various kernel configurations such as NUMA, NR_CPUS, Hugepages, and LRU.
- Application of O3 optimization and performance governor settings.

## Usage
To use the script to build your own kernel, follow these steps:

1. Clone the repository to your local machine.
2. Make the script executable with `chmod +x cachyos-deb.sh`.
3. Run the script with `./cachyos-deb.sh`.
4. Follow the on-screen prompts to select your desired kernel version and configurations, for:
   - Choose the kernel version.
   - Enable or disable CachyOS optimizations.
   - Configure the CPU scheduler, LLVM LTO, tick rate, NR_CPUS, Hugepages, LRU, and other system optimizations. You may want to check the [Advanced Configurations](#advanced-configurations) section for more details on these options.
   - Select the preempt type and tick type for further system tuning.
5. Compile and install.

### Launch options (for `cachyos-deb.sh` on `proto` branch)
- `-b`: builds a `psycachy`-variant kernel with optimizations specific to your CPU `MARCH`. 
- `-g`: builds a `psycachy` generic image from the latest kernel upstream release.
- `-l`: builds a `psycachy-lts` generic image from the latest LTS kernel upstream release.

## Advanced Configurations
The script includes advanced configuration options for users who want to fine-tune their kernel:

- **CachyOS Configuration**: Enable all optimizations from CachyOS. A kernel with this option enabled is not guaranteed to work.
- **CPU Scheduler**: Choose between different schedulers like Cachy, PDS, or none.
- **Tick Rate**: Configure the kernel tick rate according to your system's needs.
- **NR_CPUS**: Set the maximum number of CPUs/cores the kernel will support.
- **Hugepages**: Enable or disable Hugepages support.
- **LRU**: Configure the Least Recently Used memory management mechanism.
- **O3 Optimization**: Apply O3 optimization for performance improvement.
- **Performance Governor**: Set the CPU frequency scaling governor to performance.
- **Modprobed.db**: will use the database built from `modprobed.db` to only build drivers specific to your machine. **WARNING:** use the default kernel with `modprobed.db` up and running for at least a week before building with this option to make sure all drivers you need are on the database, and **always** keep a default (or `psycachy` generic package) kernel as a backup!

## Contributing
Contributions are welcome! If you have suggestions for improving the script or adding new features, please open an issue or submit a pull request.

## License
This project is licensed under the MIT License as upstream - see the LICENSE file for details.
