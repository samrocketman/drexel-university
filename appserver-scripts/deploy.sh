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
#  For analyzing the code: environment variables are defined at the 
#  top, functions are defined after that, and executing the 
#  deployment occurs at the very end of the script.
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
#If values from user configuration are set then they will be used.  
#Otherwise the DEFAULT CONFIGURATION will use ${var:-default_value}
#It is recommended that you go through each default value and specify your configuration
#stage=""
#second_stage=""
#war_files=""
#lib_files=""
#appsprofile=""
#appsuser=""
#deploydir=""
#libdir=""
#backupdir=""
#initd_script=""
#force_restart=false
#move_or_copy="mv"
#timeout=0
#debug=false
#dryrun=false
########### END USER CONFIGURATION

########### DEFAULT CONFIGURATION
#cd to the staging directory where files to be deployed are kept;the working directory must be the staging area
stage="${stage:-/opt/staging}"
#secondary staging directory.  Check here if deployment files not in $stage.  Useful for cluster deployments.
second_stage="${second_stage:-}"
#war files to deploy to deploy directory; add space separated list of war files
war_files="${war_files:-}"
#jar files to deploy to lib directory; add space separated list of jar files
lib_files="${lib_files:-}"
#app server profile for app server
appsprofile="${appsprofile:-/opt/jboss/server/default}"
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
#force JBoss restart every time (false=allow hot deploy, true=force a restart)
force_restart="${force_restart:-false}"
#move (mv) or copy (cp)... valid values include: mv cp
move_or_copy="${move_or_copy:-mv}"
#set a timeout failure if the app server doesn't shut down after $timeout seconds. 0 is unlimited or no timeout.
timeout="${timeout:-0}"
#debug output (true=enabled debugging, false=disabled debugging)
debug="${debug:-false}"
#simulates a deployment without executing changes (true=simulate deployment, false=execute deployment)
dryrun="${dryrun:-false}"
########### END DEFAULT CONFIGURATION

