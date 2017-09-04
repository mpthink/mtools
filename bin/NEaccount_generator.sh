#!/bin/bash
if [ ! -r /opt/oss/mtools/lib/mig_functions.sh ] ; then
    echo "Bash library file /opt/oss/mtools/lib/mig_functions.sh doesn't exists or it is not readable!"
    exit 1
fi
if [ ! -r /opt/oss/mtools/lib/mig_logging_helper.sh ] ; then
    echo "Bash library file /opt/oss/mtools/lib/mig_logging_helper.sh doesn't exists or it is not readable!"
    exit 1
fi

#source common mtools functionality and variables
source /opt/oss/mtools/lib/mig_functions.sh
source /opt/oss/mtools/lib/mig_logging_helper.sh

#Variables
#The SOURCE_DB_ADMIN  and SOURCE_DB_ADMIN_PASSWD is defined in the mtool.conf file #

DATABASE_USER="omc"
DATABASE_PASSWORD=`polpasmx -omc`

NE_FILTER_CONF="/opt/oss/mtools/ne-integration/conf/NE_filter.conf"
CSV_FILE_DIR="/opt/oss/mtools/data/ne-integration"
LOGDIR="/var/opt/oss/log/mtools"
CSV_TEMPLATE_DIR="$CSV_FILE_DIR/conf"
LOGFILE_BSC="$CSV_TEMPLATE_DIR/BSC_CM_XMLevents_conf.csv"


printOptions()
{

   echo "------------------------------------------------------------------------"
   echo "Options:"
   echo ""
   echo "/opt/oss/mtools/ne-integration/bin/NEaccount_generator.sh: Execute script"
   echo "-h or --help:           Show help"
   echo ""
   echo "------------------------------------------------------------------------"
}
printHelp ()
{
   echo "------------------------------------------------------------------------"
   echo "Usage:"
   echo ""
   echo "/opt/oss/mtools/ne-integration/bin/NEaccount_generator.sh "
   echo ""
   echo "The conf file located in the:" 
   echo "/opt/oss/mtools/ne-integration/conf/NE_filter.conf"
   echo ""
   echo ""
   echo "------------------------------------------------------------------------"
}

function clean_tem_files()
{
rm -f ${CSV_FILE_DIR}/temp.sql
rm -f ${CSV_FILE_DIR}/temp_sql_result.csv
rm -f ${CSV_FILE_DIR}/temp_joint_conf_file.csv
rm -f ${CSV_FILE_DIR}/file1.conf
rm -f ${CSV_FILE_DIR}/file2.conf
rm -f ${CSV_FILE_DIR}/temp_split_service_types.csv
rm -f ${CSV_FILE_DIR}/temp_show_user_pwd_tip.csv
rm -f ${CSV_FILE_DIR}/temp_show_root_user_for_OMS.csv
rm -f ${CSV_FILE_DIR}/temp_no_user_tip_for_SNMP.csv
rm -f ${CSV_FILE_DIR}/temp_with_exist_credential.csv
rm -f ${CSV_FILE_DIR}/result.log
}

function generate_BSC_file()
{
  OMC_PWD=`polpasmx -omc`

  sqlplus -S omc/$OMC_PWD >"${CSV_FILE_DIR}/result.log" <<EOF
  col co_dn for a40
  select CO_DN from utp_common_objects where CO_OC_ID =3 AND CO_STATE != '9';
  exit
EOF
    perl << EOF
my \$in_ae_name=0;
my \$c_number;
my %c_number_tp_class_mapping;
my \$ouorapmx="$NTC_OSI_CONFIG_PATH/ouorapmx.cf";
open(IN,\$ouorapmx) or die "can't open file \$ouorapmx\n";
while(<IN>){
   my \$line=\$_;
   if(\$line=~/^\s*ae_name\s+BSC0*([1-9]\d*)\D*\$/)
   {
       \$in_ae_name=1;
       \$c_number=\$1;
   }
   if(\$line=~/^\s*end_aen\s+.*\$/){
       \$in_ae_name=0;
   }
   if(\$in_ae_name eq 1){
       if(\$line=~/^\s*transport_class\s+(\d)+\D*\$/){
          \$c_number_tp_class_mapping{\$c_number}=\$1;
       }
   }
}
close(IN);
my \$result="${CSV_FILE_DIR}/result.log";
open(RS_IN,\$result) or die "can't open \$result";
my \$out_file="$LOGFILE_BSC";
open(OUT,">",\$out_file) or die  "can't open \$out_file";
print OUT "BSC_FQDN,CM_XMLEVENTS_PROTOCOL\n";
while(<RS_IN>){
    my \$line=\$_;
    if(\$line=~/^PLMN-(.*)\/BSC-(0*[1-9]\d*)\D/){
        my \$plmn=\$1;
        my \$bsc=\$2;
        my \$tp_class=\$c_number_tp_class_mapping{\$bsc};
        if(\$tp_class eq 4){
            \$tp_class="FTAM";
        }
        else{
            \$tp_class="FTP";
        }
        print OUT "PLMN-\$plmn/BSC-\$bsc,\$tp_class\n";
    }
}
close(RS_IN);
close(OUT);
EOF
}


