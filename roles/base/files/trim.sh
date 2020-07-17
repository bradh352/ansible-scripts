#!/bin/bash
cat /proc/mounts | grep ^/ | grep -e " xfs " -e " ext4 " | awk '{ print $2 };' | while read mountpoint ; do
  ionice -c2 -n7 nice -n 19 fstrim ${mountpoint}
done 
