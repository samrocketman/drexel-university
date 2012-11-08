#!/bin/bash
#Created by Sam Gleske
#Created Jul 26 13:12 2012
#make sure that addresses match the hostname in icinga host cfg files
#if a linux server in icinga is not in munin then it will show output



function notfiltered() {
  case "$1" in
    quail)
      return 1
      ;;
    quail-z1)
      return 1
      ;;
    sparrow)
      return 1
      ;;
  esac
}


#muninserver=http://
icingahostconfigsdir=/usr/local/icinga/etc/hosts

find $icingahostconfigsdir -type f -name '*.cfg' | while read file;do
  #if [ ! -z "`grep 'linux-host' $file`" ];then
    hostname1=`grep -v '^#' $file | grep 'host_name' | awk '{print $2}' | uniq`
    address=`grep -v '^#' $file | grep 'address' | awk '{print $2}'`
    hostname2=`nslookup $address | grep 'name = ' | awk '{print $4}'`
    hostname2=${hostname2%.}
    #echo $hostname2
    #echo $hostname
    #notfound=`curl $muninserver/munin/${hostname#*.}/$hostname/ 2>/dev/null | grep "not found on this server"`
    if [ "$hostname1" != "$hostname2" ];then
      echo "$hostname1 address pointing to $hostname2 in $file"
    fi
  #fi
done

#for x in `grep -r host_name * | awk '{print $3}'| sort | uniq`; do
#  grep $x /etc/munin/munin.conf
#  echo $x  - $?
#done
