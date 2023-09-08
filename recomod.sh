#!/usr/bin/env bash
SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=${SCRIPT_DIR:-"."}
. "$SCRIPT_DIR/lib/common_minimal.sh"

FUS_SOURCES=https://raw.githubusercontent.com/MrChromebox/scripts/master/sources.sh


cleanup(){
  umount "$ROOT" || :
  losetup -d "$loopdev"

}

leave() {
  trap - EXIT
  exit "$1"
}

quit() {
  trap - EXIT
  echo -e "\x1b[31mExiting: $1\x1b[39;49m" >&2
  exit "$2"
}
fbool(){
  [ "$(eval echo $(echo \"\$FLAGS_$1\"))" = "$FLAGS_TRUE" ]
}
should_debug(){
  fbool debug && ! fbool quiet
}

debug() {
  if should_debug; then
    echo -e "\x1B[33mDebug: $*\x1b[39;49m" >&2
  fi
}

suppress() {
  if should_debug; then
    $@
  else
    $@ >/dev/null 2>&1
  fi
}
suppress_err() {
  if should_debug; then
    $@
  else
    $@ 2>/dev/null
  fi
}


info() {
  if ! fbool quiet; then
    echo -e "\x1B[32mInfo: $*\x1b[39;49m"
  fi
}

traps() {
  set -e
  trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
  trap 'echo -e "\x1b[31m\"${last_command}\": "$BASH_COMMAND" command failed with exit code $?. THIS IS A BUG, REPORT IT HERE https://github.com/MercuryWorkshop/RecoMod\x1b[31m"' EXIT
}

configure_binaries() {
  if ! suppress which curl; then
    quit "curl binary not found! You must install curl. On debian/ubuntu, run sudo apt install curl" 1
  fi
  if ! suppress which cgpt; then
    quit "cgpt binary not found! You must install cgpt. On debian/ubuntu, run sudo apt install cgpt" 1
  fi
  
  if ! suppress which futility; then
    quit "futility binary not found! You must install vboot-utils. On debian/ubuntu, run sudo apt install vboot-kernel-utils and on arch the package is vboot-utils from the AUR" 1
  fi


  if [ -f /sbin/ssd_util.sh ]; then
    SSD_UTIL=/sbin/ssd_util.sh
  elif [ -f /usr/share/vboot/bin/ssd_util.sh ]; then
    SSD_UTIL=/usr/share/vboot/bin/ssd_util.sh
  elif [ -f "${SCRIPT_DIR}/lib/ssd_util.sh" ]; then
    SSD_UTIL="${SCRIPT_DIR}/lib/ssd_util.sh"
  else
    quit "Cannot find the required ssd_util script. Please make sure you're executing this script inside the directory it resides in" 1
  fi

  if ! fbool minimal; then
    info "Downloading clamide into lib/"
    curl -sL https://github.com/CoolElectronics/clamide/releases/latest/download/clamide -o "${SCRIPT_DIR}/lib/clamide" 

    info "Downloading pv into lib/"
    if ! [ -f lib/pv ]; then
      curl -sL https://github.com/mosajjal/binary-tools/raw/master/x64/pv -o lib/pv
    fi

  fi

  if fbool rw_legacy; then
    info "Downloading latest rw_legacy payloads into lib/rwl"
    mkdir lib/rwl || :
    rwlegacy_source="$(. <(curl -Ls "$FUS_SOURCES"); echo $rwlegacy_source)"
    files="$(. <(curl -Ls "$FUS_SOURCES"); env | grep -e rwl_altfw -e seabios)"

    while read file; do
      key=${file%%=*}
      val=${file##*=}
      debug "Downloading $key: $val"
      curl -sL "${rwlegacy_source}${val}" -o "lib/rwl/$val"
    done <<< "$files"
  fi
  if fbool fullrom; then
    quit "Sorry! I haven't gotten around to adding in fullrom support yet. Check back later" 1
  fi

  if fbool strip; then
    if suppress which sfdisk && [[ "$(sfdisk -v)" == "sfdisk from util-linux 2.38."* ]]; then
      debug "using machine's sfdisk"
      SFDISK=$(which sfdisk)
    elif [ -f "${SCRIPT_DIR}/lib/sfdisk" ] && [ "$(uname -m)" = "x86_64" ] && [[ "$(uname)" == *Linux* ]]; then
      debug "using static sfdisk"
      SFDISK="${SCRIPT_DIR}/lib/sfdisk"
      chmod +x "$SFDISK"
    else
      quit "Could not find a working version of sfdisk.
If you are using a 32 bit or ARM system (or god forbid a mac), please make sure you have exactly version 2.38.1 of sfdisk installed, as it's the only one that works."
    fi
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

  DEFINE_boolean disable-verity "$FLAGS_TRUE" \
    "disable dm-verity on the kernel that will be installed during recovery. enabling this will make the image faster to launch, but if the image is installed through recovery it will only be able to boot in developer mode" ""

  DEFINE_boolean minimal "$FLAGS_FALSE" \
    "build a non interactive version of the toolkit. IF YOU HAVE AN ARM-BASED CHROMEBOOK, YOU MUST ENABLE THIS" ""

  DEFINE_boolean cleanup "$FLAGS_TRUE" \
    "clean up gracefully after the script finishes. disable this for debugging purposes" ""

  DEFINE_boolean rw_legacy "$FLAGS_TRUE" \
    "download files from mrchromebox.tech for use in the rw_legacy firmware configuration menu" ""
  DEFINE_boolean fullrom "$FLAGS_FALSE" \
    "download files from mrchromebox.tech for use in the full uefi rom firmware configuration menu. This will take up a lot of space, only do this if you know you need it." ""


  DEFINE_boolean strip "$FLAGS_FALSE" \
    "reduce the size of the recovery image by deleting everything that isn't neccessary. The image will no longer be able to recover chrome os" ""
  DEFINE_boolean halcyon "$FLAGS_FALSE" \
    "enable E-HALCYON patches. if you don't know what that means, leave this option alone" ""

  FLAGS "$@" || leave $?
  eval set -- "$FLAGS_ARGV"


  if fbool halcyon && (fbool strip || fbool minimal); then
    quit "--halcyon and --strip/--minimal are incompatible" 1
  fi


  if [ -z "$FLAGS_image" ]; then
    flags_help || :
    leave 1
  fi
}
# https://chromium.googlesource.com/chromiumos/docs/+/master/lsb-release.md
lsbval() {
  local key="$1"
  local lsbfile="${2:-/etc/lsb-release}"

  if ! echo "${key}" | grep -Eq '^[a-zA-Z0-9_]+$'; then
    return 1
  fi

  sed -E -n -e \
    "/^[[:space:]]*${key}[[:space:]]*=/{
      s:^[^=]+=[[:space:]]*::
      s:[[:space:]]+$::
      p
    }" "${lsbfile}"
}