function split_service_types(){
while read line
do
	count_of_types=`echo $line | awk -F"|" '{print NF}'`
	head_string=`echo $line | awk -F"," '{for(k=1;k<NF;k++) {printf $k","}}'`
	servict_type_string=`echo $line | awk -F"," '{printf $NF}'`
	for (( i=1; i<count_of_types+1; i++ ))
	do
		echo $head_string`echo $servict_type_string | awk -F"|" '{print $NF}'` >>${CSV_FILE_DIR}/temp_split_service_types.csv
		servict_type_string=`echo $servict_type_string | awk -F"|" '{for(j=1;j<NF;j++) {if(j!=NF-1) {printf $j"|"}else{printf $j}}}'`
	done
done <${CSV_FILE_DIR}/temp_joint_conf_file.csv
}

function show_user_pwd_tip(){
while read line
do
	echo $line | awk -F"," '{for(i=1;i<=NF;i++) {if( i==6 ) {printf "#NE_USER#,"}else if( i==7 ){printf "#NE_PASSWORD#,"}else if( i==NF ){printf $NF"\n"}else{printf $i","}}}' >>${CSV_FILE_DIR}/temp_show_user_pwd_tip.csv
done <${CSV_FILE_DIR}/temp_split_service_types.csv
}

function handle_root_user_for_OMS(){
while read line
do
	NE_number=`echo $line | awk -F',' '{print $5}'`
	service_type=`echo $line | awk -F',' '{print $8}'`
	if [ "$NE_number" -eq 2347 ]
	then
		if [ `echo $service_type | grep -c '('` -eq 0 ]
		then
			echo $line | awk -F',' '{for(i=1;i<=NF;i++) {if(i==NF) {printf $NF"\n"}else if(i==6){printf "root,"}else{printf $i","}}}' >>${CSV_FILE_DIR}/temp_show_root_user_for_OMS.csv
		else
			echo $line >>${CSV_FILE_DIR}/temp_show_root_user_for_OMS.csv
		fi
	else
		echo $line >>${CSV_FILE_DIR}/temp_show_root_user_for_OMS.csv
	fi
done <${CSV_FILE_DIR}/temp_show_user_pwd_tip.csv
}

function handle_SNMP_Write_Access(){
while read line
do
	if [ `echo $line | grep -c "SNMP Write Access"` -gt 0 ] || [ `echo $line | grep -c "SNMP Read Access"` -gt 0 ]
	then
		echo $line | sed 's/#NE_USER#//' >>${CSV_FILE_DIR}/temp_no_user_tip_for_SNMP.csv
	else
		echo $line >>${CSV_FILE_DIR}/temp_no_user_tip_for_SNMP.csv
	fi
done <${CSV_FILE_DIR}/temp_show_root_user_for_OMS.csv
}

