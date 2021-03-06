#!/usr/bin/env python
# Created by Sam Gleske (sag47@drexel.edu)
# Created 5 Oct 2011
#
# Usage: logchecker.py -s list [-h] [options] < logchecker.mbox
#
# Description:
#    Sam's python script for filtering the filtered logs emailed by logchecker from scribe.
#    Searches logchecker logs for specific servers.
#    Logchecker emails must be exported into an mbox format.
#
# KMail exports to mbox by default.
# Thunderbird requires add-on ImportExportTools
#    http://nic-nac-project.de/~kaosmos/mboximport-en.html

from sys import stdin
from sys import stderr
from sys import exit
from optparse import OptionParser
import re
from os.path import isfile

"""
  Global Variables
  Filters comprise of a file of OR expressions.  All expressions in the filters file will be matched against a line at once.
"""
PROG_VERSION="v0.4"

#Setting ENABLE_FILTERING=True forces filters to be on, otherwise it will be optional depending on the options passed to the program.
ENABLE_FILTERING=True
FILTERS_FILE="/home/sam/.config/logchecker.filters" #for a better description of the contents of FILTERS_FILE see process_filters_file() comment block written below
#Setting ENABLE_SERVERS_FILE=True forces servers file to be processed for filtering by server name, otherwise it will be optional depending on the options passed to the program.
ENABLE_SERVERS_FILE=True
SERVERS_FILE="/home/sam/.config/logchecker.servers" #for a better description of the contents of SERVERS_FILE see process_servers_file() comment block written below
#global variable filters is created by process_filters_file() function
#filters = ""


def main():
  """
  main() function used as the main entry point.

  Reads stdin of program and processes it
  """
  global ENABLE_FILTERING,ENABLE_SERVERS_FILE,FILTERS_FILE,filters,sl
  #parsing the arguments for -w and -c
  #see docs http://docs.python.org/library/optparse.html
  parser = OptionParser(
    usage = "usage: %prog [-h] [options] < logchecker.mbox",
    version = "%prog " + PROG_VERSION + " created by Sam Gleske (sag47@drexel.edu)",
    description="This script filters logchecker logs from mbox files exported from mail clients by using stdin.  Filter logs for specific servers.  You must export the logchecker emails into the mbox format.  It does not matter if you include the Logchecker Summary or not; it will be ignored."
    )
  parser.add_option("-s","--server",action="store",type="str",dest="servers",default=False,help="Comma Separated list of servers in the logchecker list to filter for.",metavar="list")
  parser.add_option("-n","--servers-file",action="store",type="str",dest="SERVERS_FILE",default=None,help="One per line list of servers in a file to filter for.  (Similar to -s)",metavar="FILE")
  parser.add_option("-f","--filters-file",action="store",type="str",dest="FILTERS_FILE",default=None,help="FILE contains filters which will be used to locally filter out logs line by line.",metavar="FILE")
  parser.add_option("-d","--disable-filters",action="store_true",dest="DISABLE_FILTERING",default=False,help="Disable line by line filtering no matter what options are passed.")
  parser.add_option("-i","--invert-servers",action="store_true",dest="invert",default=False,help="Invert the list of servers to include only servers *not* in the list.")
  (options,args) = parser.parse_args()

  if not ENABLE_FILTERING:
    ENABLE_FILTERING = bool(options.FILTERS_FILE)
    FILTERS_FILE = options.FILTERS_FILE
  if not ENABLE_SERVERS_FILE:
    ENABLE_SERVERS_FILE = bool(options.SERVERS_FILE)
    SERVERS_FILE = options.SERVERS_FILE

  if options.DISABLE_FILTERING:
    ENABLE_FILTERING = False

  sl = []
  if bool(options.servers):
    sl = options.servers.split(',')

  #start processing data from stdin
  data = stdin.read()

  #process the filters file if filtering is enabled
  if ENABLE_FILTERING:
    process_filters_file()
  #process the servers file if it is enabled
  if ENABLE_SERVERS_FILE:
    process_servers_file()

  #split mbox file up into separate messages.  Messages will be handled individualy
  #docs http://docs.python.org/library/re.html
  messages = re.split(r'From [-a-zA-Z0-9\.]+@[a-zA-Z0-9\.]+\s+[,a-zA-Z]{3,4}\s*[0-9]*\s*[a-zA-Z]{3}\s+[0-9]+\s+[0-9:]+\s+[-0-9]+',data)

  for msg in messages:
    #handle the data within each individual message
    splitdata = re.split(r'={4}=+',msg)

    #filter logs only for servers which I am concerned (only servers in the server list sl)
    x=1
    while x < len(splitdata):
      if  not splitdata[x].split('\'')[1] in sl:
        notfound = True
        if len(sl) == 0:
          notfound = False
        else:
          for i in range(len(splitdata[x].split('\'')[1].split('.'))):
            if options.invert:
              if not splitdata[x].split('\'')[1].split('.')[i] in sl:
                notfound = False
            else:
              if splitdata[x].split('\'')[1].split('.')[i] in sl:
                notfound = False
        if notfound:
          x=x+2
          continue
      header = '\t\t' + "="*40 + splitdata[x] + "="*40
      if ENABLE_FILTERING:
        linebyline = splitdata[x+1].split('\n')
        #filter out logs by line
        #remove lines which match the filters similar to a NOT filter for regex
        #filters is a global variable
        linebyline = [line for line in linebyline if not filters.match(line)]
        #filter out empty lines.  If there are less than 2 fields in the list then it means the list is empty because it contains ['\t\t']
        #this if statement is necessary because there is no point in printing a server name if there are no logs in it
        if len(filter(len,linebyline)) < 2:
          x=x+2
          continue
        print header
        for line in linebyline:
          print line
      else:
        print header
        print splitdata[x+1]
      x=x+2

