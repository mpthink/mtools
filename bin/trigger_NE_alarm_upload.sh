#!/bin/bash
if [ -f /opt/oss/mtools/lib/mig_functions.sh ]; then
    source /opt/oss/mtools/lib/mig_functions.sh
fi

TARGET_DIR="/var/opt/nokia/oss/global/mediation/south/fm/import"
LOG_DIR="$DETAILED_LOGDIR/ne-integration"
LOG_FILE="$LOG_DIR/ne-alarm_upload.log"

FILTER_CONF="/opt/oss/mtools/conf/nasda_agent_filter/${TARGET_RELEASE_TAG}/Filter_List.conf"

tempSuffix=`date +%s%N`
FQDN_LIST="$LOG_DIR/ne-alarm_upload_dn.${tempSuffix}.txt"

#CLASSLIST="'NEMU','OMGW','MGW','TP5000','Q1A','TDXX','NETV','FHXC','FTFA','FIUE','CBBW','BSC','OMS','AXC','SGSN','FLEXINS','FLEXING','FNG','FLEXISN','LIG','PCS5000'"
#CLASSNWI3="'OMS','AXC'"

LOG_DATE_FORMAT="+%Y-%m-%d %H:%M:%S"

#trivial--1, overlap--2, prepend--3, undefined--0
DNMAPPING_STRATEGY=1
AGENT_CLASS=""

#check the directories
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p $TARGET_DIR  
    chown omc:sysop $TARGET_DIR
    chmod 775 $TARGET_DIR  
fi

if [ ! -d "$LOG_DIR" ]; then
  mkdir -p $LOG_DIR
fi

usage()
{
    echo "Usage: trigger_NE_alarm_upload.sh [-class <MOC>] [-instance <DN>]"
    exit
}

#fetch dn mapping strategy, cache the agent class and dnMappingStrategy
function fetchDnMappingStrategy {
    AGENT_CLASS=$1

    output=`grep $AGENT_CLASS $FILTER_CONF | cut -d: -f5 | head -n 1`

    if [ "$output" == "trivial" ]; then
        DNMAPPING_STRATEGY=1
    elif [ "$output" == "overlap" ]; then
        DNMAPPING_STRATEGY=2
    elif  [ "$output" == "prepend" ]; then
        DNMAPPING_STRATEGY=3
    else
        DNMAPPING_STRATEGY=0
    fi
    
    #logging
    if [ "$DNMAPPING_STRATEGY" == 1 ]; then
        echo `date "$LOG_DATE_FORMAT"`" Dn Mapping Strategy for $AGENT_CLASS : trivial" >> $LOG_FILE
    elif  [ "$DNMAPPING_STRATEGY" == 2 ]; then
        echo `date "$LOG_DATE_FORMAT"`" Dn Mapping Strategy for $AGENT_CLASS : overlap" >> $LOG_FILE
    elif  [ "$DNMAPPING_STRATEGY" == 3 ]; then
        echo `date "$LOG_DATE_FORMAT"`" Dn Mapping Strategy for $AGENT_CLASS : prepend" >> $LOG_FILE
    else
        echo `date "$LOG_DATE_FORMAT"`" Dn Mapping Strategy for $AGENT_CLASS : undefined" >> $LOG_FILE
    fi
    
    if [ $DNMAPPING_STRATEGY -eq 0 ]; then
        return 1
    else
        return 0
    fi
} 

function generateAlarm {
    myAlarmDn=$1
    myTargetFile=$2
    
    yearTime=$(echo `date +%Y`)
    monthTime=$(echo `date +%m`)
    dateTime=$(echo `date +%d`)
    hourTime=$(echo `date +%H`)
    minuteTime=$(echo `date +%M`)
    secondTime=$(echo `date +%S`)
    eventTime=`echo "${yearTime}-${monthTime}-${dateTime}T${hourTime}:${minuteTime}:${secondTime}.000"`
    alarmId="${dateTime}${hourTime}${minuteTime}${secondTime}"
    
    #handle dn mapping strategy
    #trivial--1, overlap--2, prepend--3, undefined--0
    if [ "$DNMAPPING_STRATEGY" == "1" ]; then
        : #do nothing
    elif [ "$DNMAPPING_STRATEGY" == "2" ]; then
        #or DN can be a dummy one
        myAlarmDn=`echo "$myAlarmDn" | awk -F "/$AGENT_CLASS" -vclass="$AGENT_CLASS" ' {print class$2}'`
    elif [ "$DNMAPPING_STRATEGY" == "3" ]; then
        myAlarmDn=""
    else
        return 1
    fi

    echo "<notification>" > ${myTargetFile}
    echo "    <alarmNew systemDN=\"${myAlarmDn}\">" >> ${myTargetFile}
    echo "        <alarmId>${alarmId}</alarmId>" >> ${myTargetFile}
    echo "        <eventTime>${eventTime}</eventTime>" >> ${myTargetFile}
    echo "        <specificProblem>2147483647</specificProblem>" >> ${myTargetFile}
    echo "        <alarmText>trigger alarm upload</alarmText>" >> ${myTargetFile}
    echo "        <perceivedSeverity>minor</perceivedSeverity>" >> ${myTargetFile}
    echo "        <additionalText1>Alarm Synchronization request after migrating NE to NetAct 8 system</additionalText1>" >> ${myTargetFile}
    echo "        <eventType>indeterminate</eventType>" >> ${myTargetFile}
    echo "        <probableCause>0</probableCause>" >> ${myTargetFile}
    echo "    </alarmNew>" >> ${myTargetFile}
    echo "</notification>" >> ${myTargetFile}

    return 0
}

