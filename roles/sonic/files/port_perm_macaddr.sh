#!/bin/bash
has_cnt=0

echo "{"
while read intf ; do
  permaddr=`ethtool -P ${intf} | cut -d: -f2- | sed -e 's/ //g'`
  if [ ${has_cnt} = 1 ]; then
    echo ","
  fi
  cat << EOF
  "${intf}" : "${permaddr}"
EOF
  has_cnt=1
done < <(ip a | grep Ethernet | sed -E 's/[0-9]+: (Ethernet[0-9]+):.*/\1/' | grep ^Ethernet)

echo "}"
