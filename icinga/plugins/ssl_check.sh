#!/bin/bash
#Created by Sam Gleske
#Date Created: Thu Nov  8 16:19:10 EST 2012
#The MIT License
#Copyright (c) 2012 Samuel Gleske, Drexel University
#
#Description:
#  This simple script checks the expiration of an SSL Certificate.
#  If the cert is within 30 days of expiration there will be an Icinga warning.
#  If the cert is within 14 days of expiration there will be an Icinga critical.
#
#Usage:
#  ssl_check.sh server:port
#  ssl_check.sh -f /path/to/cert.crt
#
#Required Packages: bash, coreutils, grep, sed, openssl



#values are in days
expire_warning=30
expire_critical=14

#exit status
UNKNOWN=3 
OK=0 
WARNING=1 
CRITICAL=2

if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ];then
  cat <<EOF
  DESCRIPTION:
    Check the expiration of a certificate and return a status code.

  USAGE:
    ssl_check.sh server:port
    ssl_check.sh -f /path/to/cert.crt
EOF
  exit $UNKNOWN
fi

#processing
if [ "$1" = "-f" ];then
  ssl_exp_date="$(openssl x509 -text -in $2 2>/dev/null | grep 'Not After' | sed 's/Not After : //' | sed 's/^ *//')"
  #test for successful certificate
  openssl x509 -text -in $2 1>/dev/null 2>&1
  if [ ! "$?" = "0" ];then
    echo "UNKNOWN - $(openssl x509 -text -in $2 2>&1 1>/dev/null | head -n1)"
    exit $UNKNOWN
  fi
else #run a timeout of 3 seconds for the openssl command
  ssl_exp_date="$(timeout 3 openssl s_client -connect $1 2>/dev/null < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | openssl x509 -text 2>/dev/null | grep 'Not After' | sed 's/Not After : //' | sed 's/^ *//')"
  #test for successful certificate
  openssl s_client -connect $1 </dev/null 2>/dev/null | openssl x509 -text 1>/dev/null 2>&1
  if [ ! "$?" = "0" ];then
    echo "UNKNOWN - $(openssl s_client -connect $1 </dev/null 2>/dev/null | openssl x509 -text 2>&1 1>/dev/null | head -n1)"
    exit $UNKNOWN
  fi
fi
time_left_in_seconds=$(( $(date -d "$ssl_exp_date" +%s) - $(date +%s) ))
warn_val=$(( $expire_warning*24*3600 ))
crit_val=$(( $expire_critical*24*3600 ))

#logic
if [ "$time_left_in_seconds" -lt "$crit_val" ];then
  echo "CRITICAL - Cert Expires $(date -d "$ssl_exp_date")"
  exit $CRITICAL
elif [ "$time_left_in_seconds" -lt "$warn_val" ];then
  echo "WARNING - Cert Expires $(date -d "$ssl_exp_date")"
  exit $WARNING
else
  echo "OK - Cert Expires $(date -d "$ssl_exp_date")"
  exit $OK
fi

#Tested Environment:
#  Ubuntu 12.04.1 LTS Linux 3.2.0-32-generic x86_64 GNU/Linux
#  GNU bash, version 4.2.24(1)-release (x86_64-pc-linux-gnu)
#  GNU coreutils 8.13-3ubuntu3.1
#  GNU sed version 4.2.1
#  grep (GNU grep) 2.10
#  OpenSSL 1.0.1 14 Mar 2012
