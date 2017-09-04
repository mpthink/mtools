#!/bin/bash

#
#################################################
#  Program: NE3S/WS Unregistration Tools
#  Author:  Tony Gong
#  Date: 03-25-2014
#  Version: 1.0
#################################################

LockFile="/var/opt/nokia/oss/global/ne3sws/work/unreg.lock"
NEFQDN="true"
ConfigFile="/etc/opt/nokia/oss/mf-conf/mfa-fragments-config.properties"
ConfigValue="none"
NewConfigValue="none"
AllNeInDB=""
ToCheckNeList=""
OssCoreFQDN=""
OSS55Cksum="99318728"
OSS54CD3PP2Cksum="99318728"
OSS55EFP1Cksum="2698790369"
PatchDir="/opt/nokia/oss/mf/mf-smx/unregpatch"
PatchFileName=""
TgtFielName="bcm_soc_creator_se-1.0-installer.zip"
MToolDir="/opt/oss/mtools/ne-integration/lib"


stopServicemix () {

echo "Stop Servicemix Now"
echo "......"

#Stop the servicemix
SMXPID=`ps -ef 2>/dev/null |grep -v grep |grep smxloadmx |awk '{print $2}'`
A=($SMXPID)

for smxloadPID in ${A[*]}
do
kill -TERM $smxloadPID 2>/dev/null
done

COUNT=10

while [ $COUNT -gt 0 ];
do

case "$COUNT" in
"5")
   echo -n -e "\r."
   ;;
"4")
   echo -n -e "\r.."
   ;;
"3")
   echo -n -e "\r..."
   ;;
"2")
   echo -n -e "\r...."
   ;;
"1")
   echo -n -e "\r....."
   ;;
"*")
   echo -n -e "\r......"
   ;;
esac

sleep 6

RET_SMX=`ps -ef 2>/dev/null | grep -e servicemix | grep -v grep| wc -l | tr -d '\n'`

if [ $RET_SMX = 0 ]; then
   echo ""
   echo ""
   echo "The Servicemix successfully stopped."
   break
fi
COUNT=$(($COUNT-1))
done

RET_SMX_1=`ps -ef 2>/dev/null | grep -e servicemix | grep -v grep| wc -l | tr -d '\n'`

if [ $RET_SMX_1 -gt 0 ]; then
   echo "Stopping Servicemix failed!"
   exit_nok;
fi

}

startServicemix ()
{
echo "Start ServiceMix Now"
echo "......"

DOMAIN=`hamgrmx.pl status | grep -w "osscore" | awk '{print $3}' | awk -F. '{print $1}' | tr -d '\n'`
WPID=`ls $VARROOT/local/common/ref/ 2>/dev/null | grep "$DOMAIN.wpmana"|awk -F . '{print $3}'|tr -d '\n'`

COUNT=20
echo "Wpmanamx PID is :$WPID"

kill -HUP $WPID 2>/dev/null
kill -HUP $WPID 2>/dev/null

while [ $COUNT -gt 0 ];
do

echo "Wait 30 seconds to check Servicemix"

sleep 30

RET_SMX=`ps -ef 2>/dev/null | grep -e servicemix | grep -v grep| wc -l | tr -d '\n'`

if [ $RET_SMX = 1 ]; then
   echo ""
   echo ""
   echo "The Servicemix Start Successfully "
   break
fi

COUNT=$(($COUNT-1))

#Add Gary@2014-03-31 "If servicemix cannot be started in 5 minutes, send HUP again"
if [ $COUNT -eq 10 ]; then
    kill -HUP $WPID 2>/dev/null
fi

done

RET_SMX_1=`ps -ef 2>/dev/null | grep -e servicemix | grep -v grep| wc -l | tr -d '\n'`

if [ $RET_SMX_1 = 0 ]; then
   echo "Start Servicemix failed!"
   exit_nok;
fi

}

