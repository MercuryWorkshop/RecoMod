#!/usr/bin/env bash
SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=${SCRIPT_DIR:-"."}
. "$SCRIPT_DIR/lib/common_minimal.sh"

leave() {
  trap - EXIT
  exit "$1"
}

quit() {
  trap - EXIT
  echo -e >&2 "\x1B[31mExiting: $1\x1b[39;49m"
  exit "$2"
}

debug() {
  if [ "$FLAGS_debug" = "$FLAGS_TRUE" ] && [ "$FLAGS_quiet" = "$FLAGS_FALSE" ]; then
    echo -e >&2 "\x1B[33mDebug: $*\x1b[39;49m"
  fi
}
info() {
  if [ "$FLAGS_quiet" = "$FLAGS_FALSE" ]; then
    echo -e "\x1B[32mInfo: $*\x1b[39;49m"
  fi
}

traps() {
  set -e
  trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
  trap 'echo "\"${last_command}\" command failed with exit code $?. THIS IS A BUG, REPORT IT HERE https://github.com/MercuryWorkshop/fakemurk"' EXIT
}

configure_binaries() {
  if [ -f /sbin/ssd_util.sh ]; then
    SSD_UTIL=/sbin/ssd_util.sh
  elif [ -f /usr/share/vboot/bin/ssd_util.sh ]; then
    SSD_UTIL=/usr/share/vboot/bin/ssd_util.sh
  elif [ -f "${SCRIPT_DIR}/lib/ssd_util.sh" ]; then
    SSD_UTIL="${SCRIPT_DIR}/lib/ssd_util.sh"
  else
    quit "Cannot find the required ssd_util script. Please make sure you're executing this script inside the directory it resides in" 1
  fi
}
getopts() {
  load_shflags

  FLAGS_HELP="USAGE: $0 -i /path/to/recovery_image.bin [flags]"

  DEFINE_string image "" \
    "path to the recovery image you want to patch" "i"

  DEFINE_string kit "./example-kit" \
    "specify the path to the toolkit folder that will be injected" "k"

  DEFINE_boolean help "$FLAGS_FALSE" \
    "print usage" "h"

  DEFINE_boolean quiet "$FLAGS_FALSE" \
    "do not print anything to stdout" "q"

  DEFINE_boolean keep-verity "$FLAGS_FALSE" \
    "don't disable dm-verity on the kernel that will be installed. disabling this will make the image slower to launch, but if the image is installed it will only be able to boot in developer mode" ""

  DEFINE_boolean minimal "$FLAGS_FALSE" \
    "build a non interactive version of the toolkit. IF YOU HAVE AN ARM-BASED CHROMEBOOK, YOU MUST ENABLE THIS" ""

  DEFINE_boolean cleanup "$FLAGS_TRUE" \
    "clean up gracefully after the script finishes. disable this for debugging purposes" ""

  DEFINE_boolean strip "$FLAGS_FALSE" \
    "reduce the size of the recovery image by deleting everything that isn't neccessary. The image will no longer be able to recover chrome os" ""

  FLAGS "$@" || leave $?
  eval set -- "$FLAGS_ARGV"

  if [ -z "$FLAGS_image" ]; then
    flags_help || :
    leave 1
  fi
}

