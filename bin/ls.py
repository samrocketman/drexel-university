#!/usr/bin/env python
#Author: Sam Gleske
#Thu Nov  8 10:13:27 EST 2012
#Python 2.7.3
#Description: Speed up the listing of a directory when there are too many files for ls to handle.
#Usage:
#  echo * | ls.py

#" ".join(str.split(' ')[1:3])
import sys
from os.path import *
from optparse import OptionParser

#command options
parser=OptionParser()
parser.add_option("-0","--null",action="store_true",dest="separator",default=False,help="Use null separator instead of new lines.")
parser.add_option("-d","--dirs",action="store_true",dest="dirs_only",default=False,help="Only display directories.")
parser.add_option("-f","--files",action="store_true",dest="files_only",default=False,help="Only display files.")

(options,args)=parser.parse_args()
if options.dirs_only and options.files_only:
  sys.stderr.write("Can't specify -f and -d options together.  See ls.py --help.\n")
  sys.exit(1)
if options.separator:
  separator="\0"
else:
  separator="\n"

#Check the existing path against options
def checkfile(value):
  if (not options.dirs_only) and (not options.files_only):
    return True
  elif options.dirs_only and isdir(value):
    return True
  elif options.files_only and isfile(value):
    return True
  else:
    return False

#do all initial calculations
files=sys.stdin.read()
files=files.split()
length=len(files)

start=0
end=1

  

while end <= length:
  if exists(" ".join(files[start:end])):
    if checkfile(" ".join(files[start:end])):
      sys.stdout.write( "%s%s" % (" ".join(files[start:end]),separator) )
      start,end=end,end+1
    else:#skip file
      start,end=end,end+1
      continue
  else:
    end=end+1

#successful run
sys.exit(0)
