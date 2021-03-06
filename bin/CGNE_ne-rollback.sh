#!/bin/bash

# source common mtools functionality and variables
if [ -f /opt/oss/mtools/lib/mig_functions.sh ]
then
	source /opt/oss/mtools/lib/mig_functions.sh
fi

if [ -f /opt/oss/mtools/conf/mtools-rollback.conf ]
then
	source /opt/oss/mtools/conf/mtools-rollback.conf
fi

echo "CGNE rollbcak is starting";
#get IP address from mtools-rollback.conf 
OSS5_OSSCORE2_IP=${SNMP_NE_INTEGRATION_ADDRESS}

FQDN=$1

AIFBASE='/opt/oss/NSN-AutoIntegrationFramework'
AIFPERLBIN=$AIFBASE/Perl-5.14/bin/perl
MIGPERL=$AIFBASE/bin/Migration.pl
CONFPERL=$AIFBASE/bin/ConfGenerator.pl
CREDPERL=$AIFBASE/bin/CredentialCreator.pl
INTEGRATEPERL=$AIFBASE/bin/AutoIntegrator.pl
AIFLOG='/var/opt/oss/log/aif/'

TIMESTAMP=$(date +%s%N)

EXPORTDIR=${EXPORT_DIR}
if [ -n "$EXPORTDIR" ]
then
    ACCOUNTFILE=$EXPORTDIR/ne-integration/ne_accounts.csv
else
    ACCOUNTFILE=/opt/oss/mtools/data/ne-integration/conf/ne_accounts.csv
fi

INITFILE=$AIFLOG/integration/migration_init_CGNE_"$TIMESTAMP".xml
FINALFILE=$AIFLOG/integration/migration_final_CGNE_"$TIMESTAMP".xml
moDNsFILE=$AIFLOG/integration/migration_CGNE_moDNs_"$TIMESTAMP".txt

AIFLOGFILE=$AIFLOG/integration/AutoIntegrator_migration_final_CGNE_"$TIMESTAMP"_*.log
LOGBASE='/var/opt/oss/log/mtools/ne-integration'
SUCCESSFILE=$LOGBASE/CGNE_ne-rollback.SUCCESS 
FAILEDFILE=$LOGBASE/CGNE_ne-rollback.FAILED

if [ -e $LOGBASE/CGNE_ne-rollback.* ]
then
	rm $LOGBASE/CGNE_ne-rollback.*
fi

if [ ! -e $ACCOUNTFILE ]
then
	echo "">$FAILEDFILE
	exit 1
fi

if [ ! -z "$FQDN" ]
then 
	echo $FQDN > $moDNsFILE
	$AIFPERLBIN $MIGPERL $INITFILE -neType CGNE -interfaceForAgentAddress "SNMPMUS"  -accountFile $ACCOUNTFILE -instanceFile $moDNsFILE
else
	$AIFPERLBIN $MIGPERL $INITFILE -neType CGNE -interfaceForAgentAddress "SNMPMUS"  -accountFile $ACCOUNTFILE
fi

if [ -e $INITFILE ]
then
    $AIFPERLBIN $CONFPERL $INITFILE $FINALFILE
else
	echo "">$FAILEDFILE
	exit 1
fi

function callExit()
{ 

    if [ -e $INITFILE ]
    then
        rm $INITFILE
    fi
    if [ -e $FINALFILE ]
    then
        rm $FINALFILE
    fi
    if [ -e $moDNsFILE ]
    then
        rm $moDNsFILE
    fi
   
   echo "CGNE rollback is finished"
   exit $1
}

if [ -e $FINALFILE ]
then
	sed -i 's/activate.sh/deActivate.sh/g' $FINALFILE
	sed -i "s/OSS5_OSSCORE2_IP/$OSS5_OSSCORE2_IP/g" $FINALFILE
    $AIFPERLBIN $INTEGRATEPERL $FINALFILE -c
else
	echo "">$SUCCESSFILE
	callExit 0
fi



FAILNUM=`grep -i '\[.*/CGNE-.*\]\.\s*failed' $AIFLOGFILE | wc -l`
if [ $FAILNUM -gt 0 ]
then
    `grep -i '\[.*/CGNE-.*\]\.\s*failed' $AIFLOGFILE | cut -d \[ -f2 | cut -d \] -f1  > $FAILEDFILE`
     callExit 1
else
    `touch $SUCCESSFILE`
    callExit 0
fi


