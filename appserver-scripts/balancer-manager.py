#!/usr/bin/env python
''' balancer-manager for managing Apache mod_proxy_balancer nodes 

If using httpd server, you get a 404 with https urls, then add the following to the virtualhost.
SSLCACertificateFile /etc/httpd/ssl.crt/incommon-ca.crt'''

# Created by Sam Gleske (sag47@drexel.edu)
# Fri Mar  8 12:31:54 EST 2013
# Copyright 2013 Drexel University
# Red Hat Enterprise Linux Server release 6.3 (Santiago)
# Linux 2.6.32-279.14.1.el6.x86_64
# Python 2.6.6

VERSION = '0.1.0'
USER_AGENT = 'balancer-manager.py/' + VERSION
MANAGER_URL = 'https://somehost.com/balancer-manager'

# variable cleanup
if MANAGER_URL[-1:] != '/':
  MANAGER_URL = MANAGER_URL + '/'

#imports
import os,urllib2,sys,re
from optparse import OptionParser, OptionGroup, SUPPRESS_HELP

def url_request(url):
  req = urllib2.Request(url=url, headers={'User-agent': USER_AGENT})
  try:
    f = urllib2.urlopen(req)
  except urllib2.URLError, e:
    if hasattr(e, 'reason'):
      print >> sys.stderr, "Error: %s" % e.reason
    elif hasattr(e,'code'):
      print >> sys.stderr, "Server Error: %d - %s if using https then it could be a certificate problem." % (e.code, e.msg)
      print >> sys.stderr, "Attempted to connect to %s" % url
    sys.exit(1)
  return f.read()

def get_session_nonce():
  ''' Get the nonce value for submitting management forms.  This is a uuid. '''
  #Use one of the nodes to do a poor mans search through html using regex for a uuid
  uuids=re.findall(r'.*&nonce=([-a-f0-9]{36}).*',url_request(MANAGER_URL))
  if len(uuids) <= 0:
    print >> sys.stderr, "Could not obtain nonce uuid.  Double check balancer-manager url!\n%s" % MANAGER_URL
    sys.exit(1)
  return uuids[0]

def build_urls_to_call(options,routes):
  '''build a list of urls to be called for disabling/enabling route workers'''
  uuid=get_session_nonce()
  page=url_request(MANAGER_URL)
  url_list=[]
  for route in routes:
    worker=""
    for line in page.split('\n'):
      r=re.compile('.*<a href="[^"]*">([^<]*).*>' + route + '<.*')
      if len(re.findall(r,line)) > 0:
        worker=re.findall(r,line)[0]
    if len(worker) > 0:
      if options.disable:
        url="%s?lf=1&ls=0&wr=%s&rr=&dw=%s&w=%s&b=%s&nonce=%s" % (MANAGER_URL,route,"Disable",urllib2.quote(worker),options.cluster,uuid)
      elif options.enable:
        url="%s?lf=1&ls=0&wr=%s&rr=&dw=%s&w=%s&b=%s&nonce=%s" % (MANAGER_URL,route,"Enable",urllib2.quote(worker),options.cluster,uuid)
      url_list.append(url)
    else:
      print >> sys.stderr, "Could not determine worker for route: %s" % route
      sys.exit(1)
  return url_list
  

def main():
  ''' main function for processing balancers based on options '''

  #CONFIGURE OPTIONS
  usage="""\
Usage: %%prog [OPTIONS] -c CLUSTER  NODEROUTE [NODEREOUTE...]

Description:
  %%prog can be used to change the balancing scheme on mod_proxy_balancer 
  httpd using the balancer-manager web interface.  It is recommended that 
  you restrict the /balancer-manager/ url to localhost.

  Manager URL:
    %s

Examples:
  %%prog --disable-routes -c my_cluster route2 route3""" % MANAGER_URL
  parser = OptionParser(usage=usage,version='%prog ' + VERSION)
  parser.add_option('', '--debug', dest='debug', help=SUPPRESS_HELP, action="store_true", default=False)
  managerProg_group = OptionGroup(parser, "Balancer Manager Options")
  managerProg_group.add_option('-c','--cluster',dest="cluster", help="specify the cluster to be managed", metavar="CLUSTER")
  managerProg_group.add_option('-d','--disable-routes', dest="disable",help="disable route for balancer",action="store_true",default=False)
  managerProg_group.add_option('-e','--enable-routes', dest="enable",help="enable route for balancer",action="store_true",default=False)
  parser.add_option_group(managerProg_group)
  parser.set_defaults(cluster=None)
  (options, routes) = parser.parse_args()





  #option checking
  if options.cluster == None:
    parser.error("OOPS - must specify cluster")
  if len(routes) <= 0:
    parser.error("OOPS - there's no routes to enable or disable")
  if options.disable and options.enable:
    parser.error("OOPS - --disable and --enable are incompatible options")
  elif not options.disable and not options.enable:
    parser.error("OOPS - --disable or --enable option required")

  #process options and start modifying the cluster using POST method URL calls to balancer-manager
  for url in build_urls_to_call(options,routes):
    url_request(url)



if __name__ == '__main__':
  try:
    main()
  except KeyboardInterrupt:
    print "\ninterrupted."
    sys.exit(1)
