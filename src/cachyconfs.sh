#!/bin/bash
_cfgsource="https://raw.githubusercontent.com/CachyOS/CachyOS-Settings/master/usr"
cd $HOME
mkdir -p sysctl-config
sleep 1
cd sysctl-config
{
    echo "${_cfgsource}/lib/udev/rules.d/20-audio-pm.rules"
    echo "${_cfgsource}/lib/udev/rules.d/40-hpet-permissions.rules"
    echo "${_cfgsource}/lib/udev/rules.d/50-sata.rules"
    echo "${_cfgsource}/lib/udev/rules.d/60-ioschedulers.rules"
    echo "${_cfgsource}/lib/udev/rules.d/69-hdparm.rules"
    echo "${_cfgsource}/lib/udev/rules.d/99-cpu-dma-latency.rules"
    } > "udev.txt"
{
    echo "${_cfgsource}/lib/tmpfiles.d/coredump.conf"
    echo "${_cfgsource}/lib/tmpfiles.d/thp-shrinker.conf"
    echo "${_cfgsource}/lib/tmpfiles.d/thp.conf"
    } > "tmpfiles.txt"
{
    echo "${_cfgsource}/lib/modprobe.d/20-audio-pm.conf"
    echo "${_cfgsource}/lib/modprobe.d/amdgpu.conf"
    echo "${_cfgsource}/lib/modprobe.d/blacklist.conf"
    echo "${_cfgsource}/lib/modprobe.d/nvidia.conf"
    } > "modprobe.txt"
{
    echo "${_cfgsource}/lib/sysctl.d/99-cachyos-settings.conf"
    echo "${_cfgsource}/lib/systemd/journald.conf.d/00-journal-size.conf"
    echo "${_cfgsource}/share/X11/xorg.conf.d/20-touchpad.conf"
    } > "other.txt"
sleep 1
while read -r url; do wget -P udev "$url"; done < udev.txt
while read -r url; do wget -P tmpfiles "$url"; done < tmpfiles.txt
while read -r url; do wget -P modprobe "$url"; done < modprobe.txt
while read -r url; do wget "$url"; done < other.txt
sleep 1
sudo cp -rf udev/* /usr/lib/udev/rules.d/
sudo cp -rf tmpfiles/* /usr/lib/tmpfiles.d/
sudo cp -rf modprobe/* /usr/lib/modprobe.d/
sudo cp -f 99-cachyos-settings.conf /usr/lib/sysctl.d/
sudo cp -f 00-journal-size.conf /usr/lib/systemd/journald.conf.d/
sudo cp -f 20-touchpad.conf /usr/share/X11/xorg.conf.d/
cd ..
rm -rf sysctl-config
