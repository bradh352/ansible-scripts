#!/bin/bash
user=$1
alg=`grep "^${user}:" /etc/shadow | cut -d '$' -f 2`
if [ "$alg" != "6" ] ; then
  exit 0
fi
salt=`grep "^${user}:" /etc/shadow | cut -d '$' -f 3`
if [[ $salt == *"round"* ]] ; then
  salt=`grep "^${user}:" /etc/shadow | cut -d '$' -f 4`
fi
echo $salt