function fill_exist_user_and_pwd(){
flag=1
line_count=`cat ${CSV_FILE_DIR}/temp_no_user_tip_for_SNMP.csv|wc -l`
for ((i=1;i<=$line_count;i++))
do
line=`sed -n "${i}p" ${CSV_FILE_DIR}/temp_no_user_tip_for_SNMP.csv`
GID=`echo $line | awk -F',' '{print $1}'`
        SystemDN=`echo $line | awk -F',' '{print $2}'`
        CountBracket=`echo $line | grep -c '('`
        if [ $CountBracket -gt 0 ]
        then
                if [ "$flag" -eq 1 ]
                then
                echo -n "Begin to get exist credentials. Please wait."
                else
                echo -n "."
                fi
                ACCESS_TYPE=`echo $line | awk -F'(' '{print $2}' | awk -F')' '{print $1}'`
                address_of_core2=`ldapacmx.pl -pkgPrimaryNode osscore2`
                str=`ssh -q omc@${address_of_core2} /opt/oss/mtools/ne-integration/bin/sum_query.sh $GID $ACCESS_TYPE`
                NE_User=`echo $str | awk -F':' '{print $1}'`
                NE_Pwd=`echo $str | awk -F':' '{print $2}'`
                flag=`expr $flag + 1`
                if [[ "${NE_User}" == "" ]] || [[ "${NE_Pwd}" == "" ]]
                then
                        echo $line  >>${CSV_FILE_DIR}/temp_with_exist_credential.csv
                else
                        echo $line | sed "s/#NE_USER#/${NE_User}/" | sed "s/#NE_PASSWORD#/${NE_Pwd}/" >>${CSV_FILE_DIR}/temp_with_exist_credential.csv
                fi
        else
                echo $line >>${CSV_FILE_DIR}/temp_with_exist_credential.csv
        fi
done
}

function generate_final_template(){
#echo the title for the csv file
echo -e "OSS5x_DN","IP/DNS_Host","NE_user","NE_passwd","NEAC_Access_Type" >${CSV_TEMPLATE_DIR}/ne_accounts.csv
while read line
do
	if [ `echo $line | grep -c '('` -gt 0 ]
	then
		echo $line | cut -d '(' -f 1 | awk -F"," '{for(k=2;k<=NF;k++) {if(k==4) {printf ""}else if(k==5){printf ""}else if(k!=NF) {printf $k","}else{printf $NF"\n"}}}' >>${CSV_TEMPLATE_DIR}/ne_accounts.csv
	else
		echo $line | awk -F"," '{for(k=2;k<=NF;k++) {if(k==4) {printf ""}else if(k==5){printf ""}else if(k!=NF) {printf $k","}else{printf $NF"\n"}}}' >>${CSV_TEMPLATE_DIR}/ne_accounts.csv
	fi
done <${CSV_FILE_DIR}/temp_with_exist_credential.csv
}

function join_sql_result_and_conf_content(){
#delect the blank character in the temp csv file
sed -e 's/[ ]*$//g' ${CSV_FILE_DIR}/temp_sql_result.csv >${CSV_FILE_DIR}/temp_joint_conf_file.csv

#fill the NEAC Acess Type filed according to conf file
echo -e "` awk -F":" '{if( length($3)>0 ) print $0}' ${NE_FILTER_CONF}`" > ${CSV_FILE_DIR}/file1.conf
echo -e "` awk -F":" '{if( length($3)==0 ) print $0}' ${NE_FILTER_CONF}`" > ${CSV_FILE_DIR}/file2.conf

echo -e "` awk -F"[,:]" 'NR==FNR{a[$1$3]=$4}   NR>FNR{if($NF=="") {print $1","$2","$3","$4","$5","$6","$7","a[$5$4]}else{print $0}}' ${CSV_FILE_DIR}/file1.conf ${CSV_FILE_DIR}/temp_joint_conf_file.csv`" >${CSV_FILE_DIR}/temp_joint_conf_file.csv
echo -e "` awk -F"[,:]" 'NR==FNR{a[$1]=$4}   NR>FNR{if($NF=="") {print $1","$2","$3","$4","$5","$6","$7","a[$5]}else{print $0}}' ${CSV_FILE_DIR}/file2.conf ${CSV_FILE_DIR}/temp_joint_conf_file.csv`" >${CSV_FILE_DIR}/temp_joint_conf_file.csv
}

