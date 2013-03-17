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
#runas_appsuser=false
#deploydir=""
#libdir=""
#backupdir=""
#initd_script=""
#force_restart=false
#move_or_copy="mv"
#timeout=0
#debug=false
#dryrun=false
#enable_colors=false
########### END USER CONFIGURATION

########### DEFAULT CONFIGURATION
#cd to the staging directory where files to be deployed are kept;this will become the working directory
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
#assume will be run as apps user otherwise root is assumed (it will basically just avoid the chown command)
runas_appsuser="${runas_appsuser:-false}"
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
#just some colored output eye candy in the terminal
enable_colors="${enable_colors:-true}"
########### END DEFAULT CONFIGURATION

#clean up user defined paths in variables vars (basically remove trailing slash if there is one with parameter expansion)
stage="${stage%/}"
second_stage="${second_stage%/}"
appsprofile="${appsprofile%/}"
deploydir="${deploydir%/}"
libdir="${libdir%/}"
backupdir="${backupdir%/}"

#COLORS DOCUMENTATION
# black - 30
# red - 31
# green - 32
# brown - 33
# blue - 34
# magenta - 35
# cyan - 36
# lightgray - 37
# 
# * 'm' character at the end of each of the following sentences is used as a stop character, where the system should stop and parse the \033[ sintax.
# 
# \033[0m - is the default color for the console
# \033[0;#m - is the color of the text, where # is one of the codes mentioned above
# \033[1m - makes text bold
# \033[1;#m - makes colored text bold**
# \033[2;#m - colors text according to # but a bit darker
# \033[4;#m - colors text in # and underlines
# \033[7;#m - colors the background according to #
# \033[9;#m - colors text and strikes it
# \033[A - moves cursor one line above (carfull: it does not erase the previously written line)
# \033[B - moves cursor one line under
# \033[C - moves cursor one spacing to the right
# \033[D - moves cursor one spacing to the left
# \033[E - don't know yet
# \033[F - don't know yet
# 
# \033[2K - erases everything written on line before this.

