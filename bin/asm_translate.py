#!/usr/bin/env python
#Sam Gleske
#Thu Mar 27 14:48:54 EDT 2014
#Ubuntu 12.04.4 LTS \n \l
#Linux 3.8.0-37-generic x86_64
#Python 2.7.3
#Translates assembly comments from cz to en.
#Requires google translate python module - https://github.com/terryyin/google-translate-python

import argparse
from os.path import isfile
from sys import argv
from sys import exit
from sys import stdin
from translate import Translator

#select language defaults or use arguments
DEFAULT_FROM_LANG="cz"
DEFAULT_TO_LANG="en"

def main(asmfile="",from_lang="cz",to_lang="en"):
  if len(asmfile) > 0 and not isfile(asmfile):
    print "%s is not a file!" % asmfile
    exit(1)
  tl=Translator(from_lang=from_lang,to_lang=to_lang)
  #read from stdin or a file
  if len(asmfile) == 0:
    data=stdin.read()
  else:
    with open(asmfile,'r') as f:
      data=f.read()
  #try translating comments otherwise simply output the line
  for x in data.split('\n'):
    parts=x.split(';',1)
    if len(parts) > 1:
      parts[1]=tl.translate(parts[1])
      print ';'.join(parts)
    else:
      print x

if __name__ == '__main__':
  try:
    parser = argparse.ArgumentParser(description='Translate assembly code comments.  From %s to %s by default.' % (DEFAULT_FROM_LANG,DEFAULT_TO_LANG))
    parser.add_argument(dest="asmfile",nargs="?",default="",type=str,help="Optional asm file to read.  Otherwise read from stdin.")
    parser.add_argument("--from-lang",dest="from_lang",default=DEFAULT_FROM_LANG,help="Translate from language.")
    parser.add_argument("--to-lang",dest="to_lang",default=DEFAULT_TO_LANG,help="Translate to language.")
    args = parser.parse_args()
    main(asmfile=args.asmfile,from_lang=args.from_lang,to_lang=args.to_lang)
  except KeyboardInterrupt,e:
    print "User aborted."
    exit(1)