def process_filters_file():
  """
  This is only done once and executed by the main() function.

  ABOUT THIS FILTERS_FILE
    I use this file as a way to filter servers even more.  Not all admins wish to filter as much as I do so this is one way in which I can filter my local copy of logs without affecting the view of other admins.  This is a more
    line by line log filter in addition to the hostname filter for logchecker.py.

  RULES FOR FORMATTING THIS FILTERS_FILE
    Comments are lines that start with a hash #.  Nested hashes are not evaluated as comments.
    Each line is an expression which will be evaluated as an OR regex.
    The entire file is a string of OR regexes which will be compiled into a single regex to match against entire single lines.
    Blank lines will be ignored.
    Spaces on blank lines are also ignored.
  """
  global filters
  if not isfile(FILTERS_FILE):
    stderr.write("STDERR: Filters file does not exist: " + FILTERS_FILE + "\n")
    stderr.write("STDERR: Try -h or --help options\n")
    stderr.write("STDERR: Alternatively configure the FILTERS_FILE variable at the top of logchecker.py or disable filtering by setting ENABLE_FILTERING=False\n")
    stderr.write("STDERR: Exiting.\n")
    exit(1)
  f = open(FILTERS_FILE,'r')
  filters = f.read()
  f.close()
  #remove comments from the filters list.
  #this basically splits the file into a list, remove all lines that start with a hash (#) and also if they contain only spaces.
  filters = [expr for expr in filters.split('\n') if not re.match(r'^#.*|^\s*$',expr)]
  #remove all entries in the filters list which are empty
  filters = filter(len,filters)
  #and rejoin the list using pipes as a separator (|) so that the filters can be compiled into a regex object
  #add ^expr$ to each expression so that it is matched against the whole line
  filters = '|'.join(filters)
  #filters = '$|^'.join(filters)
  #filters = '^' + filters + '$'
  #turn the string of expressions into a regex object
  filters = re.compile(filters)
def process_servers_file():
  """
  This is only done once and executed by the main() function.

  ABOUT THIS SERVERS_FILE
    I use this file as a way to make filtering server names even easier.  Rather than passing in a giant list to the -s
    option one could opt-in to use the SERVERS_FILE instead.

  RULES FOR FORMATTING THIS SERVERS_FILE
    Comments are lines that start with a hash #.  Nested hashes are not evaluated as comments.
    Each line is a server name which will be displayed in the logchecker logs.
    The host name can be just the leading server name, e.g. myhost, or the FQDN, e.g. myhost.server.com.
    Blank lines will be ignored.
    Spaces on blank lines are also ignored.
  """
  global sl
  if not isfile(SERVERS_FILE):
    stderr.write("STDERR: Servers file does not exist: " + SERVERS_FILE + "\n")
    stderr.write("STDERR: Try -h or --help options\n")
    stderr.write("STDERR: Alternatively configure the SERVERS_FILE variable at the top of logchecker.py or disable filtering by setting ENABLE_SERVERS_FILE=False\n")
    stderr.write("STDERR: Exiting.\n")
    exit(1)
  f = open(SERVERS_FILE,'r')
  servers = f.read()
  f.close()
  #remove comments from the filters list.
  #this basically splits the file into a list, remove all lines that start with a hash (#) and also if they contain only spaces.
  servers = [expr for expr in servers.split('\n') if not re.match(r'^#.*|^\s*$',expr)]
  #remove all entries in the filters list which are empty
  servers = filter(len,servers)
  #Append servers to list
  sl = sl + servers


if __name__ == "__main__":
  try:
    main()
  except IOError:
    pass
  #cleaning up open file handles
  stdin.close()
  stderr.close()







 # CHANGELOG
 # Wed Feb 12 17:43:51 EST 2014 v0.4 released
 #   Added --invert-servers option so that only servers *not* in the list are displayed.
 # Tue Feb 11 13:13:00 EST 2014 v0.3 released
 #   Added --servers-file option.  Ability to specify a file of hostnames to search for.
 # Wed May 30 19:50:19 EDT 2012 v0.2 released
 #   Added two options (--filters-file and --disable-filters).  Ability to filter logs line by line to cut out noise.
 #   Second option is to disable filtering.
 # Created 5 Oct 2011 v0.1 released