#Colors variables
SETCOLOR_GREEN="echo -en \\033[0;32m"
SETCOLOR_RED="echo -en \\033[0;31m"
SETCOLOR_YELLOW="echo -en \\033[0;33m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETSTYLE_BOLD="echo -en \\033[1m"
SETSTYLE_UNDERLINE="echo -en \\033[4m"
SETSTYLE_NORMAL="echo -en \\033[0m"

#export environment variables
GLOBAL_VARS="appsprofile appsuser backupdir debug deploydir dryrun enable_colors force_restart initd_script libdir lib_files move_or_copy second_stage stage timeout war_files"
export ${GLOBAL_VARS}

#same as echo function except the whole text line is red
function red_echo() {
  #in order for the -n functionality to work properly $2 must be quoted when called in case of spaces
  if "${enable_colors}";then
    if [ "$1" = "-n" ];then
      ${SETCOLOR_RED} && echo -n "$2" && ${SETCOLOR_NORMAL}
    else
      ${SETCOLOR_RED} && echo "$*" && ${SETCOLOR_NORMAL}
    fi
  else
    if [ "$1" = "-n" ];then
      echo -n "$2"
    else
      echo "$*"
    fi
  fi
}

#same as echo function except the whole text line is green
function green_echo() {
  #in order for the -n functionality to work properly $2 must be quoted when called in case of spaces
  if "${enable_colors}";then
    if [ "$1" = "-n" ];then
      ${SETCOLOR_GREEN} && echo -n "$2" && ${SETCOLOR_NORMAL}
    else
      ${SETCOLOR_GREEN} && echo "$*" && ${SETCOLOR_NORMAL}
    fi
  else
    if [ "$1" = "-n" ];then
      echo -n "$2"
    else
      echo "$*"
    fi
  fi
}

#same as echo function except the whole text line is yellow
function yellow_echo() {
  #in order for the -n functionality to work properly $2 must be quoted when called in case of spaces
  if "${enable_colors}";then
    if [ "$1" = "-n" ];then
      ${SETCOLOR_YELLOW} && echo -n "$2" && ${SETCOLOR_NORMAL}
    else
      ${SETCOLOR_YELLOW} && echo "$*" && ${SETCOLOR_NORMAL}
    fi
  else
    if [ "$1" = "-n" ];then
      echo -n "$2"
    else
      echo "$*"
    fi
  fi
  return 0
}

#same as echo function except output bold text
function bold_echo() {
  #in order for the -n functionality to work properly $2 must be quoted when called in case of spaces
  if "${enable_colors}";then
    if [ "$1" = "-n" ];then
      ${SETSTYLE_BOLD} && echo -n "$2" && ${SETSTYLE_NORMAL}
    else
      ${SETSTYLE_BOLD} && echo "$*" && ${SETSTYLE_NORMAL}
    fi
  else
    if [ "$1" = "-n" ];then
      echo -n "$2"
    else
      echo "$*"
    fi
  fi
  return 0
}

#same as echo function except output underlined text
function underline_echo() {
  #in order for the -n functionality to work properly $2 must be quoted when called in case of spaces
  if "${enable_colors}";then
    if [ "$1" = "-n" ];then
      ${SETSTYLE_UNDERLINE} && echo -n "$2" && ${SETSTYLE_NORMAL}
    else
      ${SETSTYLE_UNDERLINE} && echo "$*" && ${SETSTYLE_NORMAL}
    fi
  else
    if [ "$1" = "-n" ];then
      echo -n "$2"
    else
      echo "$*"
    fi
  fi
  return 0
}

#reads stdin and highlights deploy specific environment variables
function colorize_env() {
  while read line;do
    MATCH=0
    for var in ${GLOBAL_VARS};do
      if [ ! -z "$(echo "$line" | grep -e "^$var")" ];then
        MATCH="${var}"
        break
      fi
    done
    if [ ! "${MATCH}" = "0" ];then
      #$(eval "echo \$$var")
      underline_echo -n "${MATCH}"
      echo "=$(eval "echo \$${MATCH}")"
    else
      echo "$line"
    fi
  done
}

#show environment if debugging enabled
function if_debug_print_environment() {
  if [ ! "${debug}" = "false" ];then
    echo ""
    bold_echo "== ENVIRONMENT VARIABLES =="
    if "${enable_colors}";then
      echo "debug mode style:"
      echo -n "  " && underline_echo -n "underlined text" && echo " is used to highlight env vars specific for deployment"
    fi
    echo ""
    env | colorize_env
    echo ""
    bold_echo "== EXECUTE DEPLOYMENT =="
    if "${enable_colors}";then
      echo "debug mode style:"
      green_echo -n "  green text" && echo " is used to highlight normal stdout output"
      yellow_echo -n "  yellow text" && echo " is used to highlight output which might be interesting"
      red_echo -n "  red text" && echo " is used to highlight changes which affect the running system"
    fi
    echo ""
  fi
}


#run through tests and determine what to deploy (or fail if none)
function preflight_check() {
  #START CRITICAL CHECKS (checks which are depended on by the preflight_check in itself)
  #test debug environment variable (must be bool)
  if [ ! "${debug}" = "true" ] && [ ! "${debug}" = "false" ];then
    red_echo "debug=${debug} is not a valid option for debug!  Must be true or false." 1>&2
    echo "Preflight test failed...  Aborting." 1>&2
    return 1
  fi
  #test dryrun environment variable (must be bool)
  if [ ! "${dryrun}" = "true" ] && [ ! "${dryrun}" = "false" ];then
    red_echo "dryrun=${dryrun} is not a valid option for dryrun!  Must be true or false." 1>&2
    echo "Preflight test failed...  Aborting." 1>&2
    return 1
  fi
  #test runas_appsuser environment variable (must be bool)
  if [ ! "${runas_appsuser}" = "true" ] && [ ! "${runas_appsuser}" = "false" ];then
    echo "runas_appsuser=${runas_appsuser} is not a valid option for runas_appsuser!  Must be true or false." 1>&2
    echo "Preflight test failed...  Aborting." 1>&2
    return 1
  fi
  #END CRITICAL CHECKS
  if "${debug}";then
    echo "enter function ${FUNCNAME}" 1>&2
  fi
  STATUS=0
  #test for /etc/init.d service script
  if [ ! -f "${initd_script}" ];then
    echo "There is no \${initd_script} ${initd_script}." 1>&2
    echo "  |- At a minimum the script must be able to: start, stop, and status the app server." 1>&2
    STATUS=1
  fi
  #test to make sure /etc/init.d service script is executable
  if [ ! -x "${initd_script}" ];then
    echo "\${initd_script} ${initd_script} is not executable." 1>&2
    STATUS=1
  fi
  #test force_restart environment variable (must be bool)
  if [ ! "${force_restart}" = "true" ] && [ ! "${force_restart}" = "false" ];then
    echo "force_restart=${force_restart} is not a valid option for force_restart!  Must be true or false." 1>&2
    STATUS=1
  fi
  #test move_or_copy environment variable (limited string values)
  if [ ! "${move_or_copy}" = "mv" ] && [ ! "${move_or_copy}" = "cp" ];then
    echo "move_or_copy=${move_or_copy} is not a valid option for move_or_copy!  Must be mv or cp." 1>&2
    STATUS=1
  fi
  #test enable_colors environment variable (must be bool)
  if [ ! "${enable_colors}" = "true" ] && [ ! "${enable_colors}" = "false" ];then
    #don't really care if there's something wrong with this
    echo "WARNING: enable_colors=${enable_colors} is not a valid option for enable_colors!  Must be true or false." 1>&2
    echo "  |- setting enable_colors=false"
    enable_colors="false"
  fi
  #test timeout environment variable (must be number)
  if ! [[ "${timeout}" =~ "^[0-9]+$" ]];then
    echo "timeout=${timeout} is not a valid option for timeout!  Must be number >= 0." 1>&2
    STATUS=1
  fi
  #test if $runas_appsuser set make sure the script is actually running as the $appsuser.
  if "${runas_appsuser}";then
    if [ ! "${appsuser}" = "${USER}" ];then
      echo "runas_appsuser is true.  The appsuser=${appsuser} however you're currently running as ${USER}" 1>&2
      STATUS=1
    fi
  else
    if [ ! "${USER}" = "root" ];then
      echo "Trying to run deploy.sh as user ${USER}.  Must be run as root or choose the runas_appsuser option." 1>&2
      STATUS=1
    fi
  fi
  isdeploy=0
  islib=0
  #test check all the war files and be sure at least one exists otherwise don't deploy war files
  if [ ! -z "${war_files}" ];then
    for x in ${war_files};do
      if [ -f "${x}" ] || [ -f "${second_stage%/}/${x}" ];then
        if "${debug}";then
          yellow_echo "stage file exists: ${x}" 1>&2
        fi
        isdeploy=1
        break
      elif "${debug}";then
        echo "not exist: ${x}" 1>&2
      fi
    done
  fi
  #test check all lib files and be sure at least one exists otherwise don't deploy lib files
  if [ ! -z "${lib_files}" ];then
    for x in ${lib_files};do
      if [ -f "${x}" ] || [ -f "${second_stage%/}/${x}" ];then
        if "${debug}";then
          green_echo "stage file exists: ${x}" 1>&2
        fi
        islib=1
        break
      elif "${debug}";then
        echo "not exist: ${x}" 1>&2
      fi
    done
  fi
  #test there is at least something to deploy, otherwise no need to continue the script
  if [ "${isdeploy}" = "0" -a "${islib}" = "0" ];then
    echo "No deployments happened.  There was nothing to deploy." 1>&2
    STATUS=1
  fi
  #test the app server profile exists
  if [ ! -d "${appsprofile}" ];then
    red_echo "\${appsprofile} dir does not exist: ${appsprofile}" 1>&2
    STATUS=1
  fi
  #test that the backup directory exists.  If not create it. Eventually a backup will be taken before deployment
  if [ ! -d "${backupdir}" ];then
    yellow_echo "WARNING: \${backupdir} ${backupdir} does not exist." 1>&2
    echo -n "Creating directory..." 1>&2
    if "${dryrun}";then
      echo "DRYRUN: mkdir -p \"${backupdir}\" " 1>&2
    else
      mkdir -p "${backupdir}" && echo "Done." 1>&2 || echo "Failed." 1>&2
    fi
  fi
  #test that the backup directory exists.  If not create it. Eventually a backup will be taken before deployment
  if [ ! -d "${backupdir}/${deploydir}" ];then
    yellow_echo "WARNING: \${backupdir} ${backupdir}/${deploydir} does not exist." 1>&2
    echo -n "Creating directory..." 1>&2
    if "${dryrun}";then
      red_echo "DRYRUN: mkdir -p \"${backupdir}/${deploydir}\" " 1>&2
    else
      mkdir -p "${backupdir}/${deploydir}" && echo "Done." 1>&2 || echo "Failed." 1>&2
    fi
  fi
  #test that the backup directory exists.  If not create it. Eventually a backup will be taken before deployment
  if [ ! -d "${backupdir}/${libdir}" ];then
    yellow_echo "WARNING: \${backupdir} ${backupdir}/${libdir} does not exist." 1>&2
    echo -n "Creating directory..." 1>&2
    if "${dryrun}";then
      red_echo "DRYRUN: mkdir -p \"${backupdir}/${libdir}\"" 1>&2
    else
      mkdir -p "${backupdir}/${libdir}" && echo "Done." 1>&2 || echo "Failed." 1>&2
    fi
  fi
  #final test that the backup directory exists or was successfully created
  if [ ! -d "${backupdir}" ];then
    if ! "${dryrun}";then
      echo "Something went wrong with creating \${backupdir} ${backupdir}." 1>&2
    fi
    STATUS=1
  fi
  #final test that the backup directory exists or was successfully created
  if [ ! -d "${backupdir}/${deploydir}" ];then
    if ! "${dryrun}";then
      echo "Something went wrong with creating \${backupdir}/${deploydir} ${backupdir}/${deploydir}." 1>&2
    fi
    STATUS=1
  fi
  #final test that the backup directory exists or was successfully created
  if [ ! -d "${backupdir}/${libdir}" ];then
    if ! "${dryrun}";then
      echo "Something went wrong with creating \${backupdir}/${libdir} ${backupdir}/${libdir}." 1>&2
    fi
    STATUS=1
  fi
  #if there was any failure in all of the above tests let the user know nothing is going to happen
  if [ ! "${STATUS}" -eq "0" ];then
    echo "Preflight test failed...  Aborting." 1>&2
  fi
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" 1>&2
  fi
  return ${STATUS}
}

#run through and backup everything
function backup_directories() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" 1>&2
  fi
  STATUS=0
  echo "Creating backups..."
  #custom timestamp for backup archives (used as part of the name)
  TIME="$(date +%Y-%m-%d-%s)"
  pushd "${appsprofile}" > /dev/null
  if "${dryrun}";then
    yellow_echo "DRYRUN: Changed working directory: $PWD" 1>&2
  fi
  if [ "${isdeploy}" = "1" ];then
    if "${dryrun}";then
      green_echo "backup ${deploydir}: ${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz"
      red_echo "DRYRUN: tar -czf \"${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz\" \"${deploydir}\"" 1>&2
    else
      echo "backup ${deploydir}: ${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz"
      if ! tar -czf "${backupdir}/${deploydir}/${deploydir}_${TIME}.tar.gz" "${deploydir}";then
        echo "Backup FAILED!" 1>&2
        STATUS=1
      fi
    fi
  fi
  if [ "${islib}" = "1" ];then
    if "${dryrun}";then
      green_echo "${libdir} backup: ${backupdir}/${libdir}/${libdir}_${TIME}.tar.gz"
      red_echo "DRYRUN: tar -czf \"${backupdir}/${libdir}/${libdir_}${TIME}.tar.gz\" \"${libdir}\"" 1>&2
    else
      echo "${libdir} backup: ${backupdir}/${libdir}/${libdir}_${TIME}.tar.gz"
      if ! tar -czf "${backupdir}/${libdir}/${libdir}_${TIME}.tar.gz" "${libdir}";then
        echo "Backup FAILED!" 1>&2
        STATUS=1
      fi
    fi
  fi
  popd > /dev/null
  if "${dryrun}";then
    yellow_echo "DRYRUN: Changed working directory: $PWD" 1>&2
  fi
  echo "Done."
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" 1>&2
  fi
  return ${STATUS}
}

