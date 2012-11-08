#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Author: Sam Gleske (sag47@drexel.edu)
# Date: 04 Oct 2011
# Description: CGI Script written in Python to integrate munin into Icinga/Nagios using a template
#              To install the script in Icinga/Nagios simply copy it into the following folder
#              /usr/local/icinga/sbin
#
#              https://projects.irt.drexel.edu/systems/wiki/Monitoring#MuninIntegrationWithNagios
# munin-cgi.py
# tested on Python 2.4

#docs http://docs.python.org/library/cgi.html
import cgitb,cgi
from sys import exit

# toggle the cgitb.enable comments for debugging
#cgitb.enable()
cgitb.enable(display=0, logdir="/tmp")

form=cgi.FieldStorage()


#test to make sure that the url for the cgi contains a host POST argument
#example is server.com/cgi-bin/munin.py?host=somehost
#?host= must have a value or exit in error
if "host" not in form or len(form.getlist("host")[0]) < 1 or form.getlist("host")[0] == None:
  print "Content-Type: text/html"     # HTML is following
  print                               # blank line, end of headers
  print "Error: no host name specified<br>should include ?host=somehost at the end of the url"
  exit(1)


# the goal is if the host is nagios.irt.drexel.edu then we want to redirect to /munin/irt.drexel.edu/nagios.irt.drexel.edu

hostname = form.getlist("host")[0]
if len(hostname.split('.',1)) > 1:
  domain = hostname.split('.',1)[1]
else:
  domain = None

if domain == None:
  print "Location: /munin/%s" % (hostname)
  print
  exit(0)
else:
  print "Location: /munin/%s/%s" % (domain,hostname)
  print
  exit(0)
