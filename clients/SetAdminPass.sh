#!/bin/bash

#Password server URL
URL='https://172.16.235.1/password'

#options
URL_OPTS=""
#Note trailing amp
#URL_OPTS="secure=secure&folder=2&"

#History file
HISTORY='/var/adm/SHIPS.HIST'

#user - should be root or wheel member
USER='root'

#Addtional cURL OPTIONS, for example to specify a CA CERT store
#see man curl
CURL_OPTS=''
#CURL_OPTS='--insecure ' #DON'T DO THIS!

###########################
#DO NOT EDIT BELOW THIS LINE
if [ $(id -u) -ne 0 ]; then echo "$0 Must be run as root" | logger -s; fi

if [ -f $HISTORY ]; then
  NONCE=$( cat $HISTORY | cut -d',' -f1 )
  SDATE=$( cat $HISTORY | cut -d',' -f2 )
  if [ $? -ne 0 ]; then echo "$0 Problem with $HISTORY file" | logger -s; exit 1; fi
  DATE=$( date --date="$SDATE" +"%s")
  if [ $? -ne 0 ]; then echo "$0 Date parse in $HISTORY failed" | logger -s; exit 5; fi
else
  NONCE='0'
  DATE=$( date +"%s" )
fi

SYSDATE=$( date +"%s" )
if [ $SYSDATE -lt $DATE ]; then exit 0; fi #Its not time yet

HOST=$( hostname )
if [ $? -ne 0 ]; then echo "$0 Failed to get hostname" | logger -s; exit 10; fi
 
RESPONSE=$( curl $CURL_OPTS -s "$URL?$URL_OPTSname=$HOST&nonce=$NONCE" )
if [ $? -ne 0 ]; then echo "$0 https request failed to $URL" | logger -s; exit 15; fi

LOOT=$( echo $RESPONSE | sed 's[<!DOCTYPE html><html><body>\(.*\)</body></html>[\1[' )
if [ $? -ne 0 ]; then echo "$0 server response not understood" | logger -s; exit 15; fi

if [ "$( echo $LOOT | cut -d',' -f1 )" != 'true' ]; then
  echo "$0 server says $( echo $LOOT | cut -d',' -f2)" | logger -s
  exit 20
fi

PASSWD=$( echo $LOOT | cut -d',' -f2 | base64 -d )
if [ $? -ne 0 ]; then echo "$0 base64 decode failed" | logger -s; exit 25; fi 

echo $( printf '%s:%s' "$USER" "$PASSWD" ) | chpasswd
if [ $? -ne 0 ]; then echo "$0 password update failed" | logger -s; exit 30; fi

echo $LOOT | cut -d',' -f3,4 > $HISTORY
if [ $? -ne 0 ]; then echo "$0 could not write $HISTORY" | logger -s; exit 35; fi
exit 0
