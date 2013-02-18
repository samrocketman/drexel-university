#!/bin/bash
#Created by Sam Gleske (sag47@drexel.edu)
#Created Thu Nov 29 16:42:12 EST 2012
#Red Hat Enterprise Linux Server release 5.5 (Tikanga)
#Linux 2.6.18-194.11.4.el5 x86_64 GNU/Linux
#JBoss EWP 5.1.0.GA
#java version "1.6.0_13"
#
#Description:
#  This is an automatic deployer for a production jboss instance.
#  To be run by an admin from the terminal rather than configuring
#  automated deployments from a web interface.  Web interface
#  automated deployments are for test machines only.
#
#  Note the variables are flexible enough that you could configure
#  this for most app servers.  All you need is an init.d script 
#  for the app server which can start, stop, and status the server.
#  Here's a sample config for tomcat:
#    appsprofile=/opt/tomcat
#    deploydir="webapps"
#    initd_script=/etc/init.d/tomcat
#
#Dependencies: 
#  coreutils-5.97-23.el5_4.2
#  bash-3.2-24.el5
#  tar-1.15.1-30.el5
#  JBoss EWP 5.x
#  Java 1.6.x
#
#  Also depends on my custom /etc/init.d/jboss script.

export PATH="$PATH:/bin"

########### USER CONFIGURATION
#It is recommended that you go through each default value and specify your configuration
#stage=""
#war_files=""
#lib_files=""
#appsprofile=""
#appsuser=""
#deploydir=""
#libdir=""
#backupdir=""
#initd_script=""
#force_restart=0
########### END USER CONFIGURATION

########### DEFAULT CONFIGURATION
#cd to the staging directory where files to be deployed are kept;the working directory must be the staging area
cd ${stage:-/opt/staging}
#war files to deploy to deploy directory
war_files="${war_files:-something1.war something2.war}"
#jar files to deploy to lib directory
lib_files="${lib_files:-something1.jar something2.jar}"
#app server profile for app server
appsprofile=${appsprofile:-/opt/jboss/server/default}
#app server user
appsuser="${appsuser:-jboss}"
# deploy directory (relative to $appsprofile)
deploydir="${deploydir:-deploy}"
# lib directory (relative to $appsprofile)
libdir="${libdir:-lib}"
#backup copies for deployments
backupdir=${backupdir:-/opt/jboss/server/backup}
#path to init.d service script
initd_script=${initd_script:-/etc/init.d/jboss}
#force JBoss restart every time (0=allow hot deploy, 1=force a restart)
force_restart=${force_restart:-0}
########### END DEFAULT CONFIGURATION

#run through tests and determine what to deploy (or fail if none)
function preflight_check() {
  if [ ! -f "$initd_script" ];then
    echo "There is no \$initd_script $initd_script."
    echo "At a minimum the script must be able to: start, stop, and status the app server."
    echo "Preflight test failed...  Aborting."
    exit 1
  fi
  isdeploy=0
  islib=0
  if [ ! -z "$war_files" ];then
    for x in $war_files;do
      if [ -f "$x" ];then
        isdeploy=1
        break
      fi
    done
  fi
  if [ ! -z "$lib_files" ];then
    for x in $lib_files;do
      if [ -f "$x" ];then
        islib=1
        break
      fi
    done
  fi
  if [ "$isdeploy" = "0" -a "$islib" = "0" ];then
    echo "No deployments happened.  There was nothing to deploy."
    echo "Preflight test failed...  Aborting."
    exit 1
  fi
  if [ ! -d "$appsprofile" ];then
    echo "\$appsprofile dir does not exist: $appsprofile"
    echo "Preflight test failed...  Aborting."
    exit 1
  fi
  if [ ! -d "$backupdir" ];then
    echo "WARNING: \$backupdir $backupdir does not exist."
    echo -n "Creating directory..."
    mkdir -p "$backupdir" && echo "Done." || echo "Failed."
  fi
  if [ ! -d "$backupdir/$deploydir" ];then
    mkdir -p "$backupdir/$deploydir"
  fi
  if [ ! -d "$backupdir/$libdir" ];then
    mkdir -p "$backupdir/$libdir"
  fi
  if [ ! -d "$backupdir" ];then
    echo "Something went wrong with creating \$backupdir $backupdir."
    echo "Preflight test failed...  Aborting."
    exit 1
  fi
  if [ ! -d "$backupdir/$deploydir" ];then
    echo "Something went wrong with creating \$backupdir/$deploydir $backupdir/$deploydir."
    echo "Preflight test failed...  Aborting."
    exit 1
  fi
  if [ ! -d "$backupdir/$libdir" ];then
    echo "Something went wrong with creating \$backupdir/$libdir $backupdir/$libdir."
    echo "Preflight test failed...  Aborting."
    exit 1
  fi
}

#deployment logic
function deploy_wars() {
  for x in $war_files;do
    if [ -e "$x" ];then
      chown $appsuser\: "$x"
      chmod 644 "$x"
      mv -f "$x" "$appsprofile/$deploydir/$x"
      touch "$appsprofile/$deploydir/$x"
      echo "$x deployed."
    fi
  done
}
function deploy_libs() {
  for x in $lib_files;do
    if [ -e "$x" ];then
      chown $appsuser\: "$x"
      chmod 644 "$x"
      mv -f "$x" "$appsprofile/$libdir/$x"
      touch "$appsprofile/$libdir/$x"
      echo "$x deployed."
    fi
  done
}

#run through and backup everything
function backup_directories() {
  echo -n "Creating backups..."
  pushd "$appsprofile" > /dev/null
  if [ "$isdeploy" = "1" ];then
    tar -czf "$backupdir/$deploydir/$deploydir_$(date +%Y-%m-%d-%s).tar.gz" "$deploydir"
  fi
  if [ "$islib" = "1" ];then
    tar -czf "$backupdir/$libdir/$libdir_$(date +%Y-%m-%d-%s).tar.gz" "$libdir"
  fi
  popd > /dev/null
  echo "Done."
}

#check to see if server shutdown is required
function conditional_shutdown() {
  if [ "$islib" = "1" ] || [ ! "$force_restart" = "0" -a ! "$force_restart" = "false" ];then
    $initd_script stop
  fi
}

#check to see if server startup is required
function conditional_startup() {
  if [ "$islib" = "1" ] || [ ! "$force_restart" = "0" -a ! "$force_restart" = "false" ];then
    $initd_script start
    sleep 2 && $initd_script status
  fi
}

#execute deployments in a safe order
preflight_check
backup_directories
conditional_shutdown
deploy_wars
deploy_libs
conditional_startup

