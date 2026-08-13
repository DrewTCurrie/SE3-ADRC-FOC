# Information on booting the KR260 
This documentation serves to help boot a new KR260 SOM with the Robotics Starter Kit Carrier Board. 
Written by Drew Currie 08/12/2026

### Key Features:
- Boot AMD KR260 on Robotics Start Kit Carrier Board *(Referred to as the KR260 in this document)*
- Use Ubuntu 24.04 LTS as the main Linux flavor
- Boot using NFS and TFTP from a host Fedora computer

### What is not covered:
- Setting up PetaLinux 
- Setting up Vivado 
- Setting up Docker
- Ubuntu host computer support

## Table of contents


## General Boot Procedure
The general boot procedure used in this documentation is using the AMD provided base Ubuntu 24.04 LTS server image. This image can be found on Ubuntu's official page specifically for the AMD KR260 [linked here](https://ubuntu.com/download/amd#kria-k26). 

This image is compiled with the intent to be flashed to the micro-SD card and inserted into the KR260 carrier board. However, this documentation will forego that in place of using an NFS and TFTP boot model.

### Preparing the boot environment 
Once the image has downloaded the NFS and TFTP servers need to be created on the host computer to enable booting the KR260. 

Packages to install:
``` bash
dnf install tftp nfs-utils
```

This will bring the basic TFTP and NFS server packages. To make both of these work, there is extensive configuration of the firewall along with configuration of each server. 

1. Configure the directories
    Create the following directory structure:
    > [!TIP]
    > These directories will need to be created as root or with sudo

    ``` bash    
        /srv
        ├──tftp
        └──nfs
        └──shared
            └──petalinux-nfs
    ```
    Once the directories are created permissions for each will need to be changed. 

    > [!TIP]
    > These commands will need to be run as root or with sudo

    ``` bash
    chown -R nobody:nobody /srv/tftp
    chown -R nobody:nobody /srv/nfs/shared
    ```

