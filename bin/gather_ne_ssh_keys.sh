#!/bin/bash

# ATTENTION: modify part at the end only! Rest is mtools internal.

# mtools autoexec import script template
# file name guideline: <ss>_autoexec_import_<phase>_<order>.sh
#    <phase> can be cri for CRItical data, com for COMplementary and opt for OPTional
#    <order> is based on the import order specification, see cookbook.
# this template shall be used by components and functional areas
# to develop all mtools related scripted execution.
 
# source common mtools functionality and variables
source /opt/oss/mtools/lib/mig_functions.sh

conf_file=${DEFAULT_CONF_FILE}
func_area=$(basename $0 | cut -d_ -f1)

# component specific variables queried from system
# add if needed
mtools_dir=${MTOOLS_BASEDIR}
 
function usage()
{
# edit if needed
cat <<EOF
 
Usage: $0 <--conffile|--datadir|--help>
 
Options:
        --conffile
          Seed a configuration file holding variable values to the script.
          Optional parameter, default: ${DEFAULT_CONF_FILE}

        --datadir
          Directory where exported or filtered data is stoeed
          Optional parameter, default: ${IMPORT_DIR}/${func_area}
          func_area is derived from the first part of this
          script name separated by underscore

        --help
          Prints this help message
EOF
}
 
 
#########################
## Common housekeeping ##
#########################
 
mig_note "START: $(basename $0) execution starts."
parse_cmd_line TEMPLATE $@

if defined TEMPLATE_help; then
  usage
  exit 0
fi
 
# If conf file is specified then default mtools.conf DEFAULT_CONF_FILE is not used
defined TEMPLATE_conffile && [ -n "$TEMPLATE_conffile" ] && conf_file=$TEMPLATE_conffile
if [ ! -e $conf_file ]
  then
    mig_fail "The file $conf_file does not exist"
  else
    source $conf_file
fi

# Now that mtools.conf file is sourced, several system level
# variables are available to use. Eg: ${EXPORT_DIR}.
# See template mtools.conf in <mtools SVN repo>/mtools/src/framework/template/mtools.conf.template
# for other available variables
 
defined TEMPLATE_datadir && [ -n "$TEMPLATE_datadir" ] && datadir=$TEMPLATE_datadir/${func_area} || datadir=${IMPORT_DIR}/${func_area}
[ ! -d "$datadir" ] && mig_execute2 "mkdir -p $datadir"

# add if needed
# more handling of optional command lines params can be added if absolutely needed
# mig_info, mig_debug, mig_warning, mig_error messages will go to ${COMMON_LOGDIR}/migration.log

# mig_detailed messages will go to detailed_logfile
# if following two lines are commented, then default detailed log is used ${DETAILED_LOGDIR}/migration_detailed.log
detailed_logfile="${DETAILED_LOGDIR}/$(basename $0 .sh).log"
mig_set_detailed_logfile "${detailed_logfile}"
 

############
## Export ##
############

mig_info "Executing ${func_area} specific export steps"

#################################################################
# This script is a wrapper script that will gather NE ssh keys and store it to the mediations
# specific repositories so that mediations can use it for SSH connection towards NE.
##################################################################
SSH_KEY_BIN=/opt/oss/mtools/ne-integration/bin/ssh_key_generate.sh
NWI3_MOS="OMS,RNC,IADA"
NWI3_SSH_MOS="MSC,MGW,CDS,HLR,FING,FLEXINS,OMGW,SGSN,BCUBTS"
NX2SMOS="FLEXINS,MGW,MSC,CDS,HLR,RNC"
SCLIMOS="FING,OMGW,MCTC,IADA,RNC"
Q3MOS="BSC,SGSN,FLEXINS,MGW,MSC,CDS,HLR,RNC"
COMMEDNES="FLEXINS"
XOHMOS="MSC,HLR,CDS"

NWI3_KNOWN_HOSTS="/d/oss/global/certificate/smx/nwi3/known_hosts"
NWI3_SSH_KNOWN_HOSTS="/etc/opt/nokia/oss/common/conf/ssh_known_hosts"
SCLI_KNOWN_HOSTS="/d/oss/global/certificate/smx/nx2s/scli_known_hosts"
NX2S_KNOWN_HOSTS="/d/oss/global/certificate/smx/nx2s/mml_known_hosts"
Q3_KNOWN_HOSTS="/d/oss/global/certificate/smx/q3user/known_hosts"
COMMEDNES_KNOWN_HOSTS="/d/oss/global/certificate/smx/common_mediations/known_hosts"
XOH_KNOWN_HOSTS="/d/oss/global/certificate/smx/xoh/known_hosts"
NWI3_USER="nwi3:sysop"
SCLI_USER="nx2suser:sysop"
NX2S_USER="nx2suser:sysop"
Q3_USER="q3usr:sysop"
COMM_USER="esbadmin:sysop"
XOH_USER="xohuser:sysop"
PERMISSION="600"
PERMISSIONCM="640"

