#!/bin/sh

################################
#                              #
# Author: william.yang@nsn.com #
#                              #
################################

myself=$0

###
# Exit if the connectivity_validation.sh has already been running.
###
#if [ `ps -ef | grep "${myself}" | grep -v grep | wc -l` -gt 1  ] ; then
#    echo "The script connectivity_validation.sh has been running."
#    exit 1
#fi

if [ `whoami` != "root" ]; then
    echo "The script can only be executed by root."
    exit 1
fi

source set_env.sh
chown -R omc:sysop /var/opt/oss/log/mtools/

su - omc --session-command="cd ${basepath} && sh connectivity_validation_core.sh"