#check to see if server shutdown is required
function conditional_shutdown() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" 1>&2
  fi
  STATUS=0
  if [ "${islib}" = "1" ] || "${force_restart}";then
    if "${dryrun}";then
      red_echo "DRYRUN: \"${initd_script}\" stop" 1>&2
      green_echo "DRYRUN: app server shutdown executed."
    else
      if [ "${timeout}" -eq "0" ];then
        if ! "${initd_script}" stop;then
          red_echo "Failed shutting down the app server." 1>&2
          STATUS=1
        fi
      else
        if ! timeout ${timeout} "${initd_script}" stop;then
          echo "timeout=${timeout} not necessarily related to shutdown failure."
          red_echo "Failed shutting down the app server." 1>&2
          STATUS=1
        fi
      fi
    fi
  fi
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" 1>&2
  fi
  return ${STATUS}
}

#deployment logic
function deploy_wars() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" 1>&2
  fi
  STATUS=0
  for x in ${war_files};do
    #if war file does not exist in the current $stage then try to fall back to $second_stage
    if [ ! -z "${second_stage%/}" ] && [ ! -e "${x}" ] && [ -e "${second_stage}/${x}" ];then
      x="${second_stage}/${x}"
      if "${debug}";then
        yellow_echo "Falling back to \$second_stage: ${x}" 1>&2
      fi
    fi
    #try to deploy
    if [ -e "${x}" ];then
      if "${dryrun}";then
        #parameter expansion to the rescue for removing the second_stage from the ${x} variable like ${x#${second_stage}/}!
        red_echo "DRYRUN: ${move_or_copy} -f \"${x}\" \"${appsprofile}/${deploydir}/${x#${second_stage}/}\"" 1>&2
        green_echo "DRYRUN: ${x} deployed."
      else
        #Start of deploy command list
        if "${runas_appsuser}";then
          chmod 644 "${x}" && \
          ${move_or_copy} -f "${x}" "${appsprofile}/${deploydir}/${x#${second_stage}}" && \
          touch "${appsprofile}/${deploydir}/${x#${second_stage}/}" && \
          green_echo "${x} deployed."
        else
          chown ${appsuser}\: "${x}" && \
          chmod 644 "${x}" && \
          ${move_or_copy} -f "${x}" "${appsprofile}/${deploydir}/${x#${second_stage}/}" && \
          touch "${appsprofile}/${deploydir}/${x#${second_stage}/}" && \
          green_echo "${x} deployed."
        fi
        #End of deploy command list
      fi
      if [ ! "$?" -eq "0" ];then
        red_echo "${x} deployment FAILED!" 1>&2
        STATUS=1
        break
      fi
    elif "${debug}";then
      echo "not exist: ${x}" 1>&2
    fi
  done
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" 1>&2
  fi
  return ${STATUS}
}

