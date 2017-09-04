#!/bin/bash

BINFOLDER="/opt/oss/mtools/ne-integration/bin"
INTEGRATIONSCRIPT="/opt/oss/mtools/ne-integration/bin/*_ne-integration.sh"
LOGPATH="/var/opt/oss/log/mtools/ne-integration/"
SUCCESS=""
FAILED=""
FAILEDFILEPOSTFIX="_ne-integration.FAILED"
SUCCESSFILEPOSTFIX="_ne-integration.SUCCESS"
INTEGRATIONFAILEDLIST="/var/opt/oss/log/mtools/ne-integration/ne_integration_failed_list.txt"
LOGFILE=''
#ALARM_UPLOADER="$BINFOLDER/trigger_NE_alarm_upload.sh"
STATUS_CACHE="OK"

usage()
{
    echo "Usage: ne-integration.sh -class <MOC> [-instance <DN>]"
    echo "Usage: ne-integration.sh -parallel <TRUE|FALSE> "
}

#Used to handle the single Class, parameter is MO class
dealClass()
{
    class=$1
    find $LOGPATH -iname "$class"_ne-integration* | xargs rm -f
    FILENAME="$class"_ne-integration.sh
    BINFILE=`find $BINFOLDER -maxdepth 1 -iname  $FILENAME` 
    if [ -n "$BINFILE" ] && [ -e $BINFILE ]
    then
        sh $BINFILE
        checkFailedFile $? $class
    else
        echo "Script: $FILENAME is not found. The MO class maybe error,please check...  "
        usage
        STATUS_CACHE="NOK"
    fi
}


#Used to handle all scripts, when flag is True or parameter is  None, run all scripts parallel, when flag is FALSE, run them in sequence
dealParallel()
{
    flag=$1
    if [ -f $INTEGRATIONFAILEDLIST ]
    then
        rm -f $INTEGRATIONFAILEDLIST
    fi
    
    #delete all log
    logFileNum=`ls $LOGPATH | grep _ne-integration | wc -l`
    if [ $logFileNum -gt 0 ]
    then
        rm -f "$LOGPATH"*ne-integration*
    fi
    
    scriptNum=`ls $INTEGRATIONSCRIPT | wc -l`
    if [ ! -n "$flag" ] || [ $flag = "TRUE" ]
    then
        for script in `ls $INTEGRATIONSCRIPT`
        do
            sh $script &
        done
        
        #check and print status
        while true
        do
            sleep 30
            processNum=`ps -ef | grep _ne-integration.sh | grep -v grep | wc -l`
            if [ $processNum -eq 0 ]
            then
                break
            else
                echo "--------------------------------------"
                echo "Status update at `date "+%Y.%m.%d  %H:%M:%S"`. If want to quit, click CTRL+C  "
                ps -ef | grep _ne-integration.sh | grep -v grep
            fi
        done
    elif [ $flag = "FALSE" ]
    then
        for script in `ls $INTEGRATIONSCRIPT`
        do
            sh $script 
            if [ $? -ne 0  ]
            then
                echo $FAILED
                echo $script
            fi
        done
    fi

    #check final status
    successFileNum=`ls $LOGPATH | grep ne-integration.SUCCESS | wc -l`
    failFileNum=`ls $LOGPATH | grep ne-integration.FAILED | wc -l`
    if [ $successFileNum -eq $scriptNum ]
    then
        echo $SUCCESS
        STATUS_CACHE="OK"
    else
        echo $FAILED
        #echo `ls -l "$LOGPATH"*ne-integration.FAILED`
        cat "$LOGPATH"*_ne-integration.FAILED >> $INTEGRATIONFAILEDLIST
        echo "Please get the integration failed list from: $INTEGRATIONFAILEDLIST"
        STATUS_CACHE="NOK"
    fi
}

#Used to handle the single FQDN, parameter are MO class and DN
dealInstance()
{
    class=$1
    find $LOGPATH -iname "$class"_ne-integration* | xargs rm -f
    instance=$2
    FILENAME="$class"_ne-integration.sh
    BINFILE=`find $BINFOLDER -maxdepth 1 -iname  $FILENAME`
    if [ -n "$BINFILE" ] && [ -e $BINFILE ]
    then
        sh $BINFILE $instance
        checkFailedFile $? $class
    else
        echo "The parameter class or instance may have error,please check...\n"
        usage
        STATUS_CACHE="NOK"
    fi
}

#Used to check failed file and print it
checkFailedFile()
{
    status=$1
    class=$2
    if [ $status -eq 0 ]
    then
        echo $SUCCESS
        STATUS_CACHE="OK"
    else
        echo $FAILED
        FailedFileName="$class$FAILEDFILEPOSTFIX"
        failedFile=`find $LOGPATH -iname  $FailedFileName`
        if [ -n $failedFile ] && [ -e $failedFile ]
        then
            echo $failedFile
        else
            echo "$failedFile is not exist...\n"
        fi
        STATUS_CACHE="NOK"
    fi
}

case $# in
    0)
        dealParallel
        
        #Trigger Alarm upload
        #sh $ALARM_UPLOADER -all
        ;;
    2)
        if [ "$1" == "-class" ]
        then
            className=$2
            dealClass $className
            
            #Trigger Alarm upload
            #sh $ALARM_UPLOADER -class $className
        elif [ "$1" == "-parallel" ]
        then
            dealParallel $2
            
            #Trigger Alarm upload
            #sh $ALARM_UPLOADER -all
        else
            echo "Parameters maybe may have errors,please check.\n"
            usage
            STATUS_CACHE="NOK"
        fi
        ;;
    4)
        objDn=$4
        dealInstance $2 $objDn
        
        #Trigger Alarm upload
        #sh $ALARM_UPLOADER -instance $objDn

        ;;
    *)
        usage
        STATUS_CACHE="NOK"
        ;;
esac

#check the Status and exit
if [ "$STATUS_CACHE" == "OK" ]; then
    echo -e "\nNE integration is successfully completed\n"
    exit 0
else
    echo -e "\nNE integration is failed fully/partially\n"
    exit 1
fi 
