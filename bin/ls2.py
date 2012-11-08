#!/usr/bin/env python
#Author: Sam Gleske
#Origin: https://github.com/sag47/drexel-university/
#Thu Nov  8 10:13:27 EST 2012
#Python 2.7.3
#
#Description: 
#  Speed up the listing of a directory when there are too many files for ls to handle.
#  In addition to the options this script has two modes: multiline and singleline.
#  These two modes are selected automatically based on received input but it handles
#  the processing of files differently.  In multiline mode, each newline (\n) is processed
#  as a whole file path.  In singleline mode, spaces are processed as a whole file path
#  and is expanded dynamically to account for spaces in file names.
#
#  Please note: the -e option does not work with single line mode (handled gracefully).
#  This version is much slower than ls.py because it attempts to determine the mode for
#  multiline or singleline processing.
#
#Usage:
#  List out a very large directory (singleline mode determined)
#    echo * | ls2.py
#  Show non-existent files in a file list (multiline mode determined)
#    cat filelist | ls2.py -e 1> /dev/null

#" ".join(str.split(' ')[1:3])
import sys,re
from os.path import *
from optparse import OptionParser

#command options
parser=OptionParser()
parser.add_option("-0","--null",action="store_true",dest="separator",default=False,help="Use null separator instead of new lines.")
parser.add_option("-d","--dirs",action="store_true",dest="dirs_only",default=False,help="Only display directories.")
parser.add_option("-f","--files",action="store_true",dest="files_only",default=False,help="Only display files.")
parser.add_option("-e","--err",action="store_true",dest="show_err_files",default=False,help="Output non-existing paths to stderr.")

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
#determine if the file list is all on one line or if a multiline file list (determine mode)
if ((files.split("\n")[1:] == ['']) and len(files.split("\n")) <= 2) or len(files.split("\n")) < 2:
  multiline_mode=False
  files=files.split()
else:
  files=files.split("\n")
  files=filter(lambda x: not re.match(r'^\s*$', x), files) #remove empty list entries
  multiline_mode=True
length=len(files)

start=0
end=1

  

while end <= length:
  if exists(" ".join(files[start:end])):
    if checkfile(" ".join(files[start:end])):
      sys.stdout.write( "%s%s" % (" ".join(files[start:end]),separator) )
      start,end=end,end+1
    else:
      start,end=end,end+1 #skip file (filtered out by checkfile)
      continue
  else:
    if multiline_mode:
      if options.show_err_files:
        sys.stderr.write( "%s%s" % (" ".join(files[start:end]),separator) )
      start,end=end,end+1 #next file
    else:
      end=end+1

#successful run
sys.exit(0)
