ZynqMP> printenv bootargs
bootargs=console=ttyPS1,115200 earlycon root=/dev/nfs rw nfsroot=192.168.2.10:/srv/nfs/shared/petalinux-nfs,vers=3,tcp ip=192.168.2.20:192.168.2.10:192.168.2.10:255.255.255.0::eth1:off
ZynqMP> printenv bootcmd
bootcmd=tftpboot 0x10000000 image.ub; bootm 0x10000000#conf-smk-k26-revA-sck-kr-g-revB
ZynqMP> printenv loadaddr
loadaddr=0x10000000
ZynqMP> printenv fdt_addr_r
fdt_addr_r=0x40000000ZynqMP> printenv bootargs
bootargs=console=ttyPS1,115200 earlycon root=/dev/nfs rw nfsroot=192.168.2.10:/srv/nfs/shared/petalinux-nfs,vers=3,tcp ip=192.168.2.20:192.168.2.10:192.168.2.10:255.255.255.0::eth1:off
ZynqMP> printenv bootcmd
bootcmd=tftpboot 0x10000000 image.ub; bootm 0x10000000#conf-smk-k26-revA-sck-kr-g-revB
ZynqMP> printenv loadaddr
loadaddr=0x10000000
ZynqMP> printenv fdt_addr_r
fdt_addr_r=0x40000000
