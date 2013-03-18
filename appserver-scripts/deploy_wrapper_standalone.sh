#!/bin/bash
#Created by Sam Gleske (sag47@drexel.edu)
#Sun Mar 17 01:05:41 EDT 2013
#Red Hat Enterprise Linux Server release 5.5 (Tikanga)
#Linux 2.6.18-194.11.4.el5 x86_64

#warning; this script is still immature and designed to work
#just with jboss.  Unlike the deploy.sh script which is
#highly configurable for any app server.  It will require
#extensive modification for your build environment.

#CI server to connect to get env.sh file
ci_server="ci.server.com"
#workspace path where the env.sh is located
ci_workspace="/opt/jenkins_builder/jobs/some_job_name/workspace"
#where do we pull the war files from?
test_server="test.server.com"
#this is where war files will be deployed to.  From test to prod.
prod_server="prod.server.com"
#staging directory where all the files will be kept.  This should be the same as deploy.sh
stage="/opt/staging"
#prepend the subject of the email
email_subject_prepend="$HOSTNAME: "
#remove trailing slash from ci_workspace if there is one.
ci_workspace="${ci_workspace%/}"


if [ "${HOSTNAME}" = "${prod_server}" ];then
  cd "${stage}"

  #download env.sh from the CI server using sftp
  sftp ${ci_server} &> /dev/null <<EOF
cd "${ci_workspace}"
get env.sh
EOF
  if [ ! "$?" -eq "0" ] || [ ! -f "env.sh" ];then
    echo "Could not get env.sh!" > /dev/stderr
    exit 1
  fi
  if ! ./env-security-check.sh < ./env.sh;then
    exit 1
  fi
  . ./env.sh
  #force variables for env.sh security purposes
  stage="/app/stage"
  appsprofile="/app/jboss/server/default"
  deploydir="deploy"
  libdir="lib"
  export debug dryrun email enable_colors force_restart lib_files timeout war_files
  for x in ${war_files};do
    sftp ${test_server}:"${appsprofile}/${deploydir}/${x}" ./
  done
  for x in ${lib_files};do
    sftp ${test_server}:"${appsprofile}/${libdir}/${x}" ./
  done
  #create a schedule if we're not doing an instant deployment
  /usr/bin/at ${TIME} <<EOF
#Scheduler by Sam Gleske (sag47@drexel.edu)
#Sun Mar 17 05:20:24 EDT 2013
rootdir=${stage}
cd \${rootdir}
dlog=\${rootdir}/deploy.log
#vamp the env.sh file for security issues
if ! ./env-security-check.sh < ./env.sh &> "\${dlog}";then
  exit 1
fi
. ./env.sh
#force variables for evn.sh security purposes
appsprofile="/app/jboss/server/default"
deploydir="deploy"
libdir="lib"
enable_colors="false"

export debug dryrun email enable_colors force_restart lib_files timeout war_files

logdir="/app/jboss/server/default/logs"
logs=()
logs+=("/app/jboss/server/default/log/server.log")
logs+=("/app/jboss/server/default/log/boot.log")
for x in \${war_files};do
  logs+=("\${logdir}/\${x/%.war/.log}")
done
echo "=== START DEPLOYMENT ===" >> "\${dlog}"
date >> "\${dlog}"
#append both stderr and stdout to the dlog file
sudo "\${rootdir}"/deploy.sh >> "\${dlog}" 2>&1
date >> "\${dlog}"
echo "=== END DEPLOYMENT ===" >> "\${dlog}"
cat "\${dlog}" | mail -s "${email_subject_prepend}deployment deploy.log" \${email}

#
# Mail Logs for analyzing 5 minutes after the deployment
#

function maillogs() {
  for log in \${logs[@]};do
    echo "sending mail deployment \$(basename \${log})"
    if [ -f "\${log}" ];then
      tail -n 5000 \${log} | mail -s "${email_subject_prepend}deployment \$(basename \${log})" \${email}
    else
      echo "ERROR \${log} file does not exist!" | mail -s "${email_subject_prepend}ERROR deployment \$(basename \${log})" \${email}
    fi
  done
}
if [ ! -z "\$email" ];then
  sleep 300 && maillogs
fi
EOF
fi
