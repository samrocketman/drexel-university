#!/usr/bin/env python
# Sam Gleske (sag47)
# Created 2012/04/11
# Linux 2.6.18-194.11.4.el5 x86_64 GNU/Linux
# Python 2.4.3
#
# This program combines the results of all three log files jvm_memory_stats.txt, jvm_oracleconnections_stats.txt, and open_file_descriptors_stats.txt.
# When the results are combined the timestamps will be aligned.
# The purpose of this is so that all data can be represented on the same graph easily.
# In order to have the correct time show up in Libre office graphs you must do the following:
#     Go to Tools > Options, select LibreOffice Calc > Calculate
#     Ensure the Date is set to 12/30/1899.
#     Then to calculate from the Unix timestamp to a local time in LibreOffice you must apply the following Cell equation where A2 is the Timestamp:
#         =(A2-3600*4)/3600/24+25569
# Example Usage:
#     $ generate_aligned_csv_file.py

import sys,re,os.path,linecache
from sys import exit
from os.path import basename
from optparse import OptionParser
from sys import argv

#Show more verbose error output and exit on all errors
debug = True

class DataObject:
  oldest_sample = 0
  newest_sample = 0
  datalen = 0
  data = []#array of touples
  currentindex = 0
  def __init__(self,filename,regex):
    f = open(filename,'r')
    filecontents = f.read()
    f.close()
    searchregex = re.compile(regex, re.MULTILINE|re.DOTALL)
    self.data = re.findall(searchregex,filecontents)
    self.datalen = len(self.data)
    self.newest_sample = int(self.data[self.datalen-1][1]) #highest number of time since 1970
    self.oldest_sample = int(self.data[0][1]) #smallest number of time since 1970
  def incrementIndex(self,timestamp):
    if self.currentindex < self.datalen-1:#do not allow the index to be incremented past the data array length
      if int(self.data[self.currentindex+1][1]) <= timestamp+1:
        self.currentindex += 1
  def getCurrenttime(self):
    return int(self.data[self.currentindex][1])
  def getCurrentdata(self):
    return self.data[self.currentindex][0]

def get_newest(fromlist):
  """
  get_newest(fromlist) where fromlist is a list of DataObjects
  Get the newest timestamp out of all the timestamps in the DataObject list.
  """
  newest_timestamp = 0
  for obj in fromlist:
    if obj.newest_sample > newest_timestamp:
      newest_timestamp = obj.newest_sample
  return newest_timestamp

def get_oldest(fromlist):
  """
  get_oldest(fromlist) where fromlist is a list of DataObjects
  Get the oldest timestamp out of all the timestamps in the DataObject list.
  """
  oldest_timestamp = fromlist[0].data[0][1] #take the first timestamp from the first DataObject in the fromlist list
  for obj in fromlist:
    if obj.oldest_sample < oldest_timestamp:
      oldest_timestamp = obj.oldest_sample
  return oldest_timestamp

def getfiletype(line_from_file):
  """
  getfiletype(line_from_file)

  This function has a list of registered datasources.  line_from_file will be tested against each datasource.
  If there are any datasources which match the provided string then the datasource will be returned.  If no
  matching datasource was detected the None will be returned.

  Example:
    The best way to get the first line from a file is to use the linecache.getline(filename,lineno) function.
    import linecache
    getfiletype(linecache.getline(filename,1))
  """
  
  # This is a registry of known data sources for the stats results of the live_trend programs
  datasource_types = [
    {'file' : arg,'fieldname' : "Memory Usage (MB)",'regex' : r'JVM Memory = ([\d.]+) \/ \d+ MB \([\d.]+ %\); [-\d.]+ [\d.:]+ [AP]M; (\d+)'},
    {'file' : arg,'fieldname' : "Oracle Connections (#)",'regex' : r'Number of OracleDB connections: ([\d]+); [\d\.-]+ [\d\.:]+ [AP]M; ([\d]+)'},
    {'file' : arg,'fieldname' : "Open File Descriptors (#)",'regex' : r'[-a-zA-Z\d]+ user open file descriptors = (\d+); [-\d.]+ [\d.:]+ [AP]M; ([\d]+)'},
    {'file' : arg,'fieldname' : "1min load",'regex' : r'1 minute load = ([\d\.]+); [\d\.-]+ [\d\.:]+ [AP]M; ([\d]+)'},
    {'file' : arg,'fieldname' : "5min load",'regex' : r'5 minute load = ([\d\.]+); [\d\.-]+ [\d\.:]+ [AP]M; ([\d]+)'},
    {'file' : arg,'fieldname' : "15min load",'regex' : r'15 minute load = ([\d\.]+); [\d\.-]+ [\d\.:]+ [AP]M; ([\d]+)'}
  ]
  for dstype in datasource_types:
    if re.match(dstype['regex'],line_from_file):
      return dstype
  return None
  

