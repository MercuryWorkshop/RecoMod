# reminder: pid1, busybox sh (not bash)
# to access binaries that aren't busybox, use the version on the USB_MNT. To do more complicated things, chroot into the usb

# export PATH="$PATH:$USB_MNT/usr/local/bin:$USB_MNT/usr/local/sbin:$USB_MNT/usr/sbin:$USB_MNT/usr/bin:$USB_MNT/sbin:$USB_MNT/bin"
# export TERM=xterm

BOX_H="\xe2\x94\x81"
BOX_V="\xe2\x94\x83"

BOX_TR="\xe2\x94\x93"
BOX_TL="\xe2\x94\x8f"

BOX_BR="\xe2\x94\x9b"
BOX_BL="\xe2\x94\x97"

pick_o(){
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
readinput(){
  read -rsn1 mode

	case $mode in
		'') read -rsn2 mode ;;
		'') echo kB ;;
		'') echo kE ;;
		*) echo $mode ;;
	esac

	case $mode in
		'[A') echo kU ;;
		'[B') echo kD ;;
		'[D') echo kL ;;
		'[C') echo kR ;;
	esac
}
repeat(){
  i=0
  while [ $i -le $2 ]; do
    echo -en "$1"
    i=$((i + 1))
  done
}
asusb(){
  if [ -d /usb ]; then
    chroot "$USB_MNT" "/bin/bash" -c "TERM=xterm $*"
  else
    $@
  fi
}
pick(){
  height=$(asusb tput lines)
  width=$(asusb tput cols)
  clear
  asusb stty -echo
  asusb stty -icanon
  asusb tput civis

  tlen=$(expr length "$1")
  title=$1
  shift

  mlen=0

  for i in "$@"; do
    len=$(expr length "$i")
    if [ $len -gt $mlen ]; then
      mlen=$len
    fi
  done

  startx=$(( ( width - mlen ) / 2 ))
  starty=$(( (height - $# + 1) / 2))

  echo -ne "\x1b[$((starty - 4));$(( ( width - tlen ) / 2 ))f"
  echo -ne "$title"

  echo -ne "\x1b[$((starty - 2));$((startx - 3))f"
  echo -ne "$BOX_TL"
  repeat "$BOX_H" $((mlen + 8))
  echo -ne "$BOX_TR"
  repeat "\x1b[1B\x1b[1D$BOX_V" $(($# + 1))
  echo -ne "\x1b[$((starty + $# + 1));$((startx - 3))f"
  echo -ne "$BOX_BL"
  repeat "$BOX_H" $((mlen + 8))
  echo -ne "$BOX_BR"
  echo -ne "\x1b[$((starty - 2));$((startx - 2))f"
  repeat "\x1b[1B\x1b[1D$BOX_V" $(($# + 1))


  helptext="Arrow keys to navigate, enter to select"
  elen=$(expr length "$helptext")
  echo -ne "\x1b[$((starty + $# + 3));$(( ( width - elen ) / 2 ))f"
  echo -ne "$helptext"

  selected=0
	while true; do
		idx=0
		for opt; do
      echo -ne "\x1b[$((idx + starty));${startx}f"
			if [ $idx -eq $selected ]; then
				echo -ne "--> $(echo $opt)"
			else
				echo -ne "    $(echo $opt)"
			fi
			idx=$((idx + 1))
		done
		input=$(readinput)
		case $input in
		'kB') return ;;
		'kE') CHOICE=$((selected + 1))
		      return ;;
		'kU')
			selected=$((selected - 1))
			if [ $selected -lt 0 ]; then selected=0; fi
			;;
		'kD')
			selected=$((selected + 1))
			if [ $selected -ge $# ]; then selected=$(($# - 1)); fi
			;;
		esac
	done

}

pick_chroot_dest(){
  pick "Choose the destination you want to chroot into" \
  "Internal storage (A system)" \
  "Internal storage (B system)" \
  "Local USB image" 
  case $CHOICE in
    1) CHROOT=/mmcmnt ;;
    2) CHROOT=/mmcmnt ;;
    3) CHROOT=$USB_MNT ;;
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

  clear
  asusb tput cnorm
  asusb stty echo

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
      clear
      echo "Cannot activate halcyon, --halcyon was not passed when building this image"
      sleep 3
    fi;;
  esac
done

