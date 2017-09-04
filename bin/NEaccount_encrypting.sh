#!/bin/bash
#function: encrypting the password of NE accounts with base64
#author: lihua.1.zhang.ext@nsn.com

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

#define the variable
csv_temple_file="/opt/oss/mtools/data/ne-integration/conf/ne_accounts.csv"
csv_temple_file_backup="/opt/oss/mtools/data/ne-integration/conf/ne_accounts_backup.csv"
final_file_after_encrypting="/opt/oss/mtools/data/ne-integration/conf/ne_accounts.csv"
temp_file="/opt/oss/mtools/data/ne-integration/conf/temp_file_for_encrypt"
log_file='/var/opt/oss/log/mtools/NEaccount_encrypting.log'

#remove the log file
if [ -f $log_file ]
then
    rm -f $log_file
fi

#check if original NE accounts file exists. If it does not exist, give error info and exit. Else back up the file.
if [ ! -f $csv_temple_file ]
then
    echo "Error: $csv_temple_file does not exist!"
    echo `date` ":Error: $csv_temple_file does not exist!" >>$log_file
    exit 0
else
    #back up the original NE accounts file
    echo `date` 'Info: Begin to back up the original NE accounts file from ne_accounts.csv to ne_accounts_backup.csv' >>$log_file
    mv -f $csv_temple_file $csv_temple_file_backup
    echo `date` 'Info: Back up the original NE accounts file successfully' >>$log_file
fi

#check if final_file_after_encrypting exist.
if [ -f $final_file_after_encrypting ]
then
    rm -f $final_file_after_encrypting
fi

#encrypt
echo "Begin to encrypt the NE account file. Please check ${log_file} for more information if error occurs."
i=0
index=0 # used for warning info array
while read line_info
do
	if [ $i -eq 0 ]
	then
		echo `date` "====================================================" >>$log_file
	        echo `date` "Info: handle first line" >>$log_file
        	echo $line_info >> $final_file_after_encrypting
		echo `date` "Info: handle first line successfully" >>$log_file
	else
		echo `date` "=====================================================" >>$log_file
        	#echo `date` "Info: handle this line: $line_info" >>$log_file
		
		#remove temp file
		if [ -f $temp_file ]
		then
			echo `date` "Info: remove temp file" >>$log_file
    			rm -f $temp_file
		fi
        
        	echo $line_info >> $temp_file
        
        	head_string=`echo $line_info| awk -F '"' '{printf $1}'`
        	#echo `date` "Info: head string is: $head_string" >>$log_file
        
        	tail_string=`echo $line_info| awk -F '"' '{printf $NF}'`
        	#echo `date` "Info: tail string is: $tail_string" >>$log_file
        
        	string_length=`echo ${#line_info}`
        	echo `date` "Info: string length is: $string_length" >>$log_file
        
        	head_string_length=`echo ${#head_string}`
        	echo `date` "Info: head string length is: $head_string_length" >>$log_file
        
		if [ $string_length -ne $head_string_length ]
		then
            		echo `date` "Info: There is comma or double quote in password" >>$log_file
            
            		tail_string_length=`echo ${#tail_string}`
            		echo `date` "Info: tail string length is: $tail_string_length" >>$log_file
            
            		middle_string_length=`expr $string_length - $head_string_length - $tail_string_length`
            		echo `date` "Info: middle string length is: $middle_string_length" >>$log_file
            
            		middle_string=`echo ${line_info:$head_string_length:$middle_string_length}`
            		#echo `date` "Info: middle string is: $middle_string" >>$log_file
            
            		middle_string_length_without_head_and_tail_quote=`expr $middle_string_length - 2`
            		echo `date` "Info: middle string length without quote is: $middle_string_length_without_head_and_tail_quote" >>$log_file
            
            		temp_string_without_head_and_tail_quote=`echo ${middle_string:1:$middle_string_length_without_head_and_tail_quote}`
            		#echo `date` "Info: middle string without quote is: $temp_string_without_head_and_tail_quote" >>$log_file
            
            		original_pwd=`echo ${temp_string_without_head_and_tail_quote//\"\"/\"}`
            		#echo `date` "Info: original password is: $original_pwd" >>$log_file
            
            		pwd_after_encrypting=`printf $original_pwd | base64`
            		echo `date` "Info: password after encrypting is: $pwd_after_encrypting" >>$log_file
            
            		printf $head_string >>$final_file_after_encrypting
            		printf $pwd_after_encrypting >>$final_file_after_encrypting
            		echo $tail_string >>$final_file_after_encrypting
            
            		#echo `date` "Info: ${line_info} has been handled successfully" >>$log_file
		else
            		echo `date` "Info: There is NO comma or double quote in password" >>$log_file
            
            		while IFS="," read f1 f2 f3 f4 f5
			do
				if [ -z "$f4" ]
				then
					echo `date` "Info: original password is null" >>$log_file
					pwd_after_encrypting=''				
				else
					original_pwd=$f4
                			#echo `date` "Info: original password is: $original_pwd" >>$log_file
                			pwd_after_encrypting=`printf $original_pwd | base64`
                		fi
				printf "$f1,$f2,$f3," >>$final_file_after_encrypting
				printf "$pwd_after_encrypting," >>$final_file_after_encrypting
				echo $f5 >>$final_file_after_encrypting
			done <$temp_file
            
            		#echo `date` "Info: ${line_info} has been handled successfully" >>$log_file
		fi
	fi
let i=$i+1
done <$csv_temple_file_backup

echo `date` "======================================================" >>$log_file
echo `date` "Info: NE accounts file has been encrypted successfully" >>$log_file

#remove temp file
echo `date` "Info: ===========clear=================================" >>$log_file
echo `date` "Info: remove temp file" >>$log_file
rm -f $temp_file

#prompt before removing the back up NE accounts file
echo `date` "Info: remove the back up file" >>$log_file
rm -i $csv_temple_file_backup

echo "==================Summary============================" >>$log_file
for (( j=0; j<index; j++ ))
do
echo "${WarningInfo[j]}" >>$log_file
done
echo "Encrypting is successful" >>$log_file

echo 'Encrypting is successful'