AddPatch ()
{
    echo "Update the patch ......"

    CmdRet=`mkdir -p $PatchDir 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when make pacth directory"
       exit_nok;
    else
       echo "Patch directory create successfully"
    fi

    CmdRet=`scp $MToolDir/$PatchFileName $OssCoreFQDN:$PatchDir/$TgtFielName 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when Copy File"
       exit_nok;
    else
       echo "Patch fie copying done"
    fi

    CmdRet=`chown -R esbadmin:sysop $PatchDir 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when change ownership for pacth directory"
       exit_nok;
    else
       echo "Ownership Change done"
    fi

    CmdRet=`chmod 644 $PatchDir/$TgtFielName 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when change property for pacth file"
       exit_nok;
    else
       echo "Property Change done"
    fi

    CmdRet=`rm -f /opt/nokia/oss/mf/mf-smx/hotdeploy/bcm_soc_creator_se-1.0-installer.zip 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when remove orignal file"
       exit_nok;
    else
       echo "Remove orignal file done"
    fi

    CmdRet=`ln -sf $PatchDir/$TgtFielName --target-directory=/opt/nokia/oss/mf/mf-smx/hotdeploy/ 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when Replace patch file"
       exit_nok;
    else
       echo "Replace patch file done"
    fi

    CmdRet=`chown -h esbadmin:sysop /opt/nokia/oss/mf/mf-smx/hotdeploy/bcm_soc_creator_se-1.0-installer.zip 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when change ownership for new patch file"
       exit_nok;
    else
       echo "New File Ownership Change done"
    fi

    CmdRet=`chmod 644 /opt/nokia/oss/mf/mf-smx/hotdeploy/bcm_soc_creator_se-1.0-installer.zip 2>/dev/null`
    if [ "$?" -ne 0 ]; then
       echo "Error has been met when change property for New pacth file"
       exit_nok;
    else
       echo "New File Property Change done"
    fi
    
    write_config;
    echo "New Configuration item adding done"

    stopServicemix;
    startServicemix;         

}

PatchCheck ()
{

ActualCksum=`cksum /opt/nokia/oss/mf30ep1/mf-smx/hotdeploy/bcm_soc_creator_se-1.0-installer.zip 2>/dev/null | awk  '{print $1 }'`

if [ -z $ActualCksum ]; then
    echo "Failed to get Patch cksum, Check and Try again"
    exit_nok;
fi

NE3SWSVersion=`ls -l /opt/nokia/oss/mf/mf-smx/hotdeploy/mfadaptor_slt_sa-1.0.zip 2>/dev/null | sed -n "s/^.*>\(.*\)$/\1/p" | awk -F/ '{print $5}' | awk -F- '{print $4}' | awk -F. '{print $1"."$2}' | tr -d '\n'`


if [ -z $NE3SWSVersion  ] ; then
    echo "Failed to get NE3SWS version, Check and Try again"
    exit_nok;
fi

if [ $NE3SWSVersion = "7.10" ]; then

    if [ $ActualCksum = $OSS55EFP1Cksum ]; then
        echo "Un-Reg OSS5.5EFP1 Patch has been installed"
        echo "......"
    else
        echo "Un-Reg OSS5.5EFP1 Patch has not been installed"
        echo "Waiting for Patch installation"
        echo "It will take some time"
        echo "Installation starting ......"
        PatchFileName="bcm_soc_creator_se-1.0-installer.oss55efp1.zip"
        AddPatch;
    fi

elif [ $NE3SWSVersion = "7.1" ]; then

    if [ $ActualCksum = $OSS55Cksum ]; then
        echo "Un-Reg OSS5.5 Patch has been installed"
        echo "......"
    else
        echo "Un-Reg OSS5.5 Patch has not been installed"
        echo "Waiting for Patch installation"
        echo "It will take some time"
        echo "Installation starting ......"
        PatchFileName="bcm_soc_creator_se-1.0-installer.oss55.zip"
        AddPatch;
    fi


elif [ $NE3SWSVersion = "6.36" ]; then

    if [ $ActualCksum = $OSS54CD3PP2Cksum ]; then
        echo "Un-Reg OSS5.4 CD3 PP2 Patch has been installed"
        echo "......"
    else
        echo "Un-Reg OSS5.4 CD3 PP2 Patch has not been installed"
        echo "Waiting for Patch installation"
        echo "It will take some time"
        echo "Installation starting ......"
        PatchFileName="bcm_soc_creator_se-1.0-installer.oss55.zip"
        AddPatch;
    fi

elif [ $NE3SWSVersion = "6.40" ]; then
    echo "Patch is not needed for OSS5.4 MP1, continue"

elif [ $NE3SWSVersion = "7.20" ]; then
    echo "Patch is not needed for OSS5.5 MP1, continue"
else
    echo "Failed to get NE3SWS version, Check and Try again"
    exit_nok;
fi
}


echoUsage ()
{
echo " Usage for ne-ne3swsRegister.sh "
echo " Trigger the Registration for all NE3SWS NE:"
echo " ne-ne3swsRegister.sh  -r"
echo " Trigger the Un-Registration for all NE3SWS NE:"
echo " ne-ne3swsRegister.sh  -ur"
echo " Trigger the Registration for specificed NE3SWS NE:"
echo " ne-ne3swsRegister.sh  -r  <FQDN of NE>"
echo " Trigger the Un-Registration for specificed NE3SWS NE:"
echo " ne-ne3swsRegister.sh  -ur  <FQDN of NE>"
}


exit_ok ()
{
   rm -f $LockFile; 
   echo "......"
   echo "script execution done."
   echo "successfully!"
   exit 0;
}

exit_nok ()
{
   rm -f $LockFile; 
   exit 1;
}


lock_check()
{
   if [ -e $LockFile ]; then
      echo -e "Lock file:$LockFile existed!"
      echo -e "Please wait another instance exit or remove the $LockFile if no instance active now!"
      exit 1;
   else
      `touch $LockFile`
   fi

}

##############################################
#
# Function: HealthCheck
# Description: Check the NE3SWS is startup
#
##############################################
HealthCheck() 
{

echo "Waiting for ServiceMix Checking"
echo "......" 

RET_SMX=`ps -ef 2>/dev/null | grep -e servicemix -e smxloadmx | grep -v grep| wc -l | tr -d '\n' `

if [ "$RET_SMX" -eq 3 ]; then
      echo "ServiceMix is running    "
      echo "Waiting for Un-Reg Patch Checking"
      echo "...... "
else
      echo "Servicemix is not running       "
      echo "Please ensure the ServiceMix is running firstly and try again"
      exit_nok;
fi

}


queryAllNE () {

OMC_PW=`/opt/nokia/oss/bin/polpasmx -omc | tr -d '\n'`

NEIP=`sqlplus -s omc/$OMC_PW <<EOF
set heading off;
set pagesize 0;
set feedback off;
set verify off;
set echo off;
set num 20;
select CO_DN from UTP_COMMON_OBJECTS a join NE3SWS_NETYPE b on a.CO_OC_ID=b.OC_ID and a.CO_OCV_SYS_VERSION=b.OCV_SYS_VERSION where a.CO_STATE = '0' or a.CO_STATE = '2';
exit
EOF`

AllNeInDB="$NEIP"

}


write_config ()
{
sed -i 's,\(^\s*com\.nsn\.mediation\.ne3soap\.unregister\.agents.*\),,g' $ConfigFile 2>/dev/null
echo -e "com.nsn.mediation.ne3soap.unregister.agents=$NewConfigValue" >> $ConfigFile
echo "Configuration Change Done"

}

register ()
{
    if [ $NEFQDN = "none" ]; then
        echo "Start Registration for all the NE3SWS NE"
        echo "......"
        NewConfigValue="none";
        if [ $ConfigValue = "none" ]; then
            echo "No action performed since all the NE are already registration"
            exit_ok;
        fi

        if [ $ConfigValue = "all" ]; then
            echo "All the NE should be registrated now!"
            echo "Registraiton will start in two minutes, Please check the /var/log/MF/mf-info.log for detail"
            write_config;
            exit_ok;
        fi        

        # Registrate those NEs un-registrated
        echo "The following NE  will be registered now since they are un-regstered before!"
        ExistedNe=`echo $ConfigValue | sed  's/:/\n/g'`
        A=($ExistedNe);
        for NE_HOST in ${A[*]}
        do
           echo -e "$NE_HOST"
        done

        echo "Registraiton will start in two minutes, Please check the /var/log/MF/mf-info.log for detail"
        write_config;
        exit_ok;
    else
        echo "Start Registration for $NEFQDN"
        echo "......"
        queryAllNE;
        A=($NEIP);
        Found="false";
        for NE_HOST in ${A[*]}
        do
           if [ $NE_HOST = $NEFQDN ]; then
               Found="true"
               break;
           fi
        done 
        
        if [ $Found = "false" ]; then
            echo " The NE: $NEFQDN is not valid NE3SWS NE, Please check and try again"
            exit_nok;
        fi

        if [ $ConfigValue = "none" ]; then
            echo "No action performed since all the NE are already registration"
            exit_ok;
        fi

        if [ $ConfigValue = "all" ]; then
            echo "Sorry, Register one NE when all the NE is Un-registered is forbbiden"
            exit_ok;
        fi


        ExistedNe=`echo $ConfigValue | sed  's/:/\n/g'`
        A=($ExistedNe);
        NewConfigValue="" 
        i=0;   
        Found="false"
        for NE_HOST in ${A[*]}
        do 
           if [ $NEFQDN = $NE_HOST ]; then
               Found="true"
               break;
           fi  
           i=$(($i+1))           
        done
        if [ $Found  = "true" ]; then
            unset A[$i];
        else
            echo "The NE: $NEFQDN has not been un-registered before"
            echo "No action performed "
            exit_ok;
        fi

        if [ ${#A[*]} -le 0 ]; then
            NewConfigValue="none" 
        else
            for NE_HOST in ${A[*]}
            do
                NewConfigValue="$NewConfigValue:$NE_HOST"
            done           
            NewConfigValue=`echo $NewConfigValue | sed 's/^://'` 
        fi 
       
        echo "Registraiton for NE: $NEFQDN will start in two minutes, Please check the /var/log/MF/mf-info.log for detail"
        write_config;
        exit_ok;

    fi 
       
}

unreg_check ()
{

echo "Un-registration Checking begin"
echo "The Un-registration operation will start in two minutes, Please wait"

echo "Convert DN to IP for log checking firstly"
echo "......"

StartTime=`date "+%Y %m %d %H %M %S"`

# Retrieve IP from DB
IPList=()
i=0;
for NE_HOST in ${ToCheckNeList[*]}
do

QL_QUERY_RESULT=`sqlplus -s omc/$OMC_PW <<EOF
set heading off;
set pagesize 0;
set feedback off;
set verify off;
set echo off;
set num 20;
select CO_MAIN_HOST from utp_common_objects where CO_DN = '$NE_HOST' and (CO_STATE=0 OR CO_STATE=2);
exit
EOF`

if [ -n $QL_QUERY_RESULT ]; then
    IPList[$i]="$QL_QUERY_RESULT"
    i=$(($i+1))
fi

done

echo "Convertion is done"
echo "There are ${#IPList[*]} NE3SWS NE to be un-registered"

COUNT=9

while [ ${#IPList[*]} -gt 0 ]
do
    i=0;
    for NE_HOST in ${IPList[*]}
    do
       Ret_Num=`ls /var/log/MF/mf-info* | xargs -n 1 grep "Unregistration operation successful for agent : $NE_HOST" | awk -F '+' '{print $1}' | sed 's/T/ /g'| sed 's/\..*/ /g' | awk -vstrtime="$StartTime"  '{gsub(/[:-]/," ");if ( mktime($0) > mktime(strtime) ) print "yes";else print "no" }' |grep "yes"| wc -l | tr -d '\n'`
       if [ $Ret_Num -ge 1 ]; then
           echo "NE: $NE_HOST un-registered done"
           if [ ${#IPList[*]} -eq 1 ];  then
               break 2;
           else
               unset IPList[$i];
               IPList=(${IPList[*]})
               break;
           fi
           echo "$i"
       fi
       i=$(($i+1))

       if [ $i -eq ${#IPList[*]} ]; then
          echo "......"
          echo "There is no New Un-Registration information found this round"
          echo "Waiting 20 seconds for another round checking"
          sleep 20
          
          COUNT=$(($COUNT-1))
       fi
       
    done
    
    #Wait 3 minutes then quit
    if [ $COUNT -eq 0 ]; then
        break;
    fi
    
done

}

unregister ()
{

    if [ $NEFQDN = "all" ]; then
        queryAllNE;
        echo "Start Un-Registration for all the NE3SWS NE"
        echo "......"
        NewConfigValue="all";
        if [ $ConfigValue = "none" ]; then
            ToCheckNeList=($NEIP);
            echo "All the NE3SWS NE should be un-registered"
            write_config;
            unreg_check;
            exit_ok;
        fi

        if [ $ConfigValue = "all" ]; then
            echo "No Action needed since all the NE3SWS NE are un-registered"
            exit_ok;
        fi
        # UN-Registrate All NE except done
        echo "Un-registering for All NE start"
        echo "......"
        echo "The following NE  will be not be un-registered again since they are un-regstered before!"
        ExistedNe=`echo $ConfigValue | sed  's/:/\n/g'`
        A=($ExistedNe);
        B=($NEIP);
        for NE_HOST in ${A[*]}
        do
           i=0;
           Found="false";
           for DN_HOST in ${B[*]}
           do
               if [ $DN_HOST = $NE_HOST ]; then
                   Found="true";
                   break;
               fi  
               i=$(($i+1))
           done

           if [ $Found = "true" ]; then
              unset B[$i]
              echo -e "$NE_HOST"
           fi
        done
        echo "......"
        write_config;

        if [ ${#B[*]} -le 0 ]; then
            echo "Congradulation, All the NE have been un-registered before"
            echo "No action performed"
            exit_ok;
        fi        
        ToCheckNeList=(${B[*]});
        unreg_check;
        exit_ok;
    else
        echo "Start Un-Registration for $NEFQDN"
        echo "......"
        queryAllNE;
        A=($NEIP);
        Found="false";
        for NE_HOST in ${A[*]}
        do
           if [ $NE_HOST = $NEFQDN ]; then
               Found="true"
               break;
           fi
        done

        if [ $Found = "false" ]; then
            echo " The NE: $NEFQDN is not valid NE3SWS NE, Please check and try again"
            exit_nok;
        fi

        if [ $ConfigValue = "all" ]; then
            echo "No action performed since all the NE are already un-registered"
            exit_ok;
        fi

        if [ $ConfigValue = "none" ]; then
            NewConfigValue=$NEFQDN;
            ToCheckNeList=($NEFQDN);
            write_config;
            unreg_check;
            exit_ok;
 
        fi

        ExistedNe=`echo $ConfigValue | sed  's/:/\n/g'`
        A=($ExistedNe);
        NewConfigValue="";
        Found="false";
        for NE_HOST in ${A[*]}
        do
           if [ $NEFQDN = $NE_HOST ]; then
               Found="true";
               break;
           fi
        done

        if [ $Found = "true" ]; then
            echo "No action performed since NE: $NEFQDN is already un-registered"
            exit_ok;            
        else
            NewConfigValue="$ConfigValue:$NEFQDN"
            echo "Un-Registration for NE: $NEFQDN will start in two minutes"
            NewValue=`echo $NewConfigValue | sed  's/:/\n/g'`
            ToCheckNeList=($NEFQDN);
            write_config;
            unreg_check;
            exit_ok;
        fi

    fi

}


######################################################
#
# Main Function
#
######################################################

#HealthCheck;
if  [ $# -eq 0 ] || [ $# -gt 2 ]
then
   echoUsage;
   exit;
fi

OssCoreFQDN=`hamgrmx.pl status 2>/dev/null | awk '$1=="osscore" {print $3}'`

if [ -z $OssCoreFQDN ]; then
    echo "Failed to get the osscore package FQDN, Check and Try again"
    exit_nok;
fi

lock_check;
HealthCheck;
PatchCheck;

ConfigValue=`sed -n '/com\.nsn\.mediation\.ne3soap\.unregister\.agents/p' $ConfigFile | awk -F \= '{print $2}' | tr -d '\n'`

if [ -z $ConfigValue ]; then
    echo "Configuration item for Un-Reg is null, Check and Try again"
    exit_nok;
fi

while [ -n "$1" ]; do
    case $1 in

      -r)
        shift 1;
        if [ -n "$1" ]; then
           NEFQDN=$1;
        else
           NEFQDN="none";
        fi
        register;
        shift 1;;

      -ur)
        shift 1;
        if [ -n "$1" ]; then
           NEFQDN=$1;
        else
           NEFQDN="all";
        fi
        unregister;
        shift 1;;

      --*)
        echoUsage;
        exit_nok;;

      -*)
        echoUsage;
        exit_nok;;

      *)
        echoUsage;
        exit_nok;;

    esac
done

exit_ok;