2. Configuring the Fedora firewall
Fedora provides a base firewall package named ```firewalld```. Additional documentation can be [found here](https://firewalld.org/). 

    > [!WARNING]
    > Modifications to the system firewall can expose the computer to potential risks. Only execute these commands if you understand what they are doing and why they are being executed. 


    ```bash
    firewall-cmd --permanent --add-service nfs
    firewall-cmd --permanent --add-service tftp
    firewall-cmd --reload
    ```

    To confirm the services have been added and are working run:
    ```bash
    firewall-cmd --list-services
    ```

    > [!TIP]
    > The commands below are only for NFSv3. This documentation is written with the expectation that NFSv3 is being used. This is due to legacy configuration from previous Graduate Students. The KR260 supports NFSv4. 

    ```bash
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --reload
    ```

    To confirm the services have been added and are working run:
    ```bash
    firewall-cmd --list-services
    ```
3. Configure network:
Network configuration must be done in a manual manner to create the proper boot structure for the KR260. *These network values are hardcoded and should be followed directly. Small typos can lead to hours of debugging* The directions are assuming you are using an Ethernet connection between the devices. Configure the host ethernet network adapter with the configuration in the table below. 

Configuration Scheme:

| Category | Host Configuration | KR260 Configuration |
| --- | --- | --- |
| IP Address | 192.168.2.10/24 | 192.168.2.20 |
| Subnet | 255.255.255.0 | 255.255.255.0 |
| Default Gateway | 192.168.2.10 | 192.168.2.10 |
| DNS Server | 1.1.1.1 | 1.1.1.1|

4. **TODO**: Update to include NFS server configuration specific tasks

5. Configure host computer for UART communication
The KR260 can be configured (And is configured by default) to provide a UART communication protocol at boot. Minicom is the preferred option to accessing this UART terminal through the host computer. Alternatives like PicoCom and Screen are available and left to personal preference. This documentation will assume use of Minicom.

> [!TIP]
> Minicom will need to be run as root or sudo unless you change the permissions on the selected ttyUSB interface. 

To connect to the KR260 UART port, you need to determine which port in ```/dev/``` it is bound to. Once that has been determined replaced the '*' in the command with the appropriate number. 

```bash
minicom -D /dev/ttyUSB*
```

Once in Minicom, you will want to enable line wrapping, this will be very useful for long commands later. To do so follow the directions below:
1. Press ctrl+a then z
2. A menu will appear, in the menu press "w" to enable the "Wrapping" option

> [!NOTE]
> During Minicom use at this point you may not see any text. That is expected behavior as the KR260 is not booting or outputting any data on the UART lines. 

### Setting up for first boot
Once the NFS and TFTP servers have been installed and configured, it is now time to modify the Ubuntu image to be booted via TFTP and NFS. 
> [!WARNING]
> The pathing and commands to achieve this are important to get correct. These will be referenced by U-Boot, PetaLinux, and Ubuntu. Failure to get these correct now will cause problems at boot time. 

#### Modifying the downloaded image 


#### Modifying the update-misc-config.sh
The update-misc-config.sh script is a part of the custom D-Bus system on the KR260. This is an AMD KR260 specific script that needs to be modified for the KR260 to boot over TFTP and NFS. This is largely because the default AMD Ubuntu 24.04 LTS image expects to be booted via the micro-SD card. The key thing to be changed on this file is changing the way hardware MAC addresses are handled. Normal operation has all Ethernet ports down and without a MAC address. Then the user-space network manager protocol loads and assigns a new MAC address and will redo the network handshake. However, given that this involves first disconnecting from all connected Ethernet devices and then restarting them this breaks the root file-system as NFS booting requires a constant connection to the NFS Server to run programs from the root file-system. As such, when executed as originally shipped, the user-space network manager is never able to start as the CPU cannot find that program in system RAM or on the root file-system. 

This script can be modified from the Fedora host computer via Vim. 

> [!TIP]
> This must be edited as root or with sudo. This file "belongs to root" as the UID is set for root so booting works correctly on the KR260. 

``` bash 
vim /srv/nfs/shared/petalinux-nfs/usr/bin/update-misc-config.sh
```

Then replace the existing script with the following script:

``` diff
#!/bin/bash

function Get_MAC_ID(){

	local output=""
	local index=$1
	if [ $index -eq 0 ]; then
+		output="$(ipmi-fru --fru-file=/sys/bus/i2c/devices/1-0050/eeprom --interpret-oem-data | grep 'MAC ID 0:' | awk -F': ' '{print $2}')"
+	else
+		output="$(ipmi-fru --fru-file=/sys/bus/i2c/devices/1-0051/eeprom --interpret-oem-data | grep "MAC ID $index:" | awk -F': ' '{print $2}')"
+	fi
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
+ #Do not modify the ethernet connection used for NFS booting
+ #This causes issues with boot fails in a silent way during hand-off to user space
+ #Added check for if NFS boot - Drew
+ local rootdev=""
+ if grep -qs ' / nfs' /proc/mounts; then
+   local nfsserver=$(awk '$2=="/" && $3 ~ /^nfs/ {split($1,a,":"); print a[1]}' /proc/mounts)
+   rootdev=$(ip route get "$nfsserver" 2>/dev/null | grep -o 'dev [^]*' | cut -d' ' -f2)
+   echo "NFS root detected on $rootdev - skipping MAC update on this interface"
+ fi
+ #End custom section

	i=$(ls -ld /sys/class/net/eth* | wc -l)
	while [ $i -gt 0 ]; do
		i=$(( i - 1 ))
		local eth=$(Get_Active_Ethernet $i)
+    #Added additional check for NFS root
+    [ "$eth" = "$rootdev" ] && { echo "Skipping $eth (NFS root)"; continue; }
		local MAC_ID=$(Get_MAC_ID $i)
		/sbin/ifconfig $eth down
		/sbin/ifconfig $eth hw ether $MAC_ID
        # comment out interface bring up which causes
        # conflict with NetworkManager
		# /sbin/ifconfig $eth up
		local MAC_addr=$(cat /sys/class/net/$eth/address)
+    #Added more verbose printing
+    echo "MAC address for $eth is updated to $(cat /sys/class/net/$eth/address)"
	done
}
```

>[!CAUTION]
> The above script is **critical** missing this step will cause the boot to freeze as soon as Kernel boot ends and User-Space is supposed to take over. This will produce no errors, no logs, and no messages about the failure. 

### Modifying Boot parameters on the KR260
The KR260 has U-Boot built-in to help handle booting the device. Extensive documentation has been published by AMD [here](https://xilinx.github.io/kria-apps-docs/bootfw/build/html/docs/bootfw_uboot_handoff.html) and U-Boot is incredibly well documented [here](https://docs.u-boot-project.org/en/latest/).

U-Boot provides a powerful system for handling booting operating systems across many devices. The basic functionality is to serve to boot-strap the device and operating system. 

>[!TIP]
> U-Boot will be interfaced with using the UART connection to the computer. Boot parameters must be entered correctly or errors will result. 

To enter U-Boot configuration, connect a micro-USB cable from the KR260 to the host computer, open the minicom serial terminal and then plug the KR260 into power. 

You should see lots of text scrolling by as the KR260 begins to boot. Press any key (Press repeatedly and rapidly during initialization) to interrupt the default boot command. 

This should bring you to a console where a prompt resembling the prompt below is visible:

```bash
ZynqMP> 
```

This is the U-Boot prompt for the KR260 board. From here we will use a variety of basic commands to configure how the board will boot and test network connections. 

>[!TIP]
> Use ```saveenv``` to save the environment variables to the micro-SD card. Do this often to avoid losing work after boot or restarts. 

>[!TIP]
> Instead of power-cycling the KR260 by removing power and reconnecting to power, use the ```reset``` command to restart the device from the U-Boot menu. This will not work when recovering from Kernel Panics or boot failures. 

#### Key Environment Variables
Set the following environment variables to ensure proper booting:
```c
ZynqMP> setenv ipaddr 192.168.2.20
ZynqMP> setenv serverip 192.168.2.10
ZynqMP> setenv loadaddr 0x10000000
ZynqMP> setenv fdt_addr_r 0x40000000
ZynqMP> saveenv
ZynqMP> tftpboot image.ub
```

Assuming all prior networking was done correctly and the TFTP server is running, U-Boot should have just pulled the Linux Kernel as part of the ```tftpboot image.ub``` command. 

>[!CAUTION]
> The AMD documentation for the Ethernet port naming (aliasing) convention, U-Boot, and Linux all disagree on which port of Eth0 and which is Eth1. **The top right port** should be used. This is Eth1 in U-Boot and Eth0 in AMD's documentation and the Linux Kernel. This can be a cause of failure to boot. If you see messages about ```... PHY Auto-negotiation failed ...``` **stop** and check your network configuration settings on the host computer and the physical connection of the Ethernet cable.

After confirming the image was pulled successfully, the next step is to update the boot parameters the kernel will use to boot properly on the KR260 board.

After confirming the image was pulled successfully, the next step is to update the boot parameters the kernel will use to boot properly on the KR260 board. These boot parameters must match was is configured in PetaLinux during the creation process of all PetaLinux projects that use this physical and network setup. 

``` bash
ZynqMP> setenv bootargs console=ttyPS1,115200 earlycon root=/dev/nfs rw nfsroot=192.168.2.10:/srv/nfs/shared/petalinux-nfs,vers=3,tcp ip=192.168.2.20:192.168.2.10:192.168.2.10:255.255.255.0::eth1:off
```

**Important things to note in this configuration:**
1.**console:** 
- This is the UART console. This must be configured to ttyPS1 to prevent issues when the Kernel boot finishes and passes communication to Systemd. Without this, the UART console will close and it will appear as the Kernel has hung when in reality is is just no longer outputing information. 

2.**earlycon:** 
- This allows for logging before the serial drivers have been loaded. This is very useful for debugging low-level hardware interaction issues and Kernel boot information. 

3.**root=/dev/nfs rw nfsroot=.....:** 
- This is what sets the path for the root file-system to be on the NFS Server hosted on the host system. These parameters must match exactly what was configured earlier. 

4.**ip=....:** 
- These are the IP Configurations from the previous table. Importantly eth1 is off to avoid issues with Ethernet aliases between U-Boot and the Linux Kernel. 

```bash
setenv bootcmd tftpboot ${loadaddr} image.ub; bootm ${loadaddr}#conf-smk-k26-revA-sck-kr-g-revB
saveenv
run bootcmd
```

This sets the boot command that will be executed by U-Boot when the board is powered on. This is important to get exactly correct with the memory addresses or the Kernel will not boot due to not fitting in memory. Additionally the ```#conf....``` is **critically important**. More information below. 

1. **tftpboot ${loadaddr} image.ub:** 
- This brings the Linux Kernel down over TFTP from the host and stores it \${loadaddr} address in RAM. The address for \${loadaddr} can be seen with ```printenv loadaddr```. This address can be found on [AMD's source code for U-Boot](https://github.com/Xilinx/u-boot-xlnx/blob/master/include/configs/xilinx_zynqmp.h)

2. **```bootm ${loadaddr}#conf-smk-kr26-revA-sck-kr-g-revB```:**
- This boots the OS image loaded at ${loadaddr}. In this case that is the Linux Kernel. The critical part is the configuration offset: 
    - smk-k26-revA: System-on-Module (the top chip module, Revision A).

    - sck-kr-g-revB: Starter Kit Carrier Board (the baseboard with ports, Revision B).

 - Without specifying this configuration offset into the Kernel provided by AMD, the wrong configuration will be loaded. The configuration that includes **no** IO will be loaded. This will result in various errors related to IO, ranging form Ethernet to UART to SPI, etc. This offset is different for each individual board. These should be checked with the U-Boot "Detected Name" on first power on. 

 **TODO:** Get text of first power on and highlight the relevant line. 

## Post boot checks
**TODO:** Add post boot Linux commands to check everything is up and running correctly. 