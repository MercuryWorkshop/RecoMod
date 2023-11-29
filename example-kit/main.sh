# reminder: pid1, busybox sh (not bash)
# to access binaries that aren't busybox, use the version on the USB_MNT. To do more complicated things, chroot into the usb

# export PATH="$PATH:$USB_MNT/usr/local/bin:$USB_MNT/usr/local/sbin:$USB_MNT/usr/sbin:$USB_MNT/usr/bin:$USB_MNT/sbin:$USB_MNT/bin"
# export TERM=xterm

# exec 2>/tmp/ef

DEBUG=0

BOX_H="\xe2\x94\x81"
BOX_V="\xe2\x94\x83"

BOX_TR="\xe2\x94\x93"
BOX_TL="\xe2\x94\x8f"

BOX_BR="\xe2\x94\x9b"
BOX_BL="\xe2\x94\x97"
error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
  fi
  # cat /tmp/ef
  echo "PLEASE REPORT THIS BUG, WITH ALL INFORMATION ON THE SCREEN PRESENT IN THE REPORT (https://github.com/MercuryWorkshop/RecoMod)"
  sleep 1
  read -p "PRESS RETURN TO CONTINUE" e
}
traps(){
shopt -s extdebug
  trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
  trap 'error ${LINENO}' ERR
  if ! [ $DEBUG = 1 ]; then
    trap "" SIGINT
    trap "" INT
  fi
}

pick_o() {
  local title="$1"
  echo "$title"
  shift
  i=1
  for opt in "$@"; do
    echo "$i) $opt"
    i=$((i + 1))
    # bash-isms are not allowed ((i++))
  done

  read -p "1-$#>" CHOICE

  case $CHOICE in
  '' | *[!0-9]*)
    echo "Invalid Choice"
    pick "$title" "$@"
    ;;
  esac
}
readinput() {
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
repeat() {
  i=0
  while [ $i -le $2 ]; do
    echo -en "$1"
    i=$((i + 1))
  done
}
asusb() {
  if [ -d /usb ]; then
    chroot "$USB_MNT" "/bin/bash" -c "TERM=xterm $*"
  else
    $@
  fi
}
pick() {
  height=$(asusb tput lines)
  width=$(asusb tput cols)
  clear
  asusb stty -isig
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

  startx=$(((width - mlen) / 2))
  starty=$(((height - $# + 1) / 2))

  echo -ne "\x1b[$((starty - 4));$(((width - tlen) / 2))f"
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
  echo -ne "\x1b[$((starty + $# + 3));$(((width - elen) / 2))f"
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
    # 'kB') return ;;
    'kE')
      CHOICE=$((selected + 1))
      return
      ;;
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
message() {
  height=$(asusb tput lines)
  width=$(asusb tput cols)
  clear
  asusb stty -echo
  asusb stty -icanon
  asusb tput civis

  tlen=$(expr length "$1")

  echo -ne "\x1b[$((height / 2));$(((width - tlen) / 2))f"


  echo "$1"
  sleep 2
}
pick_input() {
  height=$(asusb tput lines)
  width=$(asusb tput cols)
  clear
  asusb stty echo
  asusb stty -icanon
  asusb tput civis

  tlen=$(expr length "$1")

  echo -ne "\x1b[$((height / 2));$(((width - tlen) / 2))f"


  read -p "$1" CHOICE
}

pick_chroot_dest() {
  pick "Choose the destination you want to chroot into" \
    "Local USB image" \
    "Internal storage (A system)" \
    "Internal storage (B system)" 
  case "$CHOICE" in
    1) 
      CHROOT=$USB_MNT 
      ;;
    2) 
      # first try to mount as RW, if it fails RO mount
      mount ${ROOTADEV} /mmcmnt || mount -o ro ${ROOTADEV} /mmcmnt
      CHROOT=/mmcmnt
      ;;
    3)
     mount ${ROOTBDEV} /mmcmnt || mount -o ro ${ROOTBDEV} /mmcmnt
     CHROOT=/mmcmnt
     ;;
  esac
}
pick_parenting_type() {
  pick "Choose the type of shell you want" \
    "Normal shell" \
    "PID1 shell (debugging purposes, dangerous)"
  case $CHOICE in
  2) SHEXEC=1 ;;
  esac
}
spawn_shell() {

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
  umount /mmcmnt || :
}
find_mmcdevs() {
  USBROOTDEV=$(asusb rootdev)
  USBDEV=$(. /init; strip_partition "$USBROOTDEV")
  # me when i source the literal init point
  # why do we source inside a subshell? it breaks otherwise of course

  BDEV=$(. /usr/sbin/write_gpt.sh;. /usr/share/misc/chromeos-common.sh;load_base_vars;get_fixed_dst_drive)
  # while hard to read, sourcing within a subshell is quite elegant as it doesn't clog up names

  STATEDEV=${BDEV}p1
  ROOTADEV=${BDEV}p3
  ROOTBDEV=${BDEV}p5
}
powerwash() {
  pick "Are you sure you want to reset all data on the system?" \
    "No" \
    "Yes"
  case $CHOICE in
  1) return ;;
  esac
  pick "How would you like to reset system data?" \
    "Powerwash (remove user accounts only)" \
    "Pressurewash (remove all data)" \
    "Secure Wipe (slow, completely unrecoverable)"
  case $CHOICE in
  1)
    mkdir /stateful || :
    mount "$STATEDEV" /stateful
    echo "fast safe" >/stateful/factory_install_reset
    umount /stateful
    sync
    ;;
  2)
    yes | asusb mkfs.ext4 $STATEDEV
    ;;
  3)
    message "Starting Secure Wipe"
    echo -en "\n\n\n"
    dd if=/dev/zero | (asusb /usr/sbin/pv) | dd of="$STATEDEV" 
    message "Secure Wipe complete"
    ;;
  esac
}
edit_crossystem(){
      # no here-strings because of posix sh. sed instead of {//} because posix sh
      
      crossystem_rw=$(asusb crossystem | grep "RW")
      data="$(while read line; do
        stripped=$(echo "$line" | sed "s/#.*//g" | sed "s/ //g")

        key=$(echo "$stripped" | sed "s/=.*//g")
        val=$(echo "$stripped" | sed "s/.*=//g")


        echo -n "$key\x20(current=$val) "
      done <<EOF
$crossystem_rw
EOF
)"

        pick "Choose value to edit" $data

        line=$(echo "$crossystem_rw" | sed "${CHOICE}q;d")
        stripped=$(echo "$line" | sed "s/#.*//g" | sed "s/ //g")
        key=$(echo "$stripped" | sed "s/=.*//g")
        val=$(echo "$stripped" | sed "s/.*=//g")



        clear
        asusb stty echo
        pick_input "Enter new value for $key (current value: $val)          >"
        clear
        if crossystem "$key=$CHOICE"; then
          message "Set $key to $CHOICE sucessfully"
        else
          message "Failed to set $key to $CHOICE"
        fi
}
edit_vpd(){
    pick "Choose a VPD partition to edit" \
      "Read-Writable (RW_VPD)" \
      "Write-Protected (RO_VPD)"

    case "$CHOICE" in
      1) PART=RW_VPD ;;
      2) PART=RO_VPD ;;
    esac

    values=$(asusb vpd -i "$PART" -l | sed "s/\"//g ")
      
    data="$(while read line; do

        key=$(echo "$line" | sed "s/=.*//g")
        val=$(echo "$line" | sed "s/.*=//g" | sed "s/ /\\x20/g")

        echo -n "$key\x20(current=$val) "
      done <<EOF
