#!/bin/bash

################################
#                              #
# Author: william.yang@nsn.com #
#                              #
################################

function usage() {
	echo ""
	echo "Usage: sh get_connectivities_by_oc_id.sh <co_oc_id>"
	echo ""
}

if [ "$#" == "0" ] ; then
	usage
	exit 1
fi

omc_passwd=`polpasmx -omc`
#sqlplus -S omc/$omc_passwd >/home/omc/result.log <<EOF
sqlplus -S omc/$omc_passwd <<EOF
col co_dn for a40
col co_int_id for 9999999999
col co_main_host for a80
set line 200
set heading off
set feedback off
set newp none 
select CO_DN,CO_INT_ID,CO_MAIN_HOST from utp_common_objects where CO_OC_ID = $1 and CO_STATE != 9;
exit
EOF
