#!/bin/sh

# This script for encode or decode using base64.
# Useage: ./Password_encode_decode.pl [encode|decode] strings 

if [ ! $# -eq 2 ] ; then

	echo "Useage: ./Password_encode_decode.pl [encode|decode] strings."
	exit 1;
fi

if [ $1 = "encode" ] ; then
	#echo "-----------------------------encode-------------------------------"
	str=`echo -n $2 | base64`
	echo $str

elif [ $1 = "decode" ] ; then
	#echo "-----------------------------decode-------------------------------"
	str=`echo -n $2 | base64 -d`
	echo $str
fi

