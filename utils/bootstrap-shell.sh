#!/bin/sh +x
# this runs as busybox sh, not bash!
# additionally, this has pid 1. do not let it die, or else kernel panic

USB_MNT=/usb
KIT=$USB_MNT/usr/recokit
BACKGROUND=1E1E2E
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

dup(){
  clamide --syscall dup "int:$1"
}
dup2(){
  clamide --syscall dup2 "int:$1" "int:$2"
}
attach_streams(){
  STDOUT_BACKUP=$(dup 0)
  STDIN_BACKUP=$(dup 1)
  STDERR_BACKUP=$(dup 2)

  # as the parent process (sh), open a file descriptor to $1, then redirect streams.
  TTY_FD=$(clamide --syscall open "str:$1" int:1089) 
  dup2 "$TTY_FD" 0 # stdout
  dup2 "$TTY_FD" 1 # stdin
  dup2 "$TTY_FD" 2 # stderr 
  
}
sever_streams(){
  dup2 $STDOUT_BACKUP 0
  dup2 $STDIN_BACKUP 1
  dup2 $STDERR_BACKUP 2

  close "$TTY_FD"
}


init_frecon
TTY=/run/frecon/vt0

exec <${TTY}
exec >${TTY}
exec 2>${TTY}
attach_streams $TTY
printf "\033]box:color=0x${BACKGROUND};size=10000,10000\a" > $TTY
clear


export LD_LIBRARY_PATH="$USB_MNT/lib:$USB_MNT/lib64:$USB_MNT/usr/lib:$USB_MNT/usr/lib64"
export TERM
. "$KIT/main.sh"
main

# failsafe in case
echo "the kit exited! this should never happen!"
tail -f /dev/null
