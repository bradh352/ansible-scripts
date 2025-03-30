#!/bin/sh
if [ "$#" != 2 ] ; then
  echo "Usage: $0 host/ip port"
  exit 1
fi

host=$1
port=$2

nc -w 5 -q 0 $host $port < /dev/null > /dev/null 2>&1
exit $?
