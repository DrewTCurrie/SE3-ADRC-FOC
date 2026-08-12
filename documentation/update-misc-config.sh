#!/bin/bash

function Get_MAC_ID(){

	local output=""
	local index=$1
	if [ $index -eq 0 ]; then
		output="$(ipmi-fru --fru-file=/sys/bus/i2c/devices/1-0050/eeprom --interpret-oem-data | grep 'MAC ID 0:' | awk -F': ' '{print $2}')"
	else
		output="$(ipmi-fru --fru-file=/sys/bus/i2c/devices/1-0051/eeprom --interpret-oem-data | grep "MAC ID $index:" | awk -F': ' '{print $2}')"
	fi
	echo $output
}

function Get_Active_Ethernet(){

	local output=""
	local num=$1
	output=$(ls /sys/class/net | grep eth$num)

	if [ -z "$output" ]; then
		echo "No Ethernet Port Found"
		exit 1
	else
		line=${output:0:4}
		echo "$line"
	fi
}

function Update_MAC_Address(){
 #Do not modify the ethernet connection used for NSF booting
 #This causes issues with boot fails in a silent way during hand-off to user space
 #Added check for if NFS boot - Drew
 local rootdev=""
 if grep -qs ' / nfs' /proc/mounts; then
   local nfsserver=$(awk '$2=="/" && $3 ~ /^nfs/ {split*$1,a,":"); print a[1]}' /proc/mounts)
   rootdev=$(ip route get "$nfsserver" 2>/dev/null | grep -o 'dev [^]*' | cut -d' ' -f2)
   echo "NFS root detected on $rootdev - skipping MAC update on this interface"
 fi
 #End custom section

	i=$(ls -ld /sys/class/net/eth* | wc -l)
	while [ $i -gt 0 ]; do
		i=$(( i - 1 ))
		local eth=$(Get_Active_Ethernet $i)
    #Added additional check for NFS root
    ["eth" = "rootdev"] && { echo "Skipping $eth (NFS root)"; continue }
		local MAC_ID=$(Get_MAC_ID $i)
		/sbin/ifconfig $eth down
		/sbin/ifconfig $eth hw ether $MAC_ID
        # comment out interface bring up which causes
        # conflict with NetworkManager
		# /sbin/ifconfig $eth up
		local MAC_addr=$(cat /sys/class/net/$eth/address)
    #Added more verbose printing
    echo "MAC address for $eth is updated to $(cat /sys/class/net/$eth/address)"
	done
}


