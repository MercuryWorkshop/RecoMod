# this is also pid1, but runs as bash instead
USB_MNT=/usb
KIT=$USB_MNT/usr/recokit
BACKGROUND=303446
export LD_LIBRARY_PATH="$USB_MNT/lib:$USB_MNT/lib64:$USB_MNT/usr/lib:$USB_MNT/usr/lib64"

# note! some things will be broken!! almost everything is in a coreutil, so you have to specify busybox it won't by default
# setting the path+symlinking /bin to /usb/bin will theoretically fix

# export PATH="$PATH:$USB_MNT/usr/local/bin:$USB_MNT/usr/local/sbin:$USB_MNT/usr/sbin:$USB_MNT/usr/bin:$USB_MNT/sbin:$USB_MNT/bin"
# export TERM=xterm


sever_streams(){
  dup2 $STDOUT_BACKUP 0
  dup2 $STDIN_BACKUP 1
  dup2 $STDERR_BACKUP 2

  close "$TTY_FD"
}

boot_cros(){
    mount /dev/mmcblk0p1 $USB_MNT/mnt/stateful_partition
    pkill -f frecon
    exec switch_root $USB_MNT /sbin/init > $tty
    sleep 1d
}

exec $USB_MNT/bin/bash
