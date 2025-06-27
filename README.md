# PsyCachy & CachyOS Kernel Builder

This repository contains a script for building the CachyOS kernel with various optimizations tailored to your system's CPU architecture. The script automates the process of configuring and optimizing the kernel build according to your hardware and preferences.

## Prerequisites

Before running the script, ensure you have the following prerequisites installed:

- `gcc`: The GNU Compiler Collection is required for detecting the CPU architecture.
- `clang`: Required for compiling the kernel.
- `whiptail`: For displaying dialog boxes in the script.
- `curl`: For fetching the latest kernel version.
- `rustc`: For building newer, Rust-based kernel modules.

You can install these dependencies using your distribution's package manager.

## Features

The script offers a variety of configuration options:

- Auto-detection of CPU architecture for optimization.
- Selection of CachyOS specific optimizations.
- Configuration of CPU scheduler, LLVM LTO, tick rate, and more.
- Support for various kernel configurations such as NUMA, NR_CPUS, Hugepages, and LRU.
- Application of O3 optimization and performance governor settings.

## Usage

To use the script, follow these steps:

1. Clone the repository to your local machine.
2. Make the script executable with `chmod +x cachyos-deb.sh`.
3. Run the script with `./cachyos-deb.sh`.
4. Follow the on-screen prompts to select your desired kernel version and configurations, for:
   - Choose the kernel version.
   - Enable or disable CachyOS optimizations.
   - Configure the CPU scheduler, LLVM LTO, tick rate, NR_CPUS, Hugepages, LRU, and other system optimizations.
   - Select the preempt type and tick type for further system tuning; or
5. Install with optimized defaults and my custom 'stable' branch, which is updated roughly every two months, with `./cachyos-deb.sh -s`. This has been thoroughly tested on Debian Testing and Ubuntu (with Gnome, the standard Canonical flavour), but should work elsewhere without complications.

### Launch options

- `-b`: builds a `psycachy`-variant kernel with optimizations specific to your CPU `MARCH`. 
- `-g`: builds the same `psycachy` generic image found in Releases. Meant just to generate those images.
- `-c`: builds a `linux-cachyos` kernel with latest spec and settings.

## Advanced Configurations

The script includes advanced configuration options for users who want to fine-tune their kernel:

- **CachyOS Configuration**: Enable optimizations specific to CachyOS.
- **CPU Scheduler**: Choose between different schedulers like Cachy, PDS, or none.
- **LLVM LTO**: Select between Thin and Full LTO for better optimization.
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

This project is licensed under the MIT License - see the LICENSE file for details.
