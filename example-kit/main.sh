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
pick_fancy(){
  height=$(tput lines)
  width=$(tput cols)
  clear
  stty -echo
  stty -icanon
  tput civis

  len=$(expr length "$1")

  echo -ne "\x1b[0;$(( ( width - len ) / 2 ))f"
  echo -n "$1"

  sleep 10

}

pick_chroot_dest(){
  pick "Choose the destination you want to chroot into" \
  "Internal storage (A system)" \
  "Internal storage (B system)" \
  "Local USB image" 
  case $CHOICE in
    1) CHROOT=/mmcmnt ;;
    2) CHROOT=/mmcmnt ;;
    3) CHROOT=/usb ;;
  esac
}
pick_parenting_type(){
  pick "Choose the type of shell you want" \
    "Normal shell" \
    "PID1 shell (debugging purposes, dangerous)"
  case $CHOICE in
    2) SHEXEC=1 ;;
  esac
}
spawn_shell(){

  if [ -z $CHROOT ]; then
    COMMAND="/bin/busybox sh"
  else
    COMMAND="chroot $CHROOT /bin/bash"
  fi

  if [ -z $SHEXEC ]; then
    $COMMAND
  else
    exec $COMMAND
  fi
  umount /mmcmnt
}

while true; do
  pick "Choose action" \
    "Chroot bash shell (make modifications to the system)" \
    "Initramfs busybox sh (debugging purposes)" \
    "Activate halcyon environment"

  case $CHOICE in
    1) 
      pick_chroot_dest 
      pick_parenting_type
      spawn_shell ;;
    2)
      CHROOT= 
      pick_parenting_type
      spawn_shell ;;
    3)
    if [ -f "$KIT/halcyon_enabled" ]; then
      boot_cros
    else
      echo "Cannot activate halcyon, --halcyon was not passed when building this image"
    fi;;
  esac
done

