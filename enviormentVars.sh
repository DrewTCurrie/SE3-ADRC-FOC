#!/bin/bash

# Adding project root as an export for easy navigation
export PROOT=/opt/Xilinx/Projects/SE3-ADRC-FOC/
echo -e "Set Project Root as $PROOT"
echo -e "\n"
# NFS root and Kernel build enviornment variables
export NFSROOT=/srv/nfs/shared/petalinux-nfs
export KVER=$(cat $NFSROOT/lib/modules/*/kernel/.. 2>/dev/null; ls $NFSROOT/lib/modules)
echo -e "Enviornment variables set:"
echo -e "\t NFSROOT=$NFSROOT"
echo -e "\t Target Kernel verison: $KVER"
