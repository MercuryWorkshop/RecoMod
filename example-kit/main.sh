# reminder: pid1, busybox sh (not bash)
# to access binaries that aren't busybox, use the version on the USB_MNT. To do more complicated things, chroot into the usb

# export PATH="$PATH:$USB_MNT/usr/local/bin:$USB_MNT/usr/local/sbin:$USB_MNT/usr/sbin:$USB_MNT/usr/bin:$USB_MNT/sbin:$USB_MNT/bin"
# export TERM=xterm

pick(){
  local title="$1"
  echo "$title"
  shift
  i=1
  for opt in "$@"
  do
    echo "$i) $opt"
    i=$((i + 1))
    # bash-isms are not allowed ((i++))
  done

  read -p "1-$#>" CHOICE

  case $CHOICE in
    ''|*[!0-9]*) 
      echo "Invalid Choice"
      pick "$title" "$@" ;;
  esac
}

pick_chroot_dest(){
  pick "Choose the destination you want to chroot into" \
  "Local image" \
  "Internal storage (A system)" \
  "Internal storage (B system)"
  case $CHOICE in
    1) ;;
    2) ;;
    *) ;;
  esac
}

pick "Pick the type of shell you want" \
  "Initramfs busybox sh" \
  "Chroot bash shell" \
  "SWITCH_ROOT!!!"
exec /bin/busybox sh 
case $CHOICE in
  1)
    CHROOT= 
    exec /bin/busybox sh ;;
  2) pick_chroot_dest ;;
  3) boot_cros
  *) echo "invalid choice"
esac

# exec $USB_MNT/bin/bash