Generate_NE_account_template()
{	
        ERRORS=""
	echo "INFO:Connect the DB to get the NE information."
	   
        #check if ${CSV_FILE_DIR} is exist
        if [ ! -d ${CSV_FILE_DIR} ]; then
            mkdir -p ${CSV_FILE_DIR}
            echo "Create the ${CSV_FILE_DIR} in the script"
        fi
           #Check if ${CSV_TEMPLATE_DIR} is exist
           if [ ! -d ${CSV_TEMPLATE_DIR} ]; then
               mkdir -p ${CSV_TEMPLATE_DIR}
               echo "Create the ${CSV_TEMPLATE_DIR} in the script"
           fi
		   
		   #Check if ${LOGDIR} is exist
           if [ ! -d ${LOGDIR} ]; then
               mkdir -p ${LOGDIR}
               echo "Create the ${LOGDIR} in the script"
           fi

	   echo -e "set feedback off;
                 set echo off;
                 set term off;
                 set pagesize 0;
		set linesize 1000;
		set trimspool on;
                 spool ${CSV_FILE_DIR}/temp_sql_result.csv app;
                 column CO_DN||' heading 'DN';" > ${CSV_FILE_DIR}/temp.sql
       
	   
           # Read the information from conf file
	   while IFS=":" read co_id co_dn dn_release accesstype
           do
              if [ "${dn_release}" = "" ]; then
                 echo " SELECT CO_GID || ',' || CO_DN || ',' || CO_MAIN_HOST ||',' || CO_OCV_SYS_VERSION || ',' || CO_OC_ID ||',,,,' FROM UTP_COMMON_OBJECTS WHERE CO_OC_ID='${co_id}'and CO_STATE != '9' and CO_MAIN_HOST is not null;">>${CSV_FILE_DIR}/temp.sql
              else
                 echo " SELECT CO_GID || ',' || CO_DN || ',' || CO_MAIN_HOST ||',' || CO_OCV_SYS_VERSION || ',' || CO_OC_ID ||',,,,' FROM UTP_COMMON_OBJECTS WHERE CO_OCV_SYS_VERSION='${dn_release}' and CO_OC_ID='${co_id}' and CO_STATE != '9' and CO_MAIN_HOST is not null;">>${CSV_FILE_DIR}/temp.sql
              fi
                      
           done <${NE_FILTER_CONF}

           echo -e "spool off;
                    exit">>${CSV_FILE_DIR}/temp.sql
	   
           if [ -z "${DATABASE_USER}" ]; then
               ERRORS+="Variable DATABASE_USER is empty. "
           fi

           if [ -z "${DATABASE_PASSWORD}" ]; then
               ERRORS+="Variable DATABASE_PASSWORD is empty. "
           fi 
           if [ -z "${ERRORS}" ]; then
               #connect to the DB to get the NE information
               sqlplus -s ${DATABASE_USER}/${DATABASE_PASSWORD}>${LOGDIR}/Neaccount.log <${CSV_FILE_DIR}/temp.sql
               #Some log location information
              if [ -z `cat ${LOGDIR}/Neaccount.log|grep -i "error"` ]; then
               
		join_sql_result_and_conf_content
		split_service_types
		show_user_pwd_tip
		handle_root_user_for_OMS
		handle_SNMP_Write_Access
		fill_exist_user_and_pwd
		generate_final_template

               echo -e "\nCreated successfully!"
               echo "Please check the CSV template file located in ${CSV_TEMPLATE_DIR}/ne_accounts.csv."
             else
               ERRORS+="ERROR: DATABASE has errors Please check Neaccount.log located in ${LOGDIR}"
               echo ${ERRORS}
             fi
           else            
             echo "ERROR:There were errors: "${ERRORS}
           fi
                      
           generate_BSC_file
	   clean_tem_files
            exit 0
}

if [ `whoami` != "root" ];then
 echo "Please use root user to run the script!"
 exit 1
fi


if [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
   printHelp
   exit 0

fi

if [ "${1}" == "" ]; then   
   if [ ! -f "${NE_FILTER_CONF}" ];then
      echo "${NE_FILTER_CONF} does not exist,Please check it in the correct directory!"
      exit 1
   else
      Generate_NE_account_template "${NE_FILTER_CONF}"
      exit 0
   fi
fi

if [ "${1}" != "-h" ] || [ "${1}" != "--help" ] || [ "${1}" != "" ]; then
   echo ""
   echo "You gave wrong option! Please try again."
   echo ""
   printOptions
   exit 0
fi
