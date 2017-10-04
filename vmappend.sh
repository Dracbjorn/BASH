#!/bin/bash

# Author: Kent Graves
# This script is used to append content to the end of a file.
# During the deployment of a non-persistent VM.

#-------- GLOBALS

# Print debug output to $logfile for testing. 0 = no logging; 1 = logging
debug=1 

# Detect errors. 0 = no errors; 1 = error
error=0

# Destination of debug output if $debug -eq 1; make sure this is a sane location pls                 
logfile="/tmp/debug.log"

# File to update
file='/etc/unbound/local.d/tmnkernels.lab.conf'


# Updates appended to file
content=(					
    'local-data-ptr: "172.17.0.160 admin1.tmnkernels.lab."'
    'local-data-ptr: "172.17.0.253 core-rtr.tmnkernels.lab."'
    'local-data-ptr: "219.13.189.1 core-rtr.tmnkernels.lab."'
    'local-data-ptr: "219.13.189.173 www.linuxtools.net."'
)

#-------- FUNCTIONS

bugLog(){
	msg="$1"
	[ $debug -gt 0 ] &&	echo "$(date +%F\ %H:%M:%S) $msg" | tee -a ${logfile}
}

append(){
     msg="$1"
     echo "$msg" | tee -a $file 2>> $logfile
     [ $? -ne 0 ] && chkerr
}

chkerr(){
	bugLog "ERROR: Error encountered"
    exit 1
}

updateFile(){
	bugLog "[*] Attempting to update ${file} ..."
    
	count=0
	while [ $count -le ${#content[@]} ]; do
		append "${content[${count}]}"
        (( count++ ))
	done
    bugLog "[*] Finished updating ${file}"
}

customActions(){
	bugLog "[*] Stopping dnsmasq service"
	systemctl stop dnsmasq 2>> $logfile
    [ $? -ne 0 ] && chkerr

    bugLog "[*] Disabling dnsmasq service"
    systemctl disable dnsmasq 2>> $logfile
    [ $? -ne 0 ] && chkerr

    bugLog "[*] Masking dnsmasq service"
    systemctl mask dnsmasq 2>> $logfile
    [ $? -ne 0 ] && chkerr

	bugLog "[*] Restarting unbound service"
	systemctl restart unbound 2>> $logfile
    [ $? -ne 0 ] && chkerr
}

#-------- START SCRIPT

updateFile
customActions

#If script reaches this line it was successful
bugLog "[*] Updates were successful."

#remove script from system
#[ $debug -eq 0 ] && /bin/rm -f $0
