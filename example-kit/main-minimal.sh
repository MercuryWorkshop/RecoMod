echo "minimal payload!"

crossystem block_devmode=0
crossystem dev_boot_legacy=1
crossystem dev_boot_signed_only=0
crossystem dev_boot_usb=1
crossystem dev_boot_altfw=1

vpd -i RW_VPD -s check_enrollment=0
vpd -i RW_VPD -s block_devmode=0

echo "Resetting GBB flags... This will only work if WP is disabled"
/usr/share/vboot/bin/set_gbb_flags.sh 0x0


chromeos-tpm-recovery
echo "Done"
