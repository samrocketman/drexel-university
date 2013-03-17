#!/bin/bash
#Created by Sam Gleske (sag47@drexel.edu)
#Fri Mar  8 17:32:54 EST 2013
#Red Hat Enterprise Linux Server release 6.3 (Santiago)
#Linux 2.6.32-279.14.1.el6.x86_64
#this runs a execution security check on the env.sh file.
#there should only be static environment variables specified in the env.sh file
#
#To run a QA test on this file run the following command
#  ./env-security-check.sh < ./env-qa-test.sh

#allow users to export environment variables; if set to false then export command will fail security check.
allow_variable_exporting="true"

#exit code, this may get modified
result=0

while read line;do
  if echo "${line}" | grep '^\s*#' &> /dev/null;then
    #check for comments
    continue
  elif echo "${line}" | grep '^\s*$' &> /dev/null;then
    #check for blank line
    continue
  elif echo "${line}" | grep '$(' &> /dev/null || echo "${line}" | grep '`' &> /dev/null;then
    echo 'security failure: $(list) or `list` command substitution execution is not allowed in env.sh' > /dev/stderr
    result=1
  elif echo "${line}" | grep '(' &> /dev/null;then
    echo 'security failure: (list) subshell execution is not allowed in env.sh' > /dev/stderr
    result=1
  elif ! echo "${line}" | grep '^\s*[a-zA-Z_0-9]*=' &> /dev/null;then
    if "${allow_variable_exporting}";then
      if ! echo "${line}" | grep '^export ' &> /dev/null;then
        echo 'security failure: command execution detected.' > /dev/stderr
        result=1
      fi
    else
      echo 'security failure: command execution detected.' > /dev/stderr
      result=1
    fi
  elif echo "${line}" | grep '$[0-9]' &> /dev/null;then
    echo 'security failure: assignment shell script arguments to variables not allowed in env.sh' > /dev/stderr
    result=1
  fi
  #system_variables list obtained using following command
  #env | grep '^[a-zA-Z_]*=' | cut -d= -f1 | tr '\n' ' ' | sed 's/\(.*\)/\1\n/'
  system_variables="appsprofile backupdir deploydir libdir second_stage stage HOSTNAME SHELL TERM HISTSIZE USER JAVA_OPTS LS_COLORS TERMCAP PATH MAIL STY PWD JAVA_HOME LANG HISTCONTROL HOME SHLVL LOGNAME CVS_RSH WINDOW LESSOPEN G_BROKEN_FILENAMES _ OLDPWD"
  for var in ${system_variables};do
    if echo "${line}" | grep "^\s*${var}=" &> /dev/null;then
      echo "security failure: assignment of system variable ${var} is not allowed in env.sh" > /dev/stderr
      result=1
    fi
  done
done
if [ "${result}" -eq "1" ];then
  echo 'security notice: env.sh is not a shell script, only an environment file.' > /dev/stderr
else
  echo "env.sh security check pass"
fi
exit ${result}
