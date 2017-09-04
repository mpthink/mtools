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

MIB_ID=".1.3.6.1.2.1.1.3.0"

function probe_snmp_agent() {
ip=$1
dn=$2
append_log "Start to validate ${dn} [${ip}] via snmpget."
n=`snmpget -v2c -c public ${ip} ${MIB_ID} 2>/dev/null | grep Timeticks | wc -l`
if [ "x${n}" == "x1" ] ; then
        return 0
else
        return 1
fi
}

function start_probe() {
result_file=$1
cat ${result_file} 2>/dev/null | while read line
do
        dn=`echo ${line} | awk '{ print $1 }'`
        oc_id=`echo ${line} | awk '{ print $2 }'`
        ip=`echo ${line} | awk '{ print $3 }'`

        probe_snmp_agent ${ip} ${dn}
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

rm -f ${TMP_DIR}/snmp_result.txt
touch ${TMP_DIR}/snmp_result.txt
cat ${CONF_DIR}/snmp.cfg | while read line
do
        mo=`echo ${line} | awk -F\= '{ print $1 }'`
        oc_id=`echo ${line} | awk -F\= '{ print $2 }'`

		sh get_connectivities_by_oc_id.sh ${oc_id} >> ${TMP_DIR}/snmp_result.txt
done

start_probe ${TMP_DIR}/snmp_result.txt
rm -f ${TMP_DIR}/snmp_result.txt