patch_root_complete() {
  cp "utils/chromeos-recovery.sh" "$ROOT/usr/sbin/chromeos-recovery"
  cp "utils/bootstrap-shell.sh" "$ROOT/usr/sbin/bootstrap-shell"
  chmod +x "$ROOT/usr/sbin/chromeos-recovery"
  chmod +x "$ROOT/usr/sbin/bootstrap-shell"


  cp "clamide" "$ROOT/usr/sbin/clamide"
  chmod +x "$ROOT/usr/sbin/clamide"


  cp -r "$FLAGS_kit" "$ROOT/usr/recokit"
  chmod +x "$ROOT/usr/recokit/"*

}
patch_root_minimal(){
  cp "$FLAGS_kit/main-minimal.sh" "$ROOT/usr/sbin/chromeos-recovery"
  cp -r "$FLAGS_kit" "$ROOT/usr/recokit"
  chmod +x "$ROOT/usr/sbin/chromeos-recovery"
}
strip_root(){
  # we don't usually need to install chrome, stripping can get the file size down
  rm -rf "$ROOT/opt"
  rm -rf "$ROOT/usr/libexec"
  rm -rf "$ROOT/usr/share/chromeos-assets"
  rm -rf "$ROOT/usr/share/fonts"
  rm -rf "$ROOT/usr/lib64/va"
  rm -rf "$ROOT/usr/lib64/dri"
  rm -rf "$ROOT/usr/lib64/samba"


  rm -rf "$ROOT/usr/share/vim"
  rm -rf "$ROOT/usr/share/cros-camera"
  rm -rf "$ROOT/usr/share/X11"

  rm -rf "$ROOT/usr/lib64/libimedecoder.so"
  rm -f "$ROOT/usr/sbin/chromeos-firmwareupdate"

  >"$ROOT/usr/stripped"
}
shrink_image(){
  local buffer=5000000 #5mb buffer. keeps things from breaking too much

  e2fsck -f "${loopdev}p3"
  resize2fs -M "${loopdev}p3"
  local block_size=$(sudo tune2fs -l ${loopdev}p3 | grep -i "block size" | awk '{print $3}')
  local block_count=$(sudo tune2fs -l ${loopdev}p3 | grep -i "block count" | awk '{print $3}')
  local block_count=${block_count%%[[:space:]]*}

  debug "bs: $block_size, blocks: $block_count"

  local raw_bytes=$((block_count * block_size))
  local resize_target=$((raw_bytes + buffer))
  debug "real size: $raw_bytes"
  info "resizing disk to $resize_target"

  info "do the partitioning"
  gparted "$loopdev"

}
main() {

  if [ ! -f "$FLAGS_image" ]; then
    quit "\"$FLAGS_image\" is not a real file!!! You need to pass the path to the recovery image" 1
  fi
  local bin=$FLAGS_image
  debug "Supplied image: $bin"

  info "Creating loopback device"
  local loopdev
  loopdev=$(losetup -f)
  losetup -P "$loopdev" "$bin"
  debug "Setup loopback at $loopdev"


  if [ "$FLAGS_keep_verity" = "$FLAGS_FALSE" ]; then
    $SSD_UTIL --remove_rootfs_verification -i "$loopdev" --partitions 4
  fi
  
  $SSD_UTIL --remove_rootfs_verification --no_resign_kernel -i "$loopdev" --partitions 2

  # for good measure
  sync

  ROOT=$(mktemp -d)
  mount "${loopdev}p3" "$ROOT"
  debug "Mounted root at $ROOT"

  if [ "$FLAGS_strip" = "$FLAGS_TRUE" ]; then
    info "Stripping uneeded components"
    strip_root
  fi

  if [ "$FLAGS_minimal" = "$FLAGS_TRUE" ]; then
    info "Installing minimal toolkit"
    patch_root_minimal
  else
    info "Installing toolkit"
    patch_root_complete
  fi

  if [ "$FLAGS_cleanup" = "$FLAGS_FALSE" ]; then
    quit "Patching successful. skipping cleanup, please do it yourself!" 0
  fi

  sleep 2
  sync

  # local duout=$(du -s "$ROOT")
  # local minsize=${duout%%/*}
  # local minsize=${minsize//[[:blank:]]/}
  umount "$ROOT"

  if [ "$FLAGS_strip" = "$FLAGS_TRUE" ]; then
    info "Shrinking image to $minsize"
    shrink_image "$minsize"
  fi

  losetup -D "$loopdev"

  # i know this is a bit gratuitous, but i don't want to risk the loop not unmounting and accidentally nuking the fs
  sync
  sleep 2

  rm -rf "$ROOT"
  info "Patching successful, happy hacking!"
  leave 0
}

if [ "$0" = "$BASH_SOURCE" ]; then
  stty sane
  if [ "$EUID" -ne 0 ]; then
    quit "Please run as root" 1
  fi
  traps
  getopts "$@"
  configure_binaries
  main
fi
