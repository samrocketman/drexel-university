#!/bin/bash
#Created by Sam Gleske
#original concept by Tom Dalling
#source: http://tomdalling.com/blog/random-stuff/using-git-for-hacky-archive-deduplication/
#Fri Aug  9 11:04:46 EDT 2013
#Ubuntu 12.04.2 LTS
#Linux 3.8.0-27-generic x86_64
#GNU bash, version 4.2.25(1)-release (x86_64-pc-linux-gnu)

#KNOWN ISSUES/WON'T FIX:
#  - Not able to compress git repositories or nested git repositories.
#  - When extracting a gitar archive using tar it is possible to destroy a git repository
#    in the current working directory.
#  - It is assumed you will be compressing a single directory.  If you need to compress
#    multiple directories or files then place them all inside of a directory to be gitar'd.
#  - You must compress a directory located in the current directory or located in a child.
#    If the path you're compressing is located above the current working directory in a
#    parent then this will fail because git can't do that.

#DESCRIPTION:
#  This short script was made for when you have to compress a large amount of duplicated
#  files.  This assumes you do not have lrzip readily available.  Learn more about lrzip at
#  https://github.com/ckolivas/lrzip
#
#  lrzip can compress better and deduplicate better than this script.  Also, this script
#  has known limitations which are not bound to lrzip such as not being able to compress
#  git repositories.  This is meant as a quick hack 'n slash dedupe and compress.

#USAGE:
#  Subshell the compressing of an archive and set the compression level to 2
#    (export compression_type=2; gitar.sh "somedirectory")

######################################################################
# List of global options
######################################################################

#compression types ordered from least to greatest
#  0 - no compression, just deduplication
#  1 - deduplication+optimized git compression
#  2 - deduplication+optimized git+gzip compression
#  3 - deduplication+optimized git+bzip2 compression
compression_type="${compression_type:-3}"



######################################################################
# List of functions
######################################################################

function err(){
  echo "${1}" 1>&2
}
function write_gintar(){
  #copies the currently running program to gintar.sh for unarchiving later
  cp "$0" "./gintar.sh"
}
function preflight(){
  STATUS=0
  if [ ! -x "$(which basename)" ];then
    err "basename executable is missing: GNU coreutils package"
    STATUS=1
  fi
  if [ ! -x "$(which git)" ];then
    err "git executable is missing: git package"
    STATUS=1
  fi
  if [ ! -x "$(which tar)" ];then
    err "tar executable is missing: tar package"
    STATUS=1
  fi
  if [ ! -x "$(which bzip2)" ];then
    err "bzip2 executable is missing: bzip2 package"
    STATUS=1
  fi
  #method specific preflight check based on the script name
  if [ "${BASENAME}" = "gitar.sh" ];then
    if [ ! -d "${1}" ];then
      err "ERROR: ${1} must be a directory!"
      exit 1
    fi
    if [ -d ".git" ];then
      err "The current directory must not be a git repository!"
      STATUS=1
    elif [ ! -z "$(find "${1}" -type d -name .git | head -n1)" ];then
      err "Error, a nested git repository was found.  This is not recommended so will abort."
      err "To find location run: find \"${1}\" -type d -name .git"
      STATUS=1
    fi
    if [ -f "${1}.gitar" ];then
      err "${1}.gitar already exists!  Aborting..."
      STATUS=1
    fi
  elif [ "${BASENAME}" = "gintar.sh" ];then
    if [ ! "${0%/*}" = "${PWD}" -a ! "${0%/*}" = "." ];then
      err "This script must be run from the same working directory!"
      err "e.g. ./gintar.sh"
      STATUS=1
    elif [ ! -d ".git" ];then
      err "Missing .git directory.  Was this really from gitar?"
      STATUS=1
    fi
  fi
  return ${STATUS}
}
function gitar(){
  STATUS=0
  git init
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  git add "${1}"
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  git commit -m "gitar commit"
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  if [ ! "${compression_type}" = "0" ];then
    git gc --aggressive
    if [ ! "$?" = "0" ];then
      STATUS=1
    fi
  fi
  write_gintar
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  if [ "${compression_type}" = "0" -o "${compression_type}" = "1" ];then
    tar -cf "${1}".gitar .git gintar.sh
  elif [ "${compression_type}" = "2" ];then
    #tar -czf "${1}".gitar .git gintar.sh
    tar -cf - .git gintar.sh | gzip -9 - > "${1}".gitar
  elif [ "${compression_type}" = "3" ];then
    #tar -cjf "${1}".gitar .git gintar.sh
    tar -cf - .git gintar.sh | bzip2 -9 - > "${1}".gitar
  else
    err "Invalid compression type specified in gitar.sh"
    STATUS=1
  fi
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  rm -rf ./.git ./gintar.sh
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  return ${STATUS}
}
function gintar_ls(){
  git show --pretty="format:" --name-only $(git log | awk '$1 == "commit" { print $2}')
  exit
}
function gintar(){
  STATUS=0
  git reset --hard
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  rm -rf ./.git ./gintar.sh
  if [ ! "$?" = "0" ];then
    STATUS=1
  fi
  return ${STATUS}
}
function success(){
  if [ "${BASENAME}" = "gitar.sh" ];then
    err ""
    err "SUCCESS!"
    err ""
    err "Your gitar archive is ready.  To decompress run the following commands."
    err "tar -xf \"${1}.gitar\" && ./gintar.sh"
    err ""
  elif [ "${BASENAME}" = "gintar.sh" ];then
    err "Successfully extracted!"
  fi
  exit 0
}
######################################################################
# Main execution logic
######################################################################

#execute the script based on the basename.
BASENAME="$(basename ${0})"

#remove possible trailing slash
INPUT="${1%/}"

if [ "${BASENAME}" = "gitar.sh" ];then
  #start deduplication and compression into an archive
  if [ "$#" == "0" ];then
    err "You must provide an argument!"
    err "Help: gitar.sh somedirectory"
    exit 1
  fi
  preflight "${INPUT}" && gitar "${INPUT}" && success "${INPUT}"
  err "A problem has occurred when creating the gitar archive."
  exit 1
elif [ "${BASENAME}" = "gintar.sh" ];then
  #do the gintar.sh action to unarchive
  if [ "${INPUT}" = "ls" ];then
    preflight && gintar_ls
  else
    preflight && gintar && success
  fi
  err "Something has gone very wrong during extraction!"
  err "For more verbosity run..."
  err "bash -x ./gintar.sh"
  exit 1
else
  err "Unknown method invoked.  This file must be named gitar.sh or gintar.sh"
  exit 1
fi
