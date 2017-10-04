#!/bin/bash

# Author: Kent Graves
# This script is used to append content to the end of a file.

#-------- GLOBALS

# Print debug output to $logfile for testing. 1 = basic output; 2 = basic + shell env
debug=2    

# Destination of debug output if $debug -eq 1; make sure this is a sane location pls                 
logfile="/tmp/debug.log"

# File to update
file='/etc/unbound/local.d/tmnkernels.com.conf'


# Updates appended to file
content=(					
'local-data-ptr: "172.17.0.160 admin1.tmnkernels.lab"'
'local-data-ptr: "172.17.0.253 core-rtr.tmnkernels.lab"'
'local-data-ptr: "219.13.189.1 core-rtr.tmnkernels.lab"'
)

#-------- FUNCTIONS

bugLog{
	msg=$1
	[ $debug -gt 0 ] &&	/bin/echo "$msg" >> $logfile
}

append{
	msg=$1
	file=$2
	/bin/echo "$msg" >> $file
}

chkerr{
	[ $1 -ne 0 ] && log "ERROR: Error encountered"; exit 1
}

updateFile{
	bugLog "[*] Attempting to update ${file} ..."
	count=0
	for line in ${content[*]}; do
		(( count++ ))
		append $line $file
		chkerr $?
	done
	
	bugLog "[*] New update to ${file} :"
	for line in $(/bin/tail -n $count $file); do
		bugLog "$line"
	done
}

customActions{
	bugLog "[*] Stopping dnsmasq service"
	systemctl stop dnsmasq
	chkerr $?
	bugLog "[*] Restarting unbound service"
	systemctl restart unbound
	chkerr $?
}

#-------- START SCRIPT

updateFile
customActions

#If script reaches this line it was successful
bugLog "[*] Updates were successful."

#remove script from system
[ $debug -eq 0 ] && /bin/rm -f $0