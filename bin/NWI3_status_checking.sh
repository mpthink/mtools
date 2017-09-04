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

#/usr/bin/nokia/setossenv osscore
function probe_one() {

co_oc_id=$1
for dn in `sh get_connectivities_by_oc_id.sh ${co_oc_id} | awk '{ print $1 }'`
do
	append_log "Start to validate ${dn} via n3nmctmx."
	n=`n3nmctmx -flt ${dn} upload -d ${TMP_DIR} | grep Uploaded | grep ${dn} | wc -l`
	if [ "x$n" == "x1" ] ; then
		line="${dn},ok"
	else
		line="${dn},failed"
	fi

	append_log "Finished. Status: ${line}"
	echo ${line}
	append_csv_content ${line} ${THIS_CSV_FILE}

	rm -f ${TMP_DIR}/${dn}.xml
done
}

cat ${CONF_DIR}/nwi3.cfg 2>/dev/null | while read line
do
        mo=`echo ${line} | awk -F\= '{ print $1 }'`
        oc_id=`echo ${line} | awk -F\= '{ print $2 }'`

        probe_one ${oc_id}
done
