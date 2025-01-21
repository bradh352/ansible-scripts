#!/bin/bash

eth=""
conn="unknown"
has_cnt=0

output_eth()
{
  if [ "$eth" != "" ] ; then
    if [ ${has_cnt} = 1 ]; then
      echo ","
    fi
    echo -n "\"$eth\": \"$conn\""
    has_cnt=1
  fi
}

echo "{"

while read line ; do
  key=`echo "$line" | cut -d: -f1`
  val=`echo "$line" | cut -d: -f2 | sed -e 's/ //g'`
  if echo $key | grep "^Ethernet" > /dev/null ; then
    output_eth
    eth="$key"
    if echo $val | grep "RJ45" > /dev/null ; then
      # Mellanox outputs: SFP EEPROM is not applicable for RJ45 port
      conn="RJ45"
    else
      conn="unknown"
    fi
  fi

  if [ "$key" == "Connector" ] ; then
    conn="$val"
  fi
done < <(sfpshow eeprom | grep -e '^Ethernet' -e '^ *Connector' | sed -e 's/^ *//g')

output_eth

echo ""
echo "}"
