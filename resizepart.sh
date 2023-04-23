# WIP!!


# script -c "cfdisk /dev/loop2" cfdisk.log &
# sleep 2
expect <<EOF
spawn cfdisk /dev/loop2 >> ff
sleep 2
# send "\r"
EOF