$values
EOF
)"

        pick "Choose value to edit" $data

        line=$(echo "$values" | sed "${CHOICE}q;d")
        key=$(echo "$line" | sed "s/=.*//g")
        val=$(echo "$line" | sed "s/.*=//g")



        clear
        asusb stty echo
        pick_input "Enter new value for $key (current value: $val)          >"
        clear
        if vpd -i "$PART" -s "$key=$CHOICE"; then
          message "Set $key to $CHOICE sucessfully"
        else
          message "Failed to set $key to $CHOICE (is write-protect disabled?)"
        fi
}

edit_gbb(){
  pick "Choose GBB flag configuration to set" \
      "Short boot delay" \
      "Force devmode on" \
      "Force devmode on + short boot delay" \
      "Ignore FWMP" \
      "Factory default (reset)"
  case "$CHOICE" in
    1) FLAGS=0x1 ;;
    2) FLAGS=0x80b8 ;;
    3) FLAGS=0x80b9 ;;
    4) FLAGS=0x80b0 ;;
    5) FLAGS=0x0 ;;
  esac
  asusb flashrom --wp-disable > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    message "Failed to disable software write-protect, make sure hardware WP is disabled?"
  else
    clear
    asusb /usr/share/vboot/bin/set_gbb_flags.sh "$FLAGS"
    message "Set GBB flags sucessfully"
  fi
}

install_rw_legacy(){
  rwlegacy_file=$(asusb bash /usr/recokit/get_rwl_file.sh)
  message "Installing $rwlegacy_file"
  asusb tar -xf "/usr/recokit/rwl.tar.gz" -C /tmp "./${rwlegacy_file}"

  if asusb flashrom -w -i "RW_LEGACY:/tmp/${rwlegacy_file}" -o /tmp/flashrom.log > /dev/null 2>&1; then
    asusb crossystem dev_boot_altfw=1
    message "Sucessfully installed RW_LEGACY"
  else
    message "Failed to install RW_LEGACY"
  fi
}
install_fullrom(){
 message "not implemented"
}

