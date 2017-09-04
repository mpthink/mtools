#!/bin/sh

CLASSLIST=$1
HOST_FILE=$2

function addKeysIntoMergeFile(){
    local i=1
    local sign='#'
    while read line
    do
        if [ ${line:0:1} != $sign ] ;then
            arr[$i]="$line"
            i=`expr $i + 1`
        fi
    done < $1

    local length=`expr $i - 1`
    i=1
    for i in `seq $length` ;do
        ip=`echo "${arr[$i]}" | awk '{print $1}'`
        isExists=`grep $ip $2 | wc -l`
        if [ $isExists -eq 0 ] ;then
            echo "${arr[$i]}" >> $2
         else
			sed -i /$ip/d $2
			echo "${arr[$i]}" >> $2
        fi
    done
}

if [ ! -f $HOST_FILE ]
then
	touch $HOST_FILE
fi


KEY_TOOL="/opt/oss/NSN-mf_swp/smx/bin/gather_ssh_public_keys.pl"
TIMESTAMP=$(date +%s%N)
TEMP_HOST_FILE=/var/tmp/sshkey_temp_host_${TIMESTAMP}
TEMP_GENERATE_FILE=/var/tmp/sshkey_temp_generate_${TIMESTAMP}

cp ${HOST_FILE} ${TEMP_HOST_FILE} 

perl ${KEY_TOOL}  -elements $CLASSLIST -output ${TEMP_GENERATE_FILE}

if [ $? -ne 0 ]
then
	exit 1
fi

addKeysIntoMergeFile ${TEMP_GENERATE_FILE} ${TEMP_HOST_FILE}

cp ${TEMP_HOST_FILE} ${HOST_FILE}

rm ${TEMP_GENERATE_FILE} ${TEMP_HOST_FILE}