function generateFQDN_LIST {
    TEMPCLASSLIST=$1

    OMC_PWD=`/opt/nokia/oss/bin/syscredacc.sh -user OMC -type DB -instance OSS`

    sqlplus -S omc/$OMC_PWD >"$FQDN_LIST" <<EOF
        set heading off feedback off  verify off
        select  co_dn from NASDA_objects where co_oc_id in (select oc_id from NASDA_object_class where oc_name in ($TEMPCLASSLIST));
        exit
EOF

}

function triggerClassAlarmUpload {
    MO=$1

    echo `date "$LOG_DATE_FORMAT"`" Begin trigger alarm upload for: $MO"
    
    #Get DN mapping Strategy
    fetchDnMappingStrategy $MO
    retval=$?
    if [ "$retval" == "1" ]; then
        echo `date "$LOG_DATE_FORMAT"`" Fail trigger alarm upload for: $MO"
        return 1
    fi

    #remove -all option
    #if [ -z $MO ]; then
    #   MO=$CLASSLIST
    #elif [ "$MO" == "NWI3" ]; then
    #if [ "$MO" == "NWI3" ]; then
    #   MO=$CLASSNWI3
    #elif [[ ! $MO =~ "^'.*'$" ]]; then
    #   MO=`echo \'"$MO"\'`
    #fi    
    
    MOClass=$MO
    if [[ ! $MO =~ "^'.*'$" ]]; then
       MOClass=`echo \'"$MO"\'`
    fi
    generateFQDN_LIST $MOClass
    
    while read line
    do
        FQDN=`echo "$line" | sed -e 's/^ *//' -e 's/ *$//'`
        
        if [ "x$FQDN" == "x" ]; then
            continue
        fi
        
        format_FQDN=${FQDN//\//%2F}
        
        sleep 1
        
        numStamp=`date +%s`
        tempFile=${TARGET_DIR}/an_fqdn_${format_FQDN}_${numStamp}.xml.in-progress
        targetFile=${TARGET_DIR}/an_fqdn_${format_FQDN}_${numStamp}.xml
        
        echo `date "$LOG_DATE_FORMAT"`" Begin trigger alarm upload for: $FQDN"  >> $LOG_FILE
        generateAlarm $FQDN $tempFile
        alarmGenStatus=$?

        if [ "$alarmGenStatus" == "0" ]; then
            chown omc:sysop ${tempFile}
            chmod 775 ${tempFile}
            mv $tempFile $targetFile
            
            echo `date "$LOG_DATE_FORMAT"`" End trigger alarm upload for: $FQDN" >> $LOG_FILE
        else
            echo `date "$LOG_DATE_FORMAT"`" Fail trigger alarm upload for: $FQDN" >> $LOG_FILE
        fi
        
    done <${FQDN_LIST}    

    echo `date "$LOG_DATE_FORMAT"`" End trigger alarm upload for: $MO"
}

function triggerFqdnAlarmUpload {
    FQDN=$1

    logTime=$(echo `date "$LOG_DATE_FORMAT"`)
    
    echo "$logTime Begin trigger alarm upload for: $FQDN"
    echo "$logTime Begin trigger alarm upload for: $FQDN"  >> $LOG_FILE
    
    #Get Agent Class
    AGENT_CLASS=`echo "$FQDN" | awk -F/ '{print $NF}' | cut -d- -f1`
    #Get DN mapping Strategy
    fetchDnMappingStrategy $AGENT_CLASS
    retval=$?
    if [ "$retval" == "1" ]; then
        echo "$logTime Fail trigger alarm upload for: $FQDN"
        echo "$logTime Fail trigger alarm upload for: $FQDN"  >> $LOG_FILE
        return 1
    fi
    
    format_FQDN=${FQDN//\//%2F}
    numStamp=`date +%s`
    
    tempFile=${TARGET_DIR}/an_fqdn_${format_FQDN}_${numStamp}.xml.in-progress
    targetFile=${TARGET_DIR}/an_fqdn_${format_FQDN}_${numStamp}.xml

    generateAlarm $FQDN $tempFile
    alarmGenStatus=$?

    if [ "$alarmGenStatus" == "0" ]; then
        chown omc:sysop ${tempFile}
        chmod 775 ${tempFile}
        mv $tempFile $targetFile

        echo "$logTime End trigger alarm upload for: $FQDN"
        echo "$logTime End trigger alarm upload for: $FQDN" >> $LOG_FILE
        
        return 0
    else
        echo "$logTime Fail trigger alarm upload for: $FQDN"
        echo "$logTime Fail trigger alarm upload for: $FQDN" >> $LOG_FILE
        
        return 1
    fi
}

EXIT_CODE=0

case $# in
    # remove -all option
    #1)
    #    if [ "$1" == "-all" ]
    #   then
    #        triggerClassAlarmUpload
    #    else
    #        echo "Parameters may have errors,please check.\n"
    #        usage
    #        exit 1
    #    fi
    #    ;;
    2)
        if [ "$1" == "-class" ]
        then
            triggerClassAlarmUpload $2
            EXIT_CODE=$?
        elif [ "$1" == "-instance" ]
        then
            triggerFqdnAlarmUpload $2
            EXIT_CODE=$?
        else
            echo "Parameters may have errors,please check.\n"
            usage
            EXIT_CODE=1
        fi
        ;;
    *)
        usage
        EXIT_CODE=1
        ;;
esac

echo -e "\nPlease check $LOG_FILE for the Alarm Upload trigger detail.\n"

exit $EXIT_CODE
