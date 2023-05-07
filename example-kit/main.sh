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

while true; do
  pick "Choose action" \
    "Chroot bash shell (make modifications to the system)" \
    "Initramfs busybox sh (debugging purposes, dangerous)" \
    "Activate halcyon environment"

  case $CHOICE in
    1) echo "Currently unimplemented";pick_chroot_dest ;;
    2)
      CHROOT= 
      exec /bin/busybox sh ;;
    3)
    if [ -f "$KIT/halcyon_enabled" ]; then
      boot_cros
    else
      echo "Cannot activate halcyon, --halcyon was not passed when building this image"
    fi;;
    *) echo "invalid choice" ;;
  esac
done