nwi3hostname=$(/opt/cpf/bin/smanager.pl status service "nwi3" | grep 'nwi3:' | head -1 |cut -d ':' -f 2)
nx2shostname=$(/opt/cpf/bin/smanager.pl status service "nx2s" | grep 'nx2s:' | head -1 | cut -d ':' -f 2)
q3userhostname=$(/opt/cpf/bin/smanager.pl status service "q3user" | grep 'q3user:' | head -1| cut -d ':' -f 2)
co_mehostname=$(/opt/cpf/bin/smanager.pl status service "common_mediations" | head -1 | cut -d ':' -f 2)
xohhostname=$(/opt/cpf/bin/smanager.pl status service "xoh" | grep 'xoh:' | head -1 | cut -d ':' -f 2)

#################################################################
mig_info "Started gathering sshkeys for $NWI3_MOS"	
ssh -q "${nwi3hostname}" "sh $SSH_KEY_BIN $NWI3_MOS $NWI3_KNOWN_HOSTS"  
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $NWI3_MOS "
	exit 1
fi
# Handle permissions
ssh -q "${nwi3hostname}" "chmod $PERMISSION $NWI3_KNOWN_HOSTS"
ssh -q "${nwi3hostname}" "chown $NWI3_USER $NWI3_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $NWI3_MOS"	
#################################################################
mig_info "Started gathering sshkeys for $NWI3_SSH_MOS"	
ssh -q "${nwi3hostname}" "sh $SSH_KEY_BIN $NWI3_SSH_MOS $NWI3_SSH_KNOWN_HOSTS"  
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $NWI3_SSH_MOS "
	exit 1
fi
# Handle permissions
ssh -q "${nwi3hostname}" "chmod $PERMISSIONCM $NWI3_SSH_KNOWN_HOSTS"
ssh -q "${nwi3hostname}" "chown $NWI3_USER $NWI3_SSH_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $NWI3_SSH_MOS"	
#################################################################
mig_info "Started gathering sshkeys for $NX2SMOS"
ssh -q "${nx2shostname}" "sh $SSH_KEY_BIN $NX2SMOS $NX2S_KNOWN_HOSTS" 
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $NX2SMOS "
	exit 1
fi
# Handle permissions
ssh -q "${nx2shostname}" "chmod $PERMISSION $NX2S_KNOWN_HOSTS"
ssh -q "${nx2shostname}" "chown $NX2S_USER $NX2S_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $NX2SMOS"
#################################################################
mig_info "Started gathering sshkeys for $SCLIMOS"
ssh -q "${nx2shostname}" "sh $SSH_KEY_BIN $SCLIMOS $SCLI_KNOWN_HOSTS"  
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $SCLIMOS "
	exit 1
fi
# Handle permissions
ssh -q "${nx2shostname}" "chmod $PERMISSIONCM $SCLI_KNOWN_HOSTS"
ssh -q "${nx2shostname}" "chown $SCLI_USER $SCLI_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $SCLIMOS"
#################################################################
mig_info "Started gathering sshkeys for $Q3MOS"
ssh -q "${q3userhostname}" "sh $SSH_KEY_BIN $Q3MOS $Q3_KNOWN_HOSTS"  
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $Q3MOS "
	exit 1
fi
# Handle permissions
ssh -q "${q3userhostname}" "chmod $PERMISSION $Q3_KNOWN_HOSTS"
ssh -q "${q3userhostname}" "chown $Q3_USER $Q3_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $Q3MOS"
#################################################################
mig_info "Started gathering sshkeys for $COMMEDNES"
ssh -q "${co_mehostname}" "sh $SSH_KEY_BIN $COMMEDNES $COMMEDNES_KNOWN_HOSTS"  
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $COMMEDNES "
	exit 1
fi
# Handle permissions
ssh -q "${co_mehostname}" "chmod $PERMISSION $COMMEDNES_KNOWN_HOSTS"
ssh -q "${co_mehostname}" "chown $COMM_USER $COMMEDNES_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $COMMEDNES"
#################################################################
mig_info "Started gathering sshkeys for $XOHMOS"
ssh -q "${xohhostname}" "sh $SSH_KEY_BIN $XOHMOS $XOH_KNOWN_HOSTS"  
# Handle return code
if [ $? -ne 0 ]
then
	mig_info "Failed to gather sshkeys for $XOHMOS "
	exit 1
fi
# Handle permissions
ssh -q "${xohhostname}" "chmod $PERMISSION $XOH_KNOWN_HOSTS"
ssh -q "${xohhostname}" "chown $XOH_USER $XOH_KNOWN_HOSTS"
mig_info "End gathering sshkeys for $XOHMOS"

