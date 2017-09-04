#!/bin/sh

################################
#                              #
# Author: william.yang@nsn.com #
#                              #
################################

function set_osscore_env() {
IFWTOOL=/usr/bin/nokia/IFWGetData.pl
MYSHELL=${SHELL}
PN=$1

if [ "x${PN}" = "x" ]; then
        HN="local"
else
        HN=${PN}
        PHN=`$IFWTOOL --GetHostnameForPackage ${HN}`
        r=$?
        if [ $r != 0 ]; then
                echo "ERROR: Cannot resolve hostname for package ${HN}"
                exit 1
        fi
        OSSHOST=${PHN}
        export OSSHOST
        TUB_BUFF_DIR="/var/opt/nokia/oss/${HN}/common/buffer"
        TUB_LOCK_DIR="/var/opt/nokia/oss/${HN}/common/lock"
        export TUB_BUFF_DIR TUB_LOCK_DIR
fi
}

if [ "${TMP_DIR}" == "" ] ; then
	TMP_DIR=/var/opt/oss/log/mtools/ne-integration/connectivity_validation_`date +%Y%m%d%H%M%S`
	if [ ! -d ${TMP_DIR} ] ; then
		mkdir -p ${TMP_DIR}
	fi
fi

basepath=$(cd `dirname $0`; pwd)
CONF_DIR=${basepath}/../conf
NE_INT_LOGDIR=/var/opt/oss/log/mtools/ne-integration
LOG_FILE=${NE_INT_LOGDIR}/connectivity_validation.log


function append_csv_content() {
line=$1
CSV_FILE=$2
#if [ ! -f ${CSV_FILE} ] ; then
#	echo "FQDN,Status" > ${CSV_FILE}
#fi

echo ${line} >> ${CSV_FILE}
}

function append_log() {
    log=$1
    ts=`date +%Y-%m-%d\ %H:%M:%S`
    echo "${ts} || ${log}" >> ${LOG_FILE}
}

set_osscore_env osscore
