#!/bin/bash

grep -v -e '^#.*' -e '^ *$' "$1" | awk 'BEGIN { ORS = ""; print " [ "} NR > 1 {printf "," } { printf " { \"port\" : \""$1"\", \"lanes\" : \""$2"\", \"alias\" : \""$3"\", \"index\" : \""$4"\", \"speed\" : \""$5"\"}" } END { print " ] " }'
