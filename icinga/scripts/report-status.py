#!/usr/bin/env python
#Created by Sam Gleske (sag47@drexel.edu)
#Created: Mon Nov 12 18:34:30 EST 2012
#Red Hat Enterprise Linux Server release 6.3 (Santiago)
#Linux 2.6.32-71.el6.x86_64
#Python 2.6.6

#Description:
#  A quick script to send_nsca updates back to Icinga
#  This is to simplify passive checks in Icinga.

#Usage:
#  report-status.py

#Setup:
#  Requires nsca configured on icinga server and nsca-client
#  installed on the host.
#
#  Create a user nsca on the system and move the script to
#    /usr/local/sbin/
#  Take ownership of report-status.py with
#    chown root:nsca report-status.py
#    chmod 750 report-status.py
#  Sample crontab for submitting once every 5 minutes:
#    crontab -u nsca -e
#    */5 * * * * /usr/local/sbin/report-status.py > /dev/null 2>&1
#  Edit /etc/nagios/send_nsca.cfg and set the contents to
#    encryption_method=3
#    password=somethingprivate
#  Set ownership of send_nsca.cfg:
#    chown root:nsca /etc/nagios/send_nsca.cfg
#    chmod 220 /etc/nagios/send_nsca.cfg

import os,commands

#User configurable variables
host=os.getenv("HOSTNAME")
icinga_host = "nagios.irt.drexel.edu"
send_nsca_cfg = "/etc/nagios/send_nsca.cfg"
send_cmd = "/usr/sbin/send_nsca"

# A list of descriptions and plugins we wish to run
# The descriptions need to match *exactly* the service name on the Icinga host
cmds = {
  "LOAD": "check_load -w 5,5,5 -c 10,10,10",
  "DISK": "check_disk -w 5% -c 1%",
  "PROCS-SENDMAIL": "check_procs -u root -C sendmail -w 1: -c 1:",
  "PROCS-NTPD": "check_procs -u ntp -C ntpd -w 1: -c 1:"
}

#NO NEED TO EDIT BEYOND THIS POINT
#Set up environment variables
for env_var in ("IFS","PATH","CDPATH","ENV","BASH_ENV"):
  os.unsetenv(env_var)
os.putenv("PATH","/sbin:/usr/sbin:/bin:/usr/bin:/usr/lib64/nagios/plugins:/usr/local/sbin:/usr/lib64/nagios/plugins/contrib")

#Submit the host checks to the icinga server
for cmd in cmds:
  result,output=commands.getstatusoutput(cmds[cmd])
  output=output.strip()
  print "SYS: %s RETURN: %s" % (result,output)
  rcode,nag=commands.getstatusoutput('echo -e "%s\t%s\t%s\t%s" | %s -H %s -c %s' % (host,cmd,result,output,send_cmd,icinga_host,send_nsca_cfg))
  print "%s %s" % (rcode,nag)
