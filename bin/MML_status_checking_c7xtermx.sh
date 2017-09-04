#!/bin/bash

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

function probe_with_c7xtermx() {
fqdn=$2
	append_log "Start to validate ${fqdn} via c7xtermx."
/usr/bin/expect -c "set timeout -1
    spawn -noecho c7xtermx -i $1
    expect {
        \"MAIN LEVEL COMMAND\" { exit 0 }
		\"Press Enter to continue\" { exit 1 }
        timeout {exit 1}
    }
    interact"
}

Q3_RESULT="${TMP_DIR}/q3_result.txt"
cat ${CONF_DIR}/mml.cfg 2>/dev/null | while read line
do
		rm -f ${Q3_RESULT}
		
        mo=`echo ${line} | awk -F\= '{ print $1 }'`
        oc_id=`echo ${line} | awk -F\= '{ print $2 }'`

		sh get_connectivities_by_oc_id.sh ${oc_id} > ${Q3_RESULT}
		
		cat ${Q3_RESULT} 2>/dev/null | while read line
		do
			dn=`echo ${line} | awk '{ print $1 }'`
	        int_id=`echo ${line} | awk '{ print $2 }'`	

			probe_with_c7xtermx ${int_id} ${dn}

			if [ "$?" == "0" ] ; then
				line="${dn},ok"
			else
				line="${dn},failed"
			fi

			append_log "Finished. Status: ${line}"
			echo ${line}
			append_csv_content ${line} ${THIS_CSV_FILE}	
		done
 
		rm -f ${Q3_RESULT}
done

rm -f ${Q3_RESULT}
