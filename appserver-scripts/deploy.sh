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

export PATH="${PATH}:/bin"

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
#debug=false
########### END USER CONFIGURATION

########### DEFAULT CONFIGURATION
#cd to the staging directory where files to be deployed are kept;the working directory must be the staging area
stage="${stage:-/opt/staging}"
#war files to deploy to deploy directory; add space separated list of war files
war_files="${war_files:-}"
#jar files to deploy to lib directory; add space separated list of jar files
lib_files="${lib_files:-}"
#app server profile for app server
appsprofile=${appsprofile:-/opt/jboss/server/default}
#app server user
appsuser="${appsuser:-jboss}"
# deploy directory (relative to ${appsprofile})
deploydir="${deploydir:-deploy}"
# lib directory (relative to ${appsprofile})
libdir="${libdir:-lib}"
#backup copies for deployments
backupdir="${backupdir:-/opt/jboss/server/backup}"
#path to init.d service script
initd_script="${initd_script:-/etc/init.d/jboss}"
#force JBoss restart every time (0=allow hot deploy, 1=force a restart)
force_restart=${force_restart:-0}
#enable debugging output (false=no debugging, true=debugging messages enabled)
debug="${debug:-false}"
########### END DEFAULT CONFIGURATION

#export environment variables
export stage war_files lib_files appsprofile appsuser deploydir libdir backupdir initd_script force_restart debug

#show environment if debugging enabled
function if_debug_print_environment() {
  if [ ! "${debug}" = "false" ];then
    echo "== ENVIRONMENT VARIABLES =="
    echo ""
    env
    echo ""
    echo "== EXECUTE DEPLOYMENT =="
  fi
}

#run through tests and determine what to deploy (or fail if none)
function preflight_check() {
  if [ ! "${debug}" = "true" ] && [ ! "${debug}" = "false" ];then
    echo "debug=${debug} is not a valid option for debug!  Must be true or false." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    return 1
  fi
  if "${debug}";then
    echo "enter function ${FUNCNAME}" > /dev/stderr
  fi
  STATUS=0
  if [ ! -f "${initd_script}" ];then
    echo "There is no \${initd_script} ${initd_script}." > /dev/stderr
    echo "At a minimum the script must be able to: start, stop, and status the app server." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  isdeploy=0
  islib=0
  if [ ! -z "${war_files}" ];then
    for x in ${war_files};do
      if [ -f "${x}" ];then
        isdeploy=1
        break
      fi
    done
  fi
  if [ ! -z "${lib_files}" ];then
    for x in ${lib_files};do
      if [ -f "${x}" ];then
        islib=1
        break
      fi
    done
  fi
  if [ "${isdeploy}" = "0" -a "${islib}" = "0" ];then
    echo "No deployments happened.  There was nothing to deploy." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  if [ ! -d "${appsprofile}" ];then
    echo "\${appsprofile} dir does not exist: ${appsprofile}" > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  if [ ! -d "${backupdir}" ];then
    echo "WARNING: \${backupdir} ${backupdir} does not exist." > /dev/stderr
    echo -n "Creating directory..." > /dev/stderr
    mkdir -p "${backupdir}" && echo "Done." > /dev/stderr || echo "Failed." > /dev/stderr
  fi
  if [ ! -d "${backupdir}/${deploydir}" ];then
    mkdir -p "${backupdir}/${deploydir}"
  fi
  if [ ! -d "${backupdir}/${libdir}" ];then
    mkdir -p "${backupdir}/${libdir}"
  fi
  if [ ! -d "${backupdir}" ];then
    echo "Something went wrong with creating \${backupdir} ${backupdir}." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  if [ ! -d "${backupdir}/${deploydir}" ];then
    echo "Something went wrong with creating \${backupdir}/${deploydir} ${backupdir}/${deploydir}." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  if [ ! -d "${backupdir}/${libdir}" ];then
    echo "Something went wrong with creating \${backupdir}/${libdir} ${backupdir}/${libdir}." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
  fi
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" > /dev/stderr
  fi
  return ${STATUS}
}

