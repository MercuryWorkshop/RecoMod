#!/bin/sh
# this runs as busybox sh, not bash!
USB_MNT=/usb
invoke_terminal() {
    local tty="$1"
    local title="$2"
    shift
    shift
    # Copied from factory_installer/factory_shim_service.sh.
    echo "${title}" >>${tty}
    setsid sh -c "exec script -afqc '$*' /dev/null <${tty} >>${tty} 2>&1 &"
}

enable_debug_console() {
    local tty="$1"
    echo -e '\033[1;33m[cros_debug] enabled on '${tty}'.\033[m'
    invoke_terminal "${tty}" "[Bootstrap Debug Console]" "/bin/busybox sh"
}

sleep 1

enable_debug_console /run/frecon/vt0

sleep 1d

exec /usr/recokit/main.sh
