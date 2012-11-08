#!/bin/bash
#Created by Sam Gleske
#Created on Oct. 25, 2011
#Icinga plugin, put it in /usr/local/icinga/libexec/
#This was written to test contacts

#Add the following to commands.cfg in icinga config.
#define command{
#  command_name test
#  command_line $USER1$/test.sh
#}

#End of doc

#Exit status key
# OK = 0
# WARNING = 1
# CRITICAL = 2
# UNKOWN = 3

#define your test exit status here referencing the key above
status=0

echo -n "Test status: "

case $status in
0)
  echo "OK"
  ;;
1)
  echo "WARNING"
  ;;
2)
  echo "CRITICAL"
  ;;
*)
  echo "UNKNOWN"
  ;;
esac

exit $status
