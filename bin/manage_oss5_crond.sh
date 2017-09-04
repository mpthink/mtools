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

LOG_FILE=/var/opt/oss/log/mtools/manage_oss5_crond_`date +\%G%m%d%H%M%S`.log
myself_dn=`hostname -f`

function append_log() {
    log=$1
    ts=`date +%Y-%m-%d\ %H:%M:%S`
    echo "${ts} || ${log}" >> ${LOG_FILE}
}

function manage_crond() {
        operation=$1
        for cs_node in `ldapacmx.pl -se NO_ROLES`
        do
            if [ "${operation}" == "start" ] || [ "${operation}" == "stop" ] ; then
				l="Going to ${operation} service crond on ${cs_node}"
				echo "${l}"
				append_log "${l}"
				if [  "${myself_dn}" == ${cs_node} ] ; then
					output=`service crond ${operation}`
				else
					output=`ssh ${cs_node} "service crond ${operation}"`
				fi
				status=$?
                append_log "${output}"
				echo ${output}
				if [ "${status}" == "1" ] ; then
					echo "Failed to ${operation} service crond."
					echo
					echo "Please check crond service status. Refer to ${LOG_FILE} for more details."
					echo
					exit 1
				fi
            fi
        done
}

function usage()
{
  echo "Usage: sh /opt/oss/mtools/ne-integration/bin/manage_oss5_crond.sh start|stop"
  echo "start should be used to start the crond on CS1 and CS2 nodes"
  echo "stop should be used to stop the crond on CS1 and CS2 nodes"
}

OPERATION=$1
if [ "$OPERATION" != "start" -a "$OPERATION" != "stop" ] ; then
        echo "Mandatory argument start|stop is missing"
		usage
        exit 1
fi

manage_crond ${OPERATION}
