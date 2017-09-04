#!/bin/bash
#description: This script is used to check connection for NEs which in ne_accounts.csv

if [ -f /opt/oss/mtools/lib/mig_functions.sh ]
then
	source /opt/oss/mtools/lib/mig_functions.sh
fi


csv_file=$1

if [ ! -z "$csv_file" ]
then
	csv_source_file=$csv_file
else
	csv_source_file="/opt/oss/mtools/data/ne-integration/conf/ne_accounts.csv"
fi

if [ ! -f $csv_source_file ]
then
	echo "ne accounts file is not found!"
	exit 1
fi

temp_file="/var/opt/oss/log/mtools/ne-integration/temp_file_for_checking_conn"
failed_file="/var/opt/oss/log/mtools/ne-integration/connect_failed_NEs.csv"
log_file="/var/opt/oss/log/mtools/ne-integration/check_ne_conn.log"

BINFILE=/opt/oss/mtools/ne-integration/bin/ne_connection_validate.sh

#remove the log file
if [ -f $log_file ]
then
    rm -f $log_file
fi

#remove failed file
if [ -f $failed_file ]
then
    rm -f $failed_file
fi


getPassword(){
	line_info=$1
	head_string=`echo $line_info| awk -F '"' '{printf $1}'`
	tail_string=`echo $line_info| awk -F '"' '{printf $NF}'`    
	string_length=`echo ${#line_info}`
	head_string_length=`echo ${#head_string}`
    	
	if [ $string_length -ne $head_string_length ]
		then
    		echo `date` "Info: There is comma or double quote in password" >>$log_file
    		tail_string_length=`echo ${#tail_string}`
    		#echo `date` "Info: tail string length is: $tail_string_length" >>$log_file
    		
    		middle_string_length=`expr $string_length - $head_string_length - $tail_string_length`
    		#echo `date` "Info: middle string length is: $middle_string_length" >>$log_file
    
    		middle_string=`echo ${line_info:$head_string_length:$middle_string_length}`
    		#echo `date` "Info: middle string is: $middle_string" >>$log_file
    
    		middle_string_length_without_head_and_tail_quote=`expr $middle_string_length - 2`
    		#echo `date` "Info: middle string length without quote is: $middle_string_length_without_head_and_tail_quote" >>$log_file
    
    		temp_string_without_head_and_tail_quote=`echo ${middle_string:1:$middle_string_length_without_head_and_tail_quote}`
    		#echo `date` "Info: middle string without quote is: $temp_string_without_head_and_tail_quote" >>$log_file
    
    		original_pwd=`echo ${temp_string_without_head_and_tail_quote//\"\"/\"}`
	
	else
		original_pwd=`echo $line_info| awk -F ',' '{printf $4}'`	
	fi	
	
	echo $original_pwd

}



#Begin to verify
echo "Begin to verify NE connection. Please check ${log_file} for more information."
i=0
while read line_info
do

	if [ $i -eq 0 ]
	then
		echo `date` "====================================================" >>$log_file
	    echo `date` "Info: handle first line" >>$log_file
		echo `date` "Info: handle first line successfully" >>$log_file
	else
		echo `date` "=====================================================" >>$log_file
    	
    	ne_pwd=`getPassword "$line_info"`
    	ne_fqdn=`echo $line_info| awk -F ',' '{printf $1}'`
		ne_host=`echo $line_info| awk -F ',' '{printf $2}'`
		ne_user=`echo $line_info| awk -F ',' '{printf $3}'`
		ne_access_type=`echo $line_info| awk -F ',' '{printf $NF}'`
		
		echo "Begin to verify $ne_fqdn. Line number: $i"
		
		if [ `echo $line_info|grep -i OMS | grep root| grep -i ssh|wc -l` -eq 1 ]
		then
			ne_access_type="ignored"
		fi
		
		if [ `echo $ne_access_type | grep -i ssh |wc -l` -eq 1 ]
		then
			if [ `echo $line_info | grep -i oms | grep -i ssh | grep -v root| wc -l` -eq 1 ]
			then
				
				oms_root_line=`grep -i oms $csv_source_file | grep -i root | grep $ne_host`
				if [ ! -n "$root_line" ]
				then
					oms_root_password=`getPassword $oms_root_line`
					$BINFILE $ne_host "$ne_user" "$ne_pwd" 3 "$oms_root_password"  > /dev/null
				else
					$BINFILE $ne_host "$ne_user" "$ne_pwd" 1  > /dev/null
				fi
			else
				$BINFILE $ne_host "$ne_user" "$ne_pwd" 1  > /dev/null
			fi
			
			result_status=$?
			
			if [ $result_status -eq 0 ]
			then
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect successfully" >>$log_file
			elif [ $result_status -eq 3 ]
			then
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect failed" >>$log_file
				echo ${line_info} >>$failed_file
				echo `date` "Info: ${oms_root_line}" >>$log_file
				echo `date` "Result: connection failed and the password of root is not verified" >>$log_file
				echo ${oms_root_line} >>$failed_file
			elif [ $result_status -eq 4 ]
			then
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect successfully" >>$log_file
				echo `date` "Info: ${oms_root_line}" >>$log_file
				echo `date` "Result: connection failed with root password" >>$log_file
				echo ${oms_root_line} >>$failed_file
			elif [ $result_status -eq 5 ]
			then
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect successfully" >>$log_file
				echo `date` "Info: ${oms_root_line}" >>$log_file
				echo `date` "Result: connection successfully with root password" >>$log_file
			else
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect failed" >>$log_file
				echo ${line_info} >>$failed_file
			fi		
		elif [ `echo $ne_access_type | grep -i 'mml\|telnet' |wc -l` -eq 1 ]
		then
			$BINFILE $ne_host "$ne_user" "$ne_pwd" 2  > /dev/null
			if [ $? -eq 0 ]
			then
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect successfully" >>$log_file
			else
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result:connect failed" >>$log_file
				echo ${line_info}>>$failed_file
			fi		
		elif [ `echo $ne_access_type | grep -i snmp |wc -l` -eq 1 ]
		then
			get_result=`snmpget -v2c -c "$ne_pwd" $ne_host .1.3.6.1.2.1.1.3.0`
			if [ `echo $get_result| grep -i Timeticks | wc -l` -eq 1 ]
			then
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result: connect successfully" >>$log_file
			else
				echo `date` "Info: ${line_info}" >>$log_file
				echo `date` "Result:connect failed" >>$log_file
				echo ${line_info}  >>$failed_file
			fi		  
		elif [ "$ne_access_type" = "ignored" ]
    	then
    			echo `date` "Info: ${line_info}" >>$log_file
    			echo `date` "Result: Verification of this object is will verified with common user, please find the log for this line with root account" >>$log_file
    	else
    		 	echo `date` "Info: ${line_info}" >>$log_file
    		 	echo `date` "Result: This object is not verified because access type doesn't belongs to SNMP,SSH,TELNET,MML" >>$log_file	  		
		 fi
	fi

echo `date` "Info: The line number: $i">>$log_file
    	
let i=$i+1
done<$csv_source_file


echo `date` "Info: =================================================" >>$log_file
echo `date` "Info: NE validation is finished" >>$log_file

echo "For more details, please get log from $log_file"
echo "Please get the failed NE list from: $failed_file"
