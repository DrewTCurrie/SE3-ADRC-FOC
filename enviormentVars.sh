#!/bin/bash

export NFSROOT=/srv/nfs/shared/petalinux-nfs
export KVER=$(cat $NFSROOT/lib/modules/*/kernel/.. 2>/dev/null; ls $NFSROOT/lib/modules)
echo -e "Enviornment variables set:"
echo -e "\t NFSROOT=$NFSROOT"
echo -e "\t Board Kernel version: $KVER"
