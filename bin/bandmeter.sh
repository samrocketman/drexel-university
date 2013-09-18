#Author szboardstretcher @ linuxquestions.org
#Contributor sag47 @ linuxquestions.org
#Wed Sep 18 09:16:15 EDT 2013
#GNU bash, version 4.2.25(1)-release (x86_64-pc-linux-gnu)

#DESCRIPTION
#  A simple bandwidth rate usage script for a device.  This script
#  will only output changes in bandwidth and samples at every second.
#  If it doesn't output at all then it is assumed the value is the same
#  for every second since the last output.
#USAGE
#  ./bandmeter.sh eth0

#do some error checking
if [ -z "${1}" ];then
  echo "Device not specified!" 1>&2
  echo "Usage: $(basename ${0}) device" 1>&2
  exit 1
elif [ ! -e "/sys/class/net/${1}" ];then
  echo "Error: The device you specified does not exist!" 1>&2
  echo "List of devices:" 1>&2
  (cd /sys/class/net/ && ls -1) | while read device;do
    echo "  ${device}" 1>&2
  done
  echo "Usage: $(basename ${0}) device" 1>&2
  exit 1
fi
R1=0
T1=0
while true;do
  #R2 and T2 are now the old values from the last second
  R2="${R1}"
  T2="${T1}"
  #date of right now in seconds since 1970-01-01 00:00:00 UTC
  DATE="$(date +%s)"
  R1="$(cat /sys/class/net/${1}/statistics/rx_bytes)"
  T1="$(cat /sys/class/net/${1}/statistics/tx_bytes)"
  TBPS="$(expr ${T1} - ${T2})"
  RBPS="$(expr ${R1} - ${R2})"
  TKBPS="$(expr ${TBPS} / 1024)"
  RKBPS="$(expr ${RBPS} / 1024)"
  current_message="tx ${1}: ${TKBPS} kB/s rx ${1}: ${RKBPS} kB/s"
  #If the last message is not the same as the current message then output the current message
  if [ ! "${last_message}" = "${current_message}" ];then
    echo "${DATE};${current_message}"
  fi
  last_message="${current_message}"
  sleep 1
done
