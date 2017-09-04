#!/bin/sh

################################
#                              #
# Author: william.yang@nsn.com #
#                              #
################################

source ./set_env.sh

THIS_CSV_FILE=$1

if [ `whoami` != "omc" ]; then
    echo "The script can only be executed by omc."
    exit 1
fi

PING_COUNT=3

function probe_by_ping() {
ip=$1
dn=$2
append_log "Start to validate ${dn} [${ip}] via ping."
n=`ping -c ${PING_COUNT} ${ip} 2>/dev/null | grep "${PING_COUNT} packets transmitted, ${PING_COUNT} received" | wc -l`
if [ "x${n}" == "x1" ] ; then
        return 0
else
        return 1
fi
}

function start_probe() {
result_file=$1
cat ${result_file} | while read line
do
        dn=`echo ${line} | awk '{ print $1 }'`
        int_id=`echo ${line} | awk '{ print $2 }'`
        ip=`echo ${line} | awk '{ print $3 }'`

        probe_by_ping ${ip} ${dn}
        result=$?
        if [ "${result}" == "0" ] ; then
			line="${dn},ok"
        else
			line="${dn},failed"
        fi
		
		append_log "Finished. Status: ${line}"
		echo ${line}
	    append_csv_content ${line} ${THIS_CSV_FILE}
done
}

rm -f ${TMP_DIR}/ping_result.txt

cat ${CONF_DIR}/ping.cfg 2>/dev/null | while read line
do
        mo=`echo ${line} | awk -F\= '{ print $1 }'`
        oc_id=`echo ${line} | awk -F\= '{ print $2 }'`

		sh get_connectivities_by_oc_id.sh ${oc_id} > ${TMP_DIR}/ping_result.txt
		start_probe ${TMP_DIR}/ping_result.txt
		rm -f ${TMP_DIR}/ping_result.txt
done