patch_root_complete() {
  cp "utils/bootstrap-shell.sh" "$ROOT/usr/sbin/bootstrap-shell"
  chmod +x "$ROOT/usr/sbin/bootstrap-shell"

  cp lib/clamide "$ROOT/usr/sbin/clamide"
  chmod +x "$ROOT/usr/sbin/clamide"

  # we don't neeeeeed pv, but it looks cool
  cp lib/pv "$ROOT/usr/sbin/pv"
  chmod +x "$ROOT/usr/sbin/pv"

  cp -r "$FLAGS_kit" "$ROOT/usr/recokit"
  chmod +x "$ROOT/usr/recokit/"*


  mv "$ROOT/usr/sbin/chromeos-recovery" "$ROOT/usr/sbin/chromeos-recovery.old"
  cp "utils/chromeos-recovery.sh" "$ROOT/usr/sbin/chromeos-recovery"

  chmod +x "$ROOT/usr/sbin/chromeos-recovery"
  chmod +x "$ROOT/usr/sbin/chromeos-recovery.old"

  if fbool halcyon; then
    local milestone=$(lsbval CHROMEOS_RELEASE_CHROME_MILESTONE "$ROOT/etc/lsb-release")
    if (( milestone > 107 )); then
      cleanup
      quit "You are trying to use halcyon on an image of version R${milestone}. Due to a change in chromeos_startup.sh, this is not supported. Please download an R107 image instead" 1
    fi
    if (( milestone != 107 )); then
      info "WARNING: ${bin} is not an R107 image. Proceeding anyway, but remember that R${milestone} is untested"
    fi

    info "Installing halcyon patches onto an R${milestone} image"
    cat <<EOF >"$ROOT/usr/sbin/wipe_disk"
#!/bin/bash
echo "E mode activated"
exec /usr/sbin/chromeos-recovery
EOF
    chmod +x "$ROOT/usr/sbin/wipe_disk"

    # snippet sourced from https://github.com/sebanc/brunch/blob/r107/brunch-patches/40-custom_encryption.sh, licensed under GPLv3
    cat <<EOF >"$ROOT/usr/share/cros/startup_utils.sh"
mount_var_and_home_chronos() {
  mkdir -p /mnt/stateful_partition/encrypted/var
  mount -n --bind /mnt/stateful_partition/encrypted/var /var || return 1
  mkdir -p /mnt/stateful_partition/encrypted/chronos
  mount -n --bind /mnt/stateful_partition/encrypted/chronos /home/chronos || return 1
}

umount_var_and_home_chronos() {
  umount /home/chronos
  umount /var
}
EOF
    sed -i "s/# Check if we enable ext4 features\./STATE_DEV=\$(\. \/usr\/sbin\/write_gpt.sh;\. \/usr\/share\/misc\/chromeos-common\.sh;load_base_vars;get_fixed_dst_drive)p1/" "$ROOT/sbin/chromeos_startup.sh"
    
    sed -i "s/stable/dev/" "$ROOT/etc/lsb-release"

    sed -i "s/end script/sleep 2;tpm_manager_client take_ownership;restart cryptohomed;sleep 1\nend script/" "$ROOT/etc/init/ui.conf"
    >"$ROOT/usr/recokit/halcyon_enabled"
  fi

  if fbool rw_legacy; then
    tar -czvf "$ROOT/usr/recokit/rwl.tar.gz" -C "lib/rwl" .
    >"$ROOT/usr/recokit/rw_legacy_enabled"
  fi
  if fbool fullrom; then
    >"$ROOT/usr/recokit/fullrom_enabled"
  fi

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

  suppress e2fsck -fy "${loopdev}p3"
  suppress resize2fs -M "${loopdev}p3"
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
  script /dev/null -c "parted ${loopdev} resizepart 3 ${resized_end}B" <<<"Yes" >"$jankfile"
  suppress cat "$jankfile"
  rm -f "$jankfile"


  local numparts=12
  local numtries=6


  i=0
  while [ $i -le $numtries ]; do
    j=1
    while [ $j -le $numparts ]; do
      suppress "$SFDISK" -N $j --move-data "${loopdev}" <<<"+,-" || :
      j=$((j+1))
    done
    i=$((i+1))
  done
}
truncate_image() {
  local buffer=35 # magic number to ward off evil gpt corruption spirits
  local img=$1
  local fdisk_stateful_entry
  fdisk_stateful_entry=$(fdisk -l "$img" | grep "${img}1[[:space:]]")
  local sector_size
  sector_size=$(fdisk -l "$img" | grep "Sector size" | awk '{print $4}')
  local end_sector
  end_sector=$(awk '{print $3}' <<<"$fdisk_stateful_entry")
  local end_bytes=$(((end_sector + buffer) * sector_size))

  info "truncating image to $end_bytes bytes"

  truncate -s $end_bytes "$img"
  suppress gdisk "$img" << EOF
w
y
EOF
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

  if fbool disable-verity; then
    suppress "$SSD_UTIL" --remove_rootfs_verification -i "$loopdev" --partitions 4
  fi

  suppress "$SSD_UTIL" --remove_rootfs_verification --no_resign_kernel -i "$loopdev" --partitions 2

  # for good measure
  sync

  ROOT=$(mktemp -d)
  mount "${loopdev}p3" "$ROOT"
  debug "Mounted root at $ROOT"

  if fbool strip; then
    info "Stripping uneeded components"
    strip_root
  fi

  if fbool minimal; then
    info "Installing minimal toolkit"
    patch_root_minimal
  else
    info "Installing toolkit"
    patch_root_complete
  fi

  if ! fbool cleanup; then
    quit "Patching successful. skipping cleanup, please do it yourself!" 0
  fi

  sleep 0.2
  sync

  umount "$ROOT"

  if fbool strip; then
    info "Shrinking GPT table"
    shrink_table
  fi

  losetup -d "$loopdev"

  sync
  sleep 0.2
  if fbool strip; then
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

  if [[ $(uname -r) =~ Microsoft$ ]] || grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null || [[ -n "$IS_WSL" || -n "$WSL_DISTRO_NAME" ]]; then
    info "WSL DETECTED!!!!!!!!!!!!!!!!!!!!
WSL IS NOT SUPPORTED, PLEASE DO NOT FILE AN ISSUE IF THE SCRIPT RUNS INTO AN ERROR
THE SCRIPT WILL CONTINUE TO RUN, BUT IT MAY NOT WORK"
  fi

  # breaks without this
  if suppress which sysctl; then
    orig_sysctl=$(sysctl --values fs.protected_regular || :)
    suppress sysctl -w fs.protected_regular=0 || :
  fi


  configure_binaries
  main

  if suppress which sysctl; then
    suppress sysctl -w "fs.protected_regular=$orig_sysctl" || :
  fi
  leave 0
fi