#deployment logic
function deploy_libs() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" 1>&2
  fi
  STATUS=0
  for x in ${lib_files};do
    #if war file does not exist in the current $stage then try to fall back to $second_stage
    if [ ! -z "${second_stage}" ] && [ ! -e "${x}" ] && [ -e "${second_stage}/${x}" ];then
      x="${second_stage}/${x}"
    fi
    #try to deploy
    if [ -e "${x}" ];then
      if "${dryrun}";then
        #parameter expansion to the rescue for removing the second_stage from the ${x} variable like ${x#${second_stage}/}!
        red_echo "DRYRUN: ${move_or_copy} -f \"${x}\" \"${appsprofile}/${libdir}/${x#${second_stage}/}\"" 1>&2
        green_echo "DRYRUN: ${x} deployed."
      else
        #Start of deploy command list
        if "${runas_appsuser}";then
          chmod 644 "${x}" && \
          ${move_or_copy} -f "${x}" "${appsprofile}/${libdir}/${x#${second_stage}}" && \
          touch "${appsprofile}/${libdir}/${x#${second_stage}/}" && \
          green_echo "${x} deployed."
        else
          chown ${appsuser}\: "${x}" && \
          chmod 644 "${x}" && \
          ${move_or_copy} -f "${x}" "${appsprofile}/${libdir}/${x#${second_stage}/}" && \
          touch "${appsprofile}/${libdir}/${x#${second_stage}/}" && \
          green_echo "${x} deployed."
        fi
        #End of deploy command list
      fi
      #test the status output from the deploy command list for errors
      if [ ! "$?" -eq "0" ];then
        red_echo "${x} deployment FAILED!" 1>&2
        STATUS=1
        break
      fi
    elif "${debug}";then
      echo "not exist: ${x}" 1>&2
    fi
  done
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" 1>&2
  fi
  return ${STATUS}
}

