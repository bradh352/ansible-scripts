#!/bin/sh
if [ "$#" != 4 ] ; then
  echo "Usage: $0 host/ip port fqdn verify_certs"
  echo "  verify_certs takes 0 or 1"
  exit 1
fi

host=$1
port=$2
fqdn=$3
verify_certs=$4

CMDLINE_EXTRA=""
if [ "$verify_certs" == 1 ]; then
  CMDLINE_EXTRA="-verify_return_error"
fi

openssl s_client -connect $host:$port -servername $fqdn ${CMDLINE_EXTRA} < /dev/null > /dev/null 2>&1
exit $?
