#!/bin/bash

BINFOLDER='/opt/oss/mtools/ne-integration/bin/'
ROLLBACKSCRIPT='/opt/oss/mtools/ne-integration/bin/*_ne-rollback.sh'
LOGPATH='/var/opt/oss/log/mtools/ne-integration/'
SUCCESS=""
FAILED=""
FAILEDFILEPOSTFIX="_ne-rollback.FAILED"
SUCCESSFILEPOSTFIX="_ne-rollback.SUCCESS"
ROLLBACKFAILEDLIST="/var/opt/oss/log/mtools/ne-integration/ne_rollback_failed_list.txt"
LOGFILE=''

usage()
{
    echo "Usage: ne-rollback.sh [-class <MOC>] [-instance <DN>] [-parallel <TRUE|FALSE>] "
    exit
}

#Used to handle the single Class, parameter is MO class
dealClass()
{
    class=$1
    find $LOGPATH -iname "$class"_ne-rollback* | xargs rm -f
    FILENAME="$class"_ne-rollback.sh
    BINFILE=`find $BINFOLDER -maxdepth 1 -iname  $FILENAME`
    if [ -n "$BINFILE" ] && [ -e $BINFILE ]
    then
        sh $BINFILE
        checkFailedFile $? $class
    else
        echo "Script $FILENAME is not found. The MO class maybe error,please check...  "
        usage
        exit 1
    fi
}

#Used to handle all scripts, when flag is TRUE or  parameter is None, run all scripts parallel, when flag is FALSE, run them in sequence
dealParallel()
{
    flag=$1
    if [ -f $ROLLBACKFAILEDLIST ]
    then
        rm -f $ROLLBACKFAILEDLIST
    fi
    #delete all log
    logFileNum=`ls $LOGPATH | grep _ne-rollback | wc -l`
    if [ $logFileNum -gt 0 ]
    then
        rm -f "$LOGPATH"*ne-rollback*
    fi
    
    scriptNum=`ls $ROLLBACKSCRIPT | wc -l`
    if [ ! -n "$flag" ] || [ $flag = "TRUE" ]
    then
        for script in `ls $ROLLBACKSCRIPT`
        do
            sh $script &
        done
        while true
        do
            sleep 30
            processNum=`ps -ef | grep _ne-rollback.sh | grep -v grep | wc -l`
            if [ $processNum -eq 0 ]
            then
                successFileNum=`ls $LOGPATH | grep ne-rollback.SUCCESS | wc -l`
                failFileNum=`ls $LOGPATH | grep ne-rollback.FAILED | wc -l`
                if [ $successFileNum -eq $scriptNum ]
                then
                    echo $SUCCESS
                    exit 0
                else
                    echo $FAILED
                    #echo `ls -l "$LOGPATH"*ne-rollback.FAILED`
                    cat "$LOGPATH"*_ne-rollback.FAILED >> $ROLLBACKFAILEDLIST
                    echo "Please get the rollback failed list from: $ROLLBACKFAILEDLIST"                    
                    exit 1
                fi
            else
                echo "--------------------------------------"
                echo "Status update at `date "+%Y.%m.%d  %H:%M:%S"`. If want to quit, click CTRL+C  "
                ps -ef | grep _ne-rollback.sh | grep -v grep
            fi
        done
    elif [ $flag = "FALSE" ]
    then
        for script in `ls $ROLLBACKSCRIPT`
        do
            sh $script 
            if [ $? -ne 0  ]
            then
                echo $FAILED
                echo $script
                cat "$LOGPATH"*_ne-rollback.FAILED >> $ROLLBACKFAILEDLIST
                echo "Please get the rollback failed list from: $ROLLBACKFAILEDLIST"
                exit 1
            fi
        done
        echo $SUCCESS
    fi
}

#Used to handle the single FQDN, parameter are MO class and DN
dealInstance()
{
    class=$1
    instance=$2
    find $LOGPATH -iname "$class"_ne-rollback* | xargs rm -f
    FILENAME="$class"_ne-rollback.sh
    BINFILE=`find $BINFOLDER -maxdepth 1 -iname  $FILENAME`
    if [ -n "$BINFILE" ] && [ -e $BINFILE ]
    then
        sh $BINFILE $instance
        checkFailedFile $? $class
    else
        echo "The parameter class or instance may have errors,please check...\n"
        usage
        exit 1
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
        exit 1
    fi
}


case $# in
    0)
        dealParallel
        ;;
    2)
        if [ "$1" == "-class" ]
        then
            dealClass $2
        elif [ "$1" == "-parallel" ]
        then
            dealParallel $2
        else
            echo "Parameters may have errors,please check.\n"
            usage
            exit 1
        fi
        ;;
    4)
        dealInstance $2 $4
        ;;
    *)
        usage
        exit 1
        ;;
esac