#do not execute if included as a library
if __name__ == "__main__": 
  #build a list of datasources in which to align
  datasources=[]
  data=[]
  delim=""

  usage = "usage: %prog [options] result.txt [...result.txt]"
  version = "%prog 0.4"
  description = "Takes in live_trend program results and aligns the Unix timestamps so that it can be graphed.  Multiple trend sources mean multiple dataplots of trends on the same graph."
  parser = OptionParser(usage=usage,version=version,description=description)
  parser.add_option("-f","--format",action="store",type="string",dest="format",default="csv",help="Select the data type for outputting the file.  Only option is csv or gnuplot.  Default is csv.")
  parser.add_option("-d","--delimiter",action="store",type="string",dest="delim",default=",",help="Select the delimiter to separate the data.  Default is a comma \",\".")
  parser.add_option("-t","--libre-office-timestamp",action="store_true",dest="libretime",default=False,help="Use a LibreOffice compatible timestamp since 12/30/1899 rather than the Unix timestamp.")
  (options,args) = parser.parse_args()

  #choose the correct data delimiter based on type and other options.
  if options.format == "gnuplot":
    delim = "\t"
  elif options.format == "csv":
    delim = options.delim
  elif not (options.format == 'csv') and not (options.format == 'gnuplot'):
    err="%s is not a valid output data type.  Expecting csv or gnuplot.\n" % options['type']
    sys.stderr.write(err)
    exit(1)
    
  # This is necessary because each data source requires a unique regex to parse it.  Unregistered data sources are ignored.
  # To see a list of registered data sources see the getfiletype() function
  for arg in args:
    line_to_test = linecache.getline(arg,1)
    line_to_test = line_to_test.strip()
    if not (getfiletype(line_to_test) == None):
      datasources.append(getfiletype(line_to_test))
    else:
      err="%s is not a registered datasource.\n" % arg
      sys.stderr.write(err)
      if debug:
        print "Tested line:\n  %s" % line_to_test
        exit(1)
      else:
        continue

  if len(datasources) <= 0:
    print "No registered datasources detected.  Please provide a proper datasource in the arguments.  Try seeing help docs.\n%s -h\n%s --help" % (argv[0],argv[0])
    exit(1)

  # Create a list of DataObjects from the datasources list and store them in the data list
  for source in datasources:
    data.append(DataObject(source['file'],source['regex']))

  newest=get_newest(data)
  oldest=get_oldest(data)
  datasources_len=len(datasources)

  #Write the header
  if options.format == 'gnuplot':
    headerstr="#Timestamp"
  else:
    headerstr="Timestamp"
  for source in datasources:
    headerstr += delim + source['fieldname']
  #if options.libretime:
  #  headerstr += delim + "Time"
  sys.stdout.write(headerstr+"\n")

  #Write out the syncronized timestamp data in CSV format for all datasources
  last=""
  current=""
  for i in range(oldest,newest+1):
    #do we use the libreoffice compatible timestamp or keep the unix timestamp?
    if options.libretime:
      current = str((i-3600.0*4)/3600/24+25569)
    else:
      current = str(i)
    #build the output string by iterating through all the data list DataOjbects
    for dataobj in data: 
      current += delim + dataobj.getCurrentdata()
      dataobj.incrementIndex(i)
    #if there's a duplicate data entry (not including the timestamp then don't print it
    if not (current.split(delim,1)[1] == last):
      sys.stdout.write(current+"\n")
    #set the last so that duplicates do not get printed
    last = current.split(delim,1)[1]

