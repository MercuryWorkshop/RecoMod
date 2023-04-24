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
  echo -e "\x1B[31mExiting: $1\x1b[39;49m" >&2
  exit "$2"
}

debug() {
  if [ "$FLAGS_debug" = "$FLAGS_TRUE" ] && [ "$FLAGS_quiet" = "$FLAGS_FALSE" ]; then
    echo -e "\x1B[33mDebug: $*\x1b[39;49m" >&2
  fi
}

supress() {
  if [ "$FLAGS_debug" = "$FLAGS_TRUE" ] && [ "$FLAGS_quiet" = "$FLAGS_FALSE" ]; then
    $@
  else
    $@ >/dev/null 2>&1
  fi
}
suppress_err() {
  if [ "$FLAGS_debug" = "$FLAGS_TRUE" ] && [ "$FLAGS_quiet" = "$FLAGS_FALSE" ]; then
    $@
  else
    $@ 2>/dev/null
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
  trap 'echo "\"${last_command}\": "$BASH_COMMAND" command failed with exit code $?. THIS IS A BUG, REPORT IT HERE https://github.com/MercuryWorkshop/RecoMod"' EXIT
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
patch_root_minimal() {
  cp "$FLAGS_kit/main-minimal.sh" "$ROOT/usr/sbin/chromeos-recovery"
  cp -r "$FLAGS_kit" "$ROOT/usr/recokit"
  chmod +x "$ROOT/usr/sbin/chromeos-recovery"
}
strip_root() {
  # we don't usually need to install chrome, stripping can get the file size down
  rm -rf "$ROOT/opt"
  rm -rf "$ROOT/usr/libexec"
  rm -rf "$ROOT/usr/share/chromeos-assets"
  rm -rf "$ROOT/usr/share/fonts"
  rm -rf "$ROOT/usr/lib64/va"
  rm -rf "$ROOT/usr/lib64/dri"
  rm -rf "$ROOT/usr/lib64/samba"

  rm -rf "$ROOT/usr/share/vim" # :D
  rm -rf "$ROOT/usr/share/cros-camera"
  rm -rf "$ROOT/usr/share/X11"

  rm -rf "$ROOT/usr/lib64/libimedecoder.so"
  rm -f "$ROOT/usr/sbin/chromeos-firmwareupdate"

  >"$ROOT/usr/stripped"
}
shrink_table() {
  local buffer=5000000 #5mb buffer. keeps things from breaking too much

  supress e2fsck -fy "${loopdev}p3"
  supress resize2fs -M "${loopdev}p3"
  local block_size
  block_size=$(tune2fs -l "${loopdev}p3" | grep -i "block size" | awk '{print $3}')
  local sector_size
  sector_size=$(fdisk -l "${loopdev}" | grep "Sector size" | awk '{print $4}')

  local block_count
  block_count=$(tune2fs -l "${loopdev}p3" | grep -i "block count" | awk '{print $3}')
  block_count=${block_count%%[[:space:]]*}

  debug "bs: $block_size, blocks: $block_count"

  local raw_bytes=$((block_count * block_size))
  local resized_size=$((raw_bytes + buffer))
  local fdisk_ra_entry
  fdisk_ra_entry=$(fdisk -u -l "${loopdev}" | grep "${loopdev}p3")
  local start_sector
  start_sector=$(awk '{print $2}' <<<"$fdisk_ra_entry")
  local end_sector
  end_sector=$(awk '{print $3}' <<<"$fdisk_ra_entry")
  local start_bytes=$((start_sector * sector_size))
  local end_bytes=$((end_sector * sector_size))
  local resized_end=$((start_bytes + resized_size))

  debug "real size: $raw_bytes bytes"
  info "resizing ${loopdev}p3 to $resized_size bytes"

  debug "start of ${loopdev}p3 is $start_bytes bytes. changing end from $end_bytes bytes to $resized_end bytes"

  # script will die if i connect a stream to /dev/null  for whatever reason, giving birth to this particular bit of jank
  local jankfile
  jankfile=$(mktemp)
  # if you're wondering why i don't use --script, it causes changes to not apply
  # if you're wondering why i don't use <<EOF, it causes changes not to apply
  # stupid fucking gnu devs
  script /dev/null -c "parted ${loopdev} -f resizepart 3 ${resized_end}B" <<<"Yes" >"$jankfile"
  supress cat "$jankfile"
  rm -f "$jankfile"

  supress sfdisk -N 1 --move-data "${loopdev}" <<<"+,-"

}
truncate_image() {
  local buffer=1000000 #1mb buffer. keeps things from breaking too much
  local img=$1
  local fdisk_stateful_entry
  fdisk_stateful_entry=$(fdisk -l "$img" | grep "${img}1[[:space:]]")
  local sector_size
  sector_size=$(fdisk -l "$img" | grep "Sector size" | awk '{print $4}')
  local end_sector
  end_sector=$(awk '{print $3}' <<<"$fdisk_stateful_entry")
  local end_bytes=$((end_sector * sector_size + buffer))

  info "truncating image to $end_bytes bytes"

  truncate -s $end_bytes "$img"
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
    supress "$SSD_UTIL" --remove_rootfs_verification -i "$loopdev" --partitions 4
  fi

  supress "$SSD_UTIL" --remove_rootfs_verification --no_resign_kernel -i "$loopdev" --partitions 2

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

  sleep 0.2
  sync

  umount "$ROOT"

  if [ "$FLAGS_strip" = "$FLAGS_TRUE" ]; then
    info "Shrinking GPT table"
    shrink_table
  fi

  losetup -D "$loopdev"

  sync
  sleep 0.2
  if [ "$FLAGS_strip" = "$FLAGS_TRUE" ]; then
    truncate_image "$bin"
  fi
  sync
  sleep 0.2

  rm -rf "$ROOT"
  info "Patching successful, happy hacking!"

}

# make this sourceable for testing
if [ "$0" = "$BASH_SOURCE" ]; then
  stty sane

  traps
  getopts "$@"

  if [ "$EUID" -ne 0 ]; then
    quit "Please run as root" 1
  fi

  if [ "$FLAGS_debug" = "$FLAGS_TRUE" ] && [ "$FLAGS_quiet" = "$FLAGS_FALSE" ]; then
    set -x
  fi

  # breaks without this
  if supress which sysctl; then
    orig_sysctl=$(sysctl --values fs.protected_regular)
    supress sysctl -w fs.protected_regular=0
  fi

  configure_binaries
  main

  if supress which sysctl; then
    supress sysctl -w "fs.protected_regular=$orig_sysctl"
  fi
  leave 0
fi