#export environment variables
export appsprofile appsuser backupdir debug deploydir dryrun force_restart initd_script libdir lib_files move_or_copy second_stage stage timeout war_files

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
  #START CRITICAL CHECKS (checks which are depended on by the preflight_check in itself)
  if [ ! "${debug}" = "true" ] && [ ! "${debug}" = "false" ];then
    echo "debug=${debug} is not a valid option for debug!  Must be true or false." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    return 1
  fi
  if [ ! "${dryrun}" = "true" ] && [ ! "${dryrun}" = "false" ];then
    echo "dryrun=${dryrun} is not a valid option for dryrun!  Must be true or false." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    return 1
  fi
  #END CRITICAL CHECKS
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
  if [ ! "${force_restart}" = "true" ] && [ ! "${force_restart}" = "false" ];then
    echo "force_restart=${force_restart} is not a valid option for force_restart!  Must be true or false." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  if [ ! "${move_or_copy}" = "mv" ] && [ ! "${move_or_copy}" = "cp" ];then
    echo "move_or_copy=${move_or_copy} is not a valid option for move_or_copy!  Must be mv or cp." > /dev/stderr
    echo "Preflight test failed...  Aborting." > /dev/stderr
    STATUS=1
  fi
  isdeploy=0
  islib=0
  if [ ! -z "${war_files}" ];then
    for x in ${war_files};do
      if [ -f "${x}" ] || [ -f "${second_stage%/}/${x}" ];then
        if "${debug}";then
          echo "stage file exists: ${x}" > /dev/stderr
        fi
        isdeploy=1
        break
      elif "${debug}";then
        echo "not exist: ${x}" > /dev/stderr
      fi
    done
  fi
  if [ ! -z "${lib_files}" ];then
    for x in ${lib_files};do
      if [ -f "${x}" ] || [ -f "${second_stage%/}/${x}" ];then
        if "${debug}";then
          echo "stage file exists: ${x}" > /dev/stderr
        fi
        islib=1
        break
      elif "${debug}";then
        echo "not exist: ${x}" > /dev/stderr
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
    if "${dryrun}";then
      echo "DRYRUN: mkdir -p \"${backupdir}\"" > /dev/stderr
    else
      mkdir -p "${backupdir}" && echo "Done." > /dev/stderr || echo "Failed." > /dev/stderr
    fi
  fi
  if [ ! -d "${backupdir}/${deploydir}" ];then
    echo "WARNING: \${backupdir} ${backupdir}/${deploydir} does not exist." > /dev/stderr
    echo -n "Creating directory..." > /dev/stderr
    if "${dryrun}";then
      echo "DRYRUN: mkdir -p \"${backupdir}/${deploydir}\"" > /dev/stderr
    else
      mkdir -p "${backupdir}/${deploydir}" && echo "Done." > /dev/stderr || echo "Failed." > /dev/stderr
    fi
  fi
  if [ ! -d "${backupdir}/${libdir}" ];then
    echo "WARNING: \${backupdir} ${backupdir}/${libdir} does not exist." > /dev/stderr
    echo -n "Creating directory..." > /dev/stderr
    if "${dryrun}";then
      echo "DRYRUN: mkdir -p \"${backupdir}/${libdir}\"" > /dev/stderr
    else
      mkdir -p "${backupdir}/${libdir}" && echo "Done." > /dev/stderr || echo "Failed." > /dev/stderr
    fi
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
    #if war file does not exist in the current $stage then try to fall back to $second_stage
    if [ ! -z "${second_stage%/}" ] && [ ! -e "${x}" ] && [ -e "${second_stage%/}/${x}" ];then
      x="${second_stage%/}/${x}"
      if "${debug}";then
        echo "Falling back to \$second_stage: ${x}" > /dev/stderr
      fi
    fi
    #try to deploy
    if [ -e "${x}" ];then
      if "${dryrun}";then
        echo "DRYRUN: ${move_or_copy} -f \"${x}\" \"${appsprofile}/${deploydir}/${x}\"" > /dev/stderr
        echo "DRYRUN: ${x} deployed."
      else
        #Start of deploy command list
        chown ${appsuser}\: "${x}" && \
        chmod 644 "${x}" && \
        ${move_or_copy} -f "${x}" "${appsprofile}/${deploydir}/${x}" && \
        touch "${appsprofile}/${deploydir}/${x}" && \
        echo "${x} deployed."
        #End of deploy command list
      fi
      if [ ! "$?" -eq "0" ];then
        echo "${x} deployment FAILED!" > /dev/stderr
        STATUS=1
        break
      fi
    elif "${debug}";then
      echo "not exist: ${x}" > /dev/stderr
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
    #if war file does not exist in the current $stage then try to fall back to $second_stage
    if [ ! -z "${second_stage%/}" ] && [ ! -e "${x}" ] && [ -e "${second_stage%/}/${x}" ];then
      x="${second_stage%/}/${x}"
    fi
    #try to deploy
    if [ -e "${x}" ];then
      if "${dryrun}";then
        echo "DRYRUN: ${move_or_copy} -f \"${x}\" \"${appsprofile}/${libdir}/${x}\"" > /dev/stderr
        echo "DRYRUN: ${x} deployed."
      else
        #Start of deploy command list
        chown "${appsuser}"\: "${x}" && \
        chmod 644 "${x}" && \
        ${move_or_copy} -f "${x}" "${appsprofile}/${libdir}/${x}" && \
        touch "${appsprofile}/${libdir}/${x}" && \
        echo "${x} deployed."
        #End of deploy command list
      fi
      if [ ! "$?" -eq "0" ];then
        echo "${x} deployment FAILED!" > /dev/stderr
        STATUS=1
        break
      fi
    elif "${debug}";then
      echo "not exist: ${x}" > /dev/stderr
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
  if "${dryrun}";then
    echo "DRYRUN: Changed working directory: $PWD" > /dev/stderr
  fi
  if [ "${isdeploy}" = "1" ];then
    if "${dryrun}";then
      echo "backup ${deploydir}: ${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz"
      echo "DRYRUN: tar -czf \"${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz\" \"${deploydir}\"" > /dev/stderr
    else
      echo "backup ${deploydir}: ${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz"
      if ! tar -czf "${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz" "${deploydir}";then
        echo "Backup FAILED!" > /dev/stderr
        STATUS=1
      fi
    fi
  fi
  if [ "${islib}" = "1" ];then
    if "${dryrun}";then
      echo "${libdir} backup: ${backupdir}/${libdir}/${libdir}_${TIME}.tar.gz"
      echo "DRYRUN: tar -czf \"${backupdir}/${libdir}/${libdir_}${TIME}.tar.gz\" \"${libdir}\"" > /dev/stderr
    else
      echo "${libdir} backup: ${backupdir}/${libdir}/${libdir}_${TIME}.tar.gz"
      if ! tar -czf "${backupdir}/${libdir}/${libdir}_${TIME}.tar.gz" "${libdir}";then
        echo "Backup FAILED!" > /dev/stderr
        STATUS=1
      fi
    fi
  fi
  popd > /dev/null
  if "${dryrun}";then
    echo "DRYRUN: Changed working directory: $PWD" > /dev/stderr
  fi
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
  if [ "${islib}" = "1" ] || "${force_restart}";then
    if "${dryrun}";then
      echo "DRYRUN: \"${initd_script}\" stop" > /dev/stderr
      echo "DRYRUN: app server shutdown executed."
    else
      if [ "${timeout}" -eq "0" ];then
        if ! "${initd_script}" stop;then
          echo "Failed shutting down the app server." > /dev/stderr
          STATUS=1
        fi
      else
        if ! timeout ${timeout} "${initd_script}" stop;then
          echo "timeout=${timeout} not necessarily related to shutdown failure."
          echo "Failed shutting down the app server." > /dev/stderr
          STATUS=1
        fi
      fi
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
  if [ "${islib}" = "1" ] || "${force_restart}";then
    if "${dryrun}";then
      echo "DRYRUN: \"${initd_script}\" start" > /dev/stderr
      echo "DRYRUN: app server startup executed."
    else
      if [ "${timeout}" -eq "0" ];then
        if ! "${initd_script}" start;then
          echo "Failed to start the app server." > /dev/stderr
          STATUS=1
        elif ! sleep 2 && "${initd_script}" status &> /dev/null;then
          echo "App server failed after apparent successful startup." > /dev/stderr
          STATUS=1
        fi
      else
        if ! timeout ${timeout} "${initd_script}" start;then
          echo "Failed to start the app server." > /dev/stderr
          STATUS=1
        elif ! sleep 2 && "${initd_script}" status &> /dev/null;then
          echo "App server failed after apparent successful startup." > /dev/stderr
          STATUS=1
        fi
      fi
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

