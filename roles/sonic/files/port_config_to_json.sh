#!/bin/bash

fields=`grep -v -e '^#.*' -e '^ *$' "$1" | head -n 1 | awk '{ print NF }'`
if [ $fields -eq 3 ] ; then
	grep -v -e '^#.*' -e '^ *$' "$1" | awk 'BEGIN { ORS = ""; print " [ "} NR > 1 {printf "," } { printf " { \"port\" : \""$1"\", \"lanes\" : \""$2"\", \"alias\" : \"Eth"$3"\", \"index\" : \""$3"\", \"speed\" : \"10000\"}" } END { print " ] " }'
elif [ $fields -eq 4 ] ; then
	grep -v -e '^#.*' -e '^ *$' "$1" | awk 'BEGIN { ORS = ""; print " [ "} NR > 1 {printf "," } { printf " { \"port\" : \""$1"\", \"lanes\" : \""$2"\", \"alias\" : \""$3"\", \"index\" : \""$4"\", \"speed\" : \"10000\"}" } END { print " ] " }'
else
	grep -v -e '^#.*' -e '^ *$' "$1" | awk 'BEGIN { ORS = ""; print " [ "} NR > 1 {printf "," } { printf " { \"port\" : \""$1"\", \"lanes\" : \""$2"\", \"alias\" : \""$3"\", \"index\" : \""$4"\", \"speed\" : \""$5"\"}" } END { print " ] " }'
fi
