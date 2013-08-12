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
#  1 - no compression, just deduplication
#  2 - deduplication+optimized git compression
#  3 - deduplication+optimized git+gzip compression
#  4 - deduplication+optimized git+bzip2 compression
#  5 - deduplication+optimized git+lzma compression
compression_type="${compression_type:-3}"

#Compression list helps to make the logic more human readable (e.g. in preflight check function)
compression_list[1]="dedupe_only"
compression_list[2]="optimized"
compression_list[3]="gzip"
compression_list[4]="bzip2"
compression_list[5]="lzma"

testmode="false"

######################################################################
# List of functions
######################################################################

function err(){
  echo "${1}" 1>&2
}
function write_gintar(){
  #copies the currently running program to gintar.sh for unarchiving later
  cp "$0" "./gintar.sh"
  #grab the current compression_type out of $0
  sed -i '0,/compression_type="${compression_type:-[0-9]}"/{s#\(compression_type="${compression_type:-\)[0-9]\(}"\)#\1'${compression_type}'\2#}' "./gintar.sh"
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
  #prerequisite only based on the current algorithm (gzip, bzip2, or lzma)
  if [ "gzip" = "${compression_list[compression_type]}" ] && [ ! -x "$(which gzip)" ];then
    err "gzip executable is missing: gzip package"
    STATUS=1
  fi
  if [ "bzip2" = "${compression_list[compression_type]}" ] && [ ! -x "$(which bzip2)" ];then
    err "bzip2 executable is missing: bzip2 package"
    STATUS=1
  fi
  if [ "lzma" = "${compression_list[compression_type]}" ] && [ ! -x "$(which lzma)" ];then
    err "lzma executable is missing: xz-lzma package"
    STATUS=1
  fi
  #method specific preflight check based on the script name
  if [ "${BASENAME}" = "gitar.sh" ];then
    if ! ${testmode} && [ ! -d "${1}" ];then
      err "ERROR: ${1} must be a directory!"
      exit 1
    fi
    if [ -d ".git" ];then
      err "The current directory must not be a git repository!"
      STATUS=1
    elif ! ${testmode} && [ ! -z "$(find "${1}" -type d -name .git | head -n1)" ];then
      err "Error, a nested git repository was found.  This is not recommended so will abort."
      err "$(find "${1}" -type d -name .git | head -n1)"
      err ""
      err "To find potential problems like this run: "
      err "find \"${1}\" -type d -name .git"
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
  if [ "${compression_list[compression_type]}" = "dedupe_only" -o "${compression_list[compression_type]}" = "optimized" ];then
    tar -cf "${1}".gitar .git gintar.sh
  elif [ "${compression_list[compression_type]}" = "gzip" ];then
    #tar -czf "${1}".gitar .git gintar.sh
    tar -cf - .git gintar.sh | gzip -9 - > "${1}".gitar
  elif [ "${compression_list[compression_type]}" = "bzip2" ];then
    #tar -cjf "${1}".gitar .git gintar.sh
    tar -cf - .git gintar.sh | bzip2 -9 - > "${1}".gitar
  elif [ "${compression_list[compression_type]}" = "lzma" ];then
    tar -cf - .git gintar.sh | lzma -9 - > "${1}".gitar
  else
    err "Invalid compression type specified in gitar.sh.  Choose"
    err "compression_type=[1-5] where 1 is least and 5 is most compression."
    err "1 - no compression, just deduplication"
    err "2 - deduplication+optimized git compression"
    err "3 - deduplication+optimized git+gzip compression"
    err "4 - deduplication+optimized git+bzip2 compression"
    err "5 - deduplication+optimized git+lzma compression"
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
# Application testing functions
######################################################################

function run_tests(){
  testmode="true"
  preflight
  echo -n "Cloning opengl-series.git... " 1>&2
  git clone https://github.com/tomdalling/opengl-series.git &>/dev/null && err "success" || err "failed"
  echo -n "Cleaning up git directories... " 1>&2
  rm -rf opengl-series/.git && err "success" || err "failed"
  err "Runing compression tests:"
  echo -n "  0-opengl-series.tar... " 1>&2
  tar -cf 0-opengl-series.tar opengl-series &> /dev/null && err "success" || err "failed"
  #run compression tests with each type of compression
  export compression_type=1
  try_compress
  try_decompress
  export compression_type=2
  try_compress
  try_decompress
  export compression_type=3
  try_compress
  try_decompress
  export compression_type=4
  try_compress
  try_decompress
  export compression_type=5
  try_compress
  try_decompress
  exit 1
}
function try_compress(){
  STATUS=0
  filename="${compression_type}-opengl-series.gitar.${compression_list[compression_type]}"
  echo -n "  ${filename}... " 1>&2
  "${0}" opengl-series &> /dev/null 
  if [ ! "$?" -eq "0" ];then
    STATUS=1
  fi
  mv -f opengl-series.gitar "${filename}" &> /dev/null
  if [ ! "$?" -eq "0" ];then
    STATUS=1
  fi
  if [ "${STATUS}" -eq "0" ];then
    err "success"
  else
    err "failed"
    err "For more information run the following."
    err "(export compression_type=${compression_type};bash -x $0 opengl-series)"
  fi
  return ${STATUS}
}
function try_decompress(){
  STATUS=0
  filename="${compression_type}-opengl-series.gitar.${compression_list[compression_type]}"
  echo -n "  ${filename} decompress... " 1>&2
  mkdir -p "/tmp/${filename}" &> /dev/null
  pushd "/tmp/${filename}" &> /dev/null
  tar -xf ~1/"${filename}" &> /dev/null
  if [ ! "$?" -eq "0" ];then
    STATUS=1
  fi
  ./gintar.sh &> /dev/null
  if [ ! "$?" -eq "0" ];then
    STATUS=1
  fi
  popd &> /dev/null
  if [ "${STATUS}" -eq "0" ];then
    err "success"
  else
    err "failed"
    err "For more information run the following."
    err '(mkdir /tmp/'${filename}';export compression_type=${compression_type};pushd /tmp/'${filename}';tar -xf ~1/'${filename}';bash -x ./gintar.sh)'
  fi
  return ${STATUS}
}
function clean_tests(){
  echo -n "Cleaning up gitar.sh test data..." 1>&2
  rm -rf .git opengl-series 0-opengl-series.tar
  for x in 1 2 3 4 5;do
    filename="${x}-opengl-series.gitar.${compression_list[x]}"
    rm -f "${filename}"
    rm -rf "/tmp/${filename}"
  done
  err "done"
  exit 1
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
  elif [ ! -e "test" ] && [ "${1}" = "test" ];then
    #this helps me test the program
    run_tests
  elif [ ! -e "clean-test" ] && [ "${1}" = "clean-test" ];then
    #this cleans up the test data
    clean_tests
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
