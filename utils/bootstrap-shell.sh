#!/bin/sh +x
# this runs as busybox sh, not bash!
# additionally, this has pid 1. do not let it die, or else kernel panic
USB_MNT=/usb
KIT=$USB_MNT/usr/recokit
BACKGROUND=303446
init_frecon(){
  # taken from messages.sh
  local resolution="$(frecon-lite --print-resolution)"
  local x_res="${resolution% *}"

  if [ "${x_res}" -ge 1920 ]; then
    FRECON_SCALING_FACTOR=0
  else
    FRECON_SCALING_FACTOR=1
  fi

  frecon-lite --enable-vt1 --daemon --no-login --enable-gfx \
              --enable-vts --scale="${FRECON_SCALING_FACTOR}" \
              --clear "0x${BACKGROUND}" --pre-create-vts \
              "${KIT}/splash.png"
  sleep 2
  printf "\033]switchvt:0\a" > /run/frecon/current
}

boot_cros(){
mount /dev/mmcblk0p1 $USB_MNT/mnt/stateful_partition
    pkill -f frecon
    exec switch_root $USB_MNT /sbin/init > $tty
    sleep 1d
}

init_frecon

tty=/run/frecon/vt0
echo "doing thingy" > $tty
sleep 1

boot_cros
# comment out boot_cros if you want to use the shell instead




echo "bootstrap-shell" >>${tty}
setsid sh -c "exec script -afqc '$KIT/main.sh' /dev/null <${tty} >>${tty} 2>&1 &"

# slumber forever
tail -f /dev/null