boot_halcyon(){

  # /lib/recovery_init.sh will disable the loading of modules under certain conditions.
  # this is bad as wifi won't be able to load, and we kinda need wifi to get past OOBE
  if [ $(cat /proc/sys/kernel/modules_disabled) = 0 ]; then
    
    asusb vpd -i RW_VPD -s block_devmode=0
    asusb vpd -i RW_VPD -s check_enrollment=0
    # just so people won't iT dOeSnT wOrK

    mount "$HALCYON_STATEDEV" /stateful
    rm -rf /stateful/home/.shadow
    umount /stateful
          
    pkill -f frecon
    exec switch_root "$HALCYON_MNT" /sbin/init

    # this really isn't reachable but whatever any failsafe is better than none
    echo "something went wrong!"
    tail -f /dev/null
  else
    message "Cannot activate halcyon, E mode was not activated"
  fi
}

main() {
  traps
  mkdir /mmcmnt || :

  find_mmcdevs

  while true; do
    pick "Choose action" \
      "Chroot bash shell (make modifications to the system)" \
      "Initramfs busybox sh (debugging purposes)" \
      "Reset system" \
      "Recover system" \
      "Edit GBB flags" \
      "Edit Crossytem variables" \
      "Edit VPD data" \
      "Configure Custom Firmware" \
      "Activate halcyon environment" \
      "Reboot"

    case $CHOICE in
    1)
      pick_chroot_dest
      pick_parenting_type
      spawn_shell
      ;;
    2)
      CHROOT=
      pick_parenting_type
      spawn_shell
      ;;
    3)
      powerwash
      ;;
    4)
      if [ -f "$KIT/stripped" ]; then
        message "Cannot recover system, --strip was enabled while building this image"
      else
        message "Starting Recovery"
        clear
        asusb chromeos-recovery.old "$USBDEV"
        message "Recovery Complete"
      fi
      ;;
    5) edit_gbb ;;
    6) edit_crossystem ;;
    7) edit_vpd ;;
    8) 
      pick "Choose the type of firmware to install" \
        "MrChromebox RW_LEGACY" \
        "MrChromebox UEFI Full ROM (WP MUST BE DISABLED)"
      case "$CHOICE" in
        1)
          if [ -f "$KIT/rw_legacy_enabled" ]; then
            install_rw_legacy
          else
            message "Cannot install rw_legacy, --rw_legacy was not enabled when building this image"
          fi
          ;;
        2) 
          if [ -f "$KIT/fullrom_enabled" ]; then
            install_fullrom
          else
            message "Cannot install fullrom, --fullrom was not enabled when building this image"
          fi
          ;;
      esac
      ;;
    9)
      if [ -f "$KIT/halcyon_enabled" ]; then
        pick "Choose action" \
          "Boot halcyon (tethered, usb must stay in always)" \
          "Install halcyon semi-tethered (do once before booting semi-tethered)" \
          "Boot halcyon (semi-tethered, usb must stay in during boot, can be removed after)"

        case "$CHOICE" in
          1)
            HALCYON_STATEDEV=$STATEDEV
            HALCYON_MNT=$USB_MNT
            boot_halcyon
            ;;
          2) 
            message "Installing halcyon from $USBROOTDEV to $ROOTADEV. This may take a while"
            echo -en "\n\n\n"

            # curiously i have to specify the full path?
            dd if=$USBROOTDEV status=none | (asusb /usr/sbin/pv) | dd of=$ROOTADEV status=none
            
            message "Installing devmode kernels to $BDEV. This may take a while"
            echo -en "\n\n\n"


            # here we install the recovery kernel too
            # we don't intend on booting from it but this will trip `verify_install_kernel` in recovery_init.sh
            # bypassing the 5 minute wait as long as verity was disabled when building the image
            USBDEV_WITH_SUFFIX=$(echo $USBROOTDEV | sed "s/.$//")
            dd if=${USBDEV_WITH_SUFFIX} status=none | (asusb /usr/sbin/pv) | dd of=${BDEV}p2 status=none
            dd if=${USBDEV_WITH_SUFFIX} status=none | (asusb /usr/sbin/pv) | dd of=${BDEV}p4 status=none

            message "Halcyon sucessfully installed"
            ;;
          3) 
            mount ${ROOTADEV} /mmcmnt || mount -o ro ${ROOTADEV} /mmcmnt
            HALCYON_STATEDEV=$STATEDEV
            HALCYON_MNT=/mmcmnt
            (
              # steal the newroot remounting from the initramfs code instead of writing it ourselves.
              # this will bindmount /proc, /sys, and /dev on /mmcmnt and create the needed tmpfses
              # as usual, do all sourcing inside a subshell

              . /init
              . /lib/recovery_init.sh
              USB_MNT=/mmcmnt
              NEWROOT_MNT=/mmcmnt
              setup_install_mounts
              # the odd part is that switch_root is supposed to do this for me? i guess busybox cheaped out
            )
            boot_halcyon
            ;;
        esac

      else
        message "Cannot activate halcyon, --halcyon was not passed when building this image"
      fi
      ;;
    10)
      # busybox reboot doesn't work for some fucking reason, so we do it the old fashioned way
      sync
      $USB_MNT/usr/sbin/clamide --syscall reboot int:0xfee1dead int:672274793 int:0x1234567
      tail -f /dev/null
      ;;
    esac
  done

}

if [ "$0" = "$BASH_SOURCE" ]; then
  main
fi
