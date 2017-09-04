#!/bin/sh

################################
#                              #
# Author: william.yang@nsn.com #
#                              #
################################

myself=$0

source set_env.sh
###
if [ ! -w ${TMP_DIR} ] ; then
	echo "The user omc has no write access to ${TMP_DIR}."
	exit 1
fi
###

function background_process_polling() {
	program_script=$1

	while [ `ps -ef | grep "${program_script}" | grep -v grep | wc -l` -ne 0 ]
	do
		echo "${program_script} still alive."
		sleep 1	
	done
}

NWI3_CHECK_RESULT="${TMP_DIR}/nwi3_cresult.txt"
MML_CHECK_RESULT="${TMP_DIR}/mml_cresult.txt"
PING_CHECK_RESULT="${TMP_DIR}/ping_cresult.txt"
SNMP_CHECK_RESULT="${TMP_DIR}/snmp_cresult.txt"

rm -f ${NWI3_CHECK_RESULT} ${MML_CHECK_RESULT} ${PING_CHECK_RESULT} ${SNMP_CHECK_RESULT}

append_log "Process connectivity_validation started."

sh NWI3_status_checking.sh ${NWI3_CHECK_RESULT} &
sh Ping_status_checking.sh ${PING_CHECK_RESULT} &
sh MML_status_checking_c7xtermx.sh ${MML_CHECK_RESULT} &
sh SNMP_status_checking.sh ${SNMP_CHECK_RESULT} &

background_process_polling NWI3_status_checking.sh
background_process_polling Ping_status_checking.sh
background_process_polling MML_status_checking_c7xtermx.sh
background_process_polling SNMP_status_checking.sh

# Generate CSV final result.
CSV_FILE=${NE_INT_LOGDIR}/probing_`date +%Y%m%d%H%M%S`.csv
if [ -f ${CSV_FILE} ] ; then
	rm -f ${CSV_FILE}
fi

echo "FQDN,Status" >> ${CSV_FILE}

if [ -f ${NWI3_CHECK_RESULT} ] ; then
	cat ${NWI3_CHECK_RESULT} >> ${CSV_FILE}
fi

if [ -f ${MML_CHECK_RESULT} ] ; then
    cat ${MML_CHECK_RESULT} >> ${CSV_FILE}
fi

if [ -f ${PING_CHECK_RESULT} ] ; then
    cat ${PING_CHECK_RESULT} >> ${CSV_FILE}
fi

if [ -f ${SNMP_CHECK_RESULT} ] ; then
    cat ${SNMP_CHECK_RESULT} >> ${CSV_FILE}
fi

if [ -f ${CSV_FILE} ] ; then
    echo "${CSV_FILE} generated."
else
    echo "${CSV_FILE} not found. Nothing to be generated."
fi

append_log "Process connectivity_validation completed."