#deployment logic
function deploy_wars() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" > /dev/stderr
  fi
  STATUS=0
  for x in ${war_files};do
    if [ -e "${x}" ];then
      #Start of deploy command list
      chown ${appsuser}\: "${x}" && \
      chmod 644 "${x}" && \
      mv -f "${x}" "${appsprofile}/${deploydir}/${x}" && \
      touch "${appsprofile}/${deploydir}/${x}" && \
      echo "${x} deployed."
      #End of deploy command list
      if [ ! "$?" -eq "0" ];then
        echo "${x} deployment FAILED!" > /dev/stderr
        STATUS=1
        break
      fi
    elif "${debug}";then
      echo "${x} does not exist."
    fi
  done
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" > /dev/stderr
  fi
  return ${STATUS}
}
function deploy_libs() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" > /dev/stderr
  fi
  STATUS=0
  for x in ${lib_files};do
    if [ -e "${x}" ];then
      #Start of deploy command list
      chown "${appsuser}"\: "${x}" && \
      chmod 644 "${x}" && \
      mv -f "${x}" "${appsprofile}/${libdir}/${x}" && \
      touch "${appsprofile}/${libdir}/${x}" && \
      echo "${x} deployed."
      #End of deploy command list
      if [ ! "$?" -eq "0" ];then
        echo "${x} deployment FAILED!" > /dev/stderr
        STATUS=1
        break
      fi
    elif "${debug}";then
      echo "${x} does not exist." > /dev/stderr
    fi
  done
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" > /dev/stderr
  fi
  return ${STATUS}
}

#run through and backup everything
function backup_directories() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" > /dev/stderr
  fi
  STATUS=0
  echo "Creating backups..."
  TIME="$(date +%Y-%m-%d-%s)"
  pushd "${appsprofile}" > /dev/null
  if [ "${isdeploy}" = "1" ];then
    echo "${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz"
    if ! tar -czf "${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz" "${deploydir}";then
      echo "Backup FAILED!" > /dev/stderr
      STATUS=1
    fi
  fi
  if [ "${islib}" = "1" ];then
    if ! tar -czf "${backupdir}/${libdir}/${libdir_}${TIME}.tar.gz" "${libdir}";then
      echo "Backup FAILED!" > /dev/stderr
      STATUS=1
    fi
  fi
  popd > /dev/null
  echo "Done."
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" > /dev/stderr
  fi
  return ${STATUS}
}

#check to see if server shutdown is required
function conditional_shutdown() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" > /dev/stderr
  fi
  STATUS=0
  if [ "${islib}" = "1" ] || [ ! "${force_restart}" = "0" -a ! "${force_restart}" = "false" ];then
    if ! "${initd_script}" stop;then
      echo "Failed shutting down the app server" > /dev/stderr
      STATUS=1
    fi
  fi
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" > /dev/stderr
  fi
  return ${STATUS}
}

#check to see if server startup is required
function conditional_startup() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" > /dev/stderr
  fi
  STATUS=0
  if [ "${islib}" = "1" ] || [ ! "${force_restart}" = "0" -a ! "${force_restart}" = "false" ];then
    if ! "${initd_script}" start;then
      if ! sleep 2 && "${initd_script}" status;then
        echo "App server failed after apparent successful startup." > /dev/stderr
        STATUS=1
      fi
      echo "Failed to start the app server" > /dev/stderr
      STATUS=1
    fi
  fi
  if "${debug}";then
    echo "exit function exit function ${FUNCNAME} return STATUS=${STATUS}" > /dev/stderr
  fi
  return ${STATUS}
}

#execute deployments in a safe order; each step depends on a previous
#stderr will be used for error and debug messages
#stdout will be used for successful status updates
#the script will exit with a meaningful status code
if_debug_print_environment > /dev/stderr
cd "$stage" && \
preflight_check && \
backup_directories && \
conditional_shutdown && \
deploy_wars && \
deploy_libs && \
conditional_startup
STATUS=$?
if "${debug}";then
  echo "exit STATUS=${STATUS}" > /dev/stderr
fi

exit ${STATUS}

