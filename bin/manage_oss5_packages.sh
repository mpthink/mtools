#!/bin/sh
#
# Author: william.yang@nsn.com
#
################################

if [ `whoami` != "root" ] ; then
        echo "Only root can execute this script!"
		usage
        exit 1
fi

LOG_FILE=/var/opt/oss/log/mtools/manage_oss5_packages_`date +\%G%m%d%H%M%S`.log
myself_dn=`hostname -f`

function append_log() {
    log=$1
    ts=`date +%Y-%m-%d\ %H:%M:%S`
    echo "${ts} || ${log}" >> ${LOG_FILE}
}

function manage_package() {
        package=$1
        operation=$2

		l="Going to ${operation} package ${package} on ${myself_dn}"
		echo "${l}"
		append_log "${l}"
        res=`hamgrmx.pl ${operation} package ${package}`
        append_log "${res}"
		echo ${res}
}

function usage()
{
  echo "Usage: sh /opt/oss/mtools/ne-integration/bin/manage_oss5_pacakges.sh start|stop"
  echo ""
  echo "start should be used to start osscore, osscore2 and mvi packages"
  echo "stop should be used to stop osscore, osscore2 and mvi packages"
}

OPERATION=$1
if [ "$OPERATION" != "start" -a "$OPERATION" != "stop" ] ; then
        echo "Mandatory argument start|stop is missing"
		usage
        exit 1
fi

manage_package osscore ${OPERATION}
manage_package osscore2 ${OPERATION}
manage_package mvi ${OPERATION}