#check to see if server startup is required
function conditional_startup() {
  if "${debug}";then
    echo "enter function ${FUNCNAME}" 1>&2
  fi
  STATUS=0
  if [ "${islib}" = "1" ] || "${force_restart}";then
    if "${dryrun}";then
      red_echo "DRYRUN: \"${initd_script}\" start" 1>&2
      green_echo "DRYRUN: app server startup executed."
    else
      if [ "${timeout}" -eq "0" ];then
        if ! "${initd_script}" start;then
          red_echo "Failed to start the app server." 1>&2
          STATUS=1
        elif ! sleep 2 && "${initd_script}" status &> /dev/null;then
          red_echo "App server failed after apparent successful startup." 1>&2
          STATUS=1
        fi
      else
        if ! timeout ${timeout} "${initd_script}" start;then
          red_echo "Failed to start the app server." 1>&2
          STATUS=1
        elif ! sleep 2 && "${initd_script}" status &> /dev/null;then
          red_echo "App server failed after apparent successful startup." 1>&2
          STATUS=1
        fi
      fi
    fi
  fi
  if "${debug}";then
    echo "exit function ${FUNCNAME} return STATUS=${STATUS}" 1>&2
  fi
  return ${STATUS}
}

#execute deployments in a safe order; each step depends on a previous
#stderr will be used for error and debug messages
#stdout will be used for successful status updates
#the script will exit with a meaningful status code
if_debug_print_environment 1>&2
if [ ! -d "${stage}" ];then
  red_echo "stage=${stage} directory does not exist!" 1>&2
  echo "Preflight test failed...  Aborting." 1>&2
fi
cd "$stage" &> /dev/null && \
preflight_check && \
backup_directories && \
conditional_shutdown && \
deploy_wars && \
deploy_libs && \
conditional_startup
STATUS=$?
if [ "${debug}" = "true" ];then
  echo "exit STATUS=${STATUS}" 1>&2
fi

exit ${STATUS}

