#!/bin/bash
#Created by Sam Gleske
#Tue Aug  6 14:31:01 EDT 2013
#Ubuntu 12.04.2 LTS
#Linux 3.8.0-27-generic x86_64
#GNU bash, version 4.2.25(1)-release (x86_64-pc-linux-gnu)

#This is to show which aliases are missing from the All_clusters alias located at the top of my /etc/clusters file.
for x in $(tail -n $(( $(wc -l /etc/clusters | cut -d\  -f1)-1 )) /etc/clusters | grep -v '^$' | cut -d\  -f1);do if ! head -n1 /etc/clusters | grep $x &>/dev/null;then echo $x;fi;done
