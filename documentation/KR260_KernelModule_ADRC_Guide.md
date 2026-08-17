# KR260 Kernel Module and ADRC Controller Deployment Guide

Companion document to `KR260_BootDocumenation.md`. Assumes the KR260 is already booting the AMD Ubuntu 24.04 image over TFTP/NFS as described in that document.

### Key Features:
- Cross-build out-of-tree Linux kernel modules on a Fedora host (no compilation on the KR260)
- Deploy modules directly into the NFS root filesystem
- Build and load a custom PL bitstream at runtime via `xmutil` / `dfx-mgr`
- Bind a custom platform driver to a PL peripheral via device tree overlay

### What is not covered:
- Vivado block design creation
- ADRC control theory or algorithm implementation
- PetaLinux kernel or rootfs builds *(deliberately — see the warning below)*

> [!CAUTION]
> **Do not run bare `petalinux-build` while your TFTP and NFS directories hold the working Ubuntu boot files.** PetaLinux produces its own `image.ub` containing a different kernel with different FIT configuration node names. Overwriting `/srv/tftp/image.ub` with it produces `could not find configuration` or `Wrong Image Type for bootm command` in U-Boot. PetaLinux is used in this guide **only** to generate a device tree fragment from the Vivado XSA.

> [!TIP]
> Before starting, make a pristine backup of your known-good boot image outside the TFTP root:
> ```bash
> sudo cp /srv/tftp/image.ub /srv/backup/image.ub.ubuntu-24.04.known-good
> ```
> Recovery from a clobbered TFTP directory then becomes a single `cp`.

## Table of contents
[TOC]

---

## Part 0: Environment variables used throughout

Set these on your Fedora host at the start of every session. Every command in this document references them.

```bash
export NFSROOT=/srv/nfs/shared/petalinux-nfs
export KVER=$(cat $NFSROOT/lib/modules/*/kernel/.. 2>/dev/null; ls $NFSROOT/lib/modules)
echo "Kernel version: $KVER"
```

If that produces more than one result, get the authoritative answer from the board itself over the serial console:

```bash
uname -r
```

You should see something of the form `6.8.0-XXXX-xilinx-zynqmp`. Set it explicitly:

```bash
export KVER=6.8.0-1017-xilinx-zynqmp    # replace with your actual value
```

> [!WARNING]
> This version string must match **exactly**. A module built against different kernel headers will fail to load with `Invalid module format`, and `dmesg` will report a version magic mismatch. This is the single most common failure in this entire workflow.

---

## Part 1: Setting up the build environment on Fedora

Two methods are given. **Method A is strongly recommended** and is what the rest of this document assumes.

### Method A: Native arm64 build in an emulated container *(recommended)*

This runs a real Ubuntu 24.04 arm64 userspace under QEMU emulation on your x86 Fedora host. The build is *native* from the kernel build system's perspective, so there is no cross-compilation toolchain skew and no host/target binary mismatches.

#### A.1 Install the emulation layer

```bash
sudo dnf install podman qemu-user-static
sudo systemctl restart systemd-binfmt
```

`qemu-user-static` on Fedora registers the arm64 binfmt handlers automatically. Verify:

```bash
ls /proc/sys/fs/binfmt_misc/ | grep aarch64
```

You should see `qemu-aarch64`.

> [!TIP]
> If you prefer Docker over Podman, substitute `docker` for `podman` in every command below. Register binfmt with:
> ```bash
> sudo docker run --privileged --rm tonistiigi/binfmt --install arm64
> ```

#### A.2 Create the working directory

```bash
mkdir -p ~/kr260/modules/hello
cd ~/kr260/modules
```

#### A.3 Launch the build container

```bash
podman run --rm -it \
  --platform linux/arm64 \
  -v ~/kr260/modules:/work:Z \
  ubuntu:24.04 bash
```

Inside the container, confirm you are actually on arm64:

```bash
uname -m        # must print: aarch64
```

> [!NOTE]
> The first launch will pull the arm64 image and may take a minute. Emulated builds are slower than native, but a hello-world module compiles in seconds regardless.

#### A.4 Install the toolchain and matching kernel headers *(inside the container)*

```bash
apt update
apt install -y build-essential kmod
apt install -y linux-headers-6.8.0-1017-xilinx-zynqmp   # use YOUR $KVER
```

Verify the headers landed:

```bash
ls /lib/modules/6.8.0-1017-xilinx-zynqmp/build
```

> [!TIP]
> If apt reports the package is unavailable, the exact version may have been superseded in the archive. Search for what is available:
> ```bash
> apt-cache search linux-headers | grep xilinx-zynqmp
> ```
> If your board's version is not listed, pull the `.deb` directly from the Ubuntu ports pool at `http://ports.ubuntu.com/ubuntu-ports/pool/main/l/linux-xilinx-zynqmp/`. You need **both** `linux-headers-<KVER>_arm64.deb` and the matching architecture-independent `linux-xilinx-zynqmp-headers-<version>_all.deb`. Install with `dpkg -i`.

> [!CAUTION]
> Do not "just use" a generic `linux-headers-generic` package. The Xilinx ZynqMP kernel has a different configuration, and the resulting module will not load.

### Method B: Cross-compile natively on Fedora *(fallback)*

Use this only if container emulation is unavailable.

```bash
sudo dnf install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu make bc flex bison openssl-devel elfutils-libelf-devel
```

Extract the Ubuntu arm64 headers packages into a working directory on the host:

```bash
mkdir -p ~/kr260/headers
cd ~/kr260/headers
dpkg-deb -x linux-headers-${KVER}_arm64.deb .
dpkg-deb -x linux-xilinx-zynqmp-headers-*_all.deb .
export KDIR=~/kr260/headers/usr/src/linux-headers-${KVER}
```

> [!CAUTION]
> **The Ubuntu headers package ships prebuilt host tools compiled for arm64.** On an x86_64 Fedora host, `make` will fail with `cannot execute binary file: Exec format error` when it tries to run `scripts/basic/fixdep`. You must rebuild those tools for x86_64 first:
> ```bash
> cd $KDIR
> make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- scripts
> ```
> This is the reason Method A is recommended — it sidesteps the problem entirely.

Every `make` in Part 2 then requires the extra arguments:

```bash
make -C $KDIR M=$PWD ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules
```

---

## Part 2: Hello-world kernel module

### 2.1 Write the source

Create `~/kr260/modules/hello/hello.c` on the **Fedora host** (the directory is bind-mounted into the container at `/work/hello`):

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>

static int __init hello_init(void)
{
	pr_info("hello: module loaded on KR260\n");
	return 0;
}

static void __exit hello_exit(void)
{
	pr_info("hello: module unloaded\n");
}

module_init(hello_init);
module_exit(hello_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Drew Currie");
MODULE_DESCRIPTION("Hello world kernel module for AMD KR260");
MODULE_VERSION("1.0");
```

### 2.2 Write the Makefile

Create `~/kr260/modules/hello/Makefile`:

```makefile
obj-m += hello.o

KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
```

> [!TIP]
> Tabs, not spaces, for the indented recipe lines. Make will report `missing separator` otherwise.

### 2.3 Build

Inside the arm64 container:

```bash
cd /work/hello
make
```

You should end up with `hello.ko`. Verify it targets the right kernel:

```bash
modinfo hello.ko | grep vermagic
```

The `vermagic` string must match your `$KVER`. If it does not, stop here and fix the headers before proceeding — nothing downstream will work.

Exit the container. The build artifacts persist in `~/kr260/modules/hello` on the host because of the bind mount.

### 2.4 Deploy to the NFS root filesystem

Because the KR260's root filesystem lives on your Fedora host, deployment is just a file copy. **The board does not need to be running for this step.**

```bash
sudo mkdir -p $NFSROOT/lib/modules/$KVER/extra
sudo cp ~/kr260/modules/hello/hello.ko $NFSROOT/lib/modules/$KVER/extra/
sudo depmod -b $NFSROOT $KVER
```

> [!NOTE]
> `depmod -b` operates on an alternate root, so you can regenerate `modules.dep` and `modules.alias` for the board's kernel from the host without any chroot or emulation. This becomes essential in Part 4.

### 2.5 Load and verify on the KR260

Over the serial console:

```bash
sudo modprobe hello
lsmod | grep hello
sudo dmesg | tail -5
```

You should see `hello: module loaded on KR260` in the kernel log.

```bash
sudo rmmod hello
sudo dmesg | tail -2
```

> [!TIP]
> `modprobe` works only after `depmod`. If you skipped it or want to test a module that is not yet installed, use the explicit path instead:
> ```bash
> sudo insmod /lib/modules/$(uname -r)/extra/hello.ko
> ```

### 2.6 Optional: load automatically at boot

```bash
echo hello | sudo tee /etc/modules-load.d/hello.conf
```

Or, equivalently, from the Fedora host:

```bash
echo hello | sudo tee $NFSROOT/etc/modules-load.d/hello.conf
```

---

## Part 3: ADRC controller — fabric (PL) side

### Understanding what happens at runtime

On the Kria K26, the boot firmware in QSPI is fixed and **the PL comes up completely unconfigured**. Unlike a classic ZynqMP flow, the bitstream is not part of `BOOT.BIN` and is not programmed by the FSBL. It is loaded from Linux userspace, on demand, after boot.

```
xmutil loadapp adrc
   └── dfx-mgrd (daemon)
        ├── writes bitstream via FPGA Manager
        │     /sys/class/fpga_manager/fpga0
        │     └── zynqmp-fpga driver → PMU firmware → PL configured
        └── applies the .dtbo overlay to the live device tree
              └── kernel instantiates the platform device
                    └── your driver's probe() is called
```

The consequence worth internalising: **the device tree overlay is what causes your driver to bind.** The bitstream alone gives you nothing the kernel can see.

### 3.1 Export hardware from Vivado

In your Vivado project, with the ADRC IP connected to the PS via an AXI4-Lite interface:

1. Generate the bitstream.
2. **File → Export → Export Hardware**, select **Include bitstream**.
3. Save as `design_1_wrapper.xsa`.

Note the base address Vivado assigned to your ADRC IP in the Address Editor — typically in the `0xA000_0000` range. You will see this reappear in the device tree.

### 3.2 Generate the device tree fragment

This is the **only** step in the entire workflow that uses PetaLinux, and it neither builds nor touches a kernel.

```bash
petalinux-create -t project --template zynqMP --name adrc_dt
cd adrc_dt
petalinux-config --get-hw-description=/path/to/design_1_wrapper.xsa --silentconfig
```

The generated fragment appears at:

```
components/plnx_workspace/device-tree/device-tree/pl.dtsi
```

Inspect it. You are looking for a node describing your IP:

```dts
adrc_controller_0: adrc_controller@a0000000 {
	compatible = "xlnx,adrc-controller-1.0";
	reg = <0x0 0xa0000000 0x0 0x10000>;
	clock-names = "s_axi_aclk";
	clocks = <&zynqmp_clk 71>;
	interrupt-parent = <&gic>;
	interrupts = <0 89 4>;
};
```

> [!CAUTION]
> **Write down the `compatible` string exactly as it appears.** It is derived from your IP's VLNV in Vivado. Part 4's driver must match it character for character. A mismatch causes no error message of any kind — `probe()` simply never runs.

> [!TIP]
> If you would rather not install PetaLinux at all, `xsct` with the `device-tree-xlnx` repository produces the same `pl.dtsi` and is a far lighter dependency.

### 3.3 Build the device tree overlay

The overlay needs two fragments: one telling the FPGA region which bitstream to program, and one adding your peripheral nodes to the AXI bus.

Create `adrc-overlay.dts`:

```dts
/dts-v1/;
/plugin/;

/ {
	fragment@0 {
		target = <&fpga_full>;
		__overlay__ {
			#address-cells = <2>;
			#size-cells = <2>;
			firmware-name = "adrc.bit.bin";
		};
	};

	fragment@1 {
		target = <&amba>;
		__overlay__ {
			#address-cells = <2>;
			#size-cells = <2>;

			adrc_controller_0: adrc_controller@a0000000 {
				compatible = "xlnx,adrc-controller-1.0";
				reg = <0x0 0xa0000000 0x0 0x10000>;
				clock-names = "s_axi_aclk";
				clocks = <&zynqmp_clk 71>;
				interrupt-parent = <&gic>;
				interrupts = <0 89 4>;
			};
		};
	};
};
```

Paste your actual node from `pl.dtsi` into `fragment@1`. Compile it:

```bash
sudo dnf install dtc
dtc -@ -I dts -O dtb -o adrc.dtbo adrc-overlay.dts
```

> [!WARNING]
> The `-@` flag is mandatory. It emits the `__symbols__` node the overlay machinery needs to resolve `&fpga_full`, `&amba`, `&gic`, and `&zynqmp_clk` against the running device tree. Without it the overlay will be rejected at load time.

### 3.4 Convert the bitstream to `.bin`

The FPGA Manager expects raw configuration data with the `.bit` header stripped. Create `adrc.bif`:

```
all:
{
	[destination_device = pl] design_1_wrapper.bit
}
```

Then:

```bash
bootgen -image adrc.bif -arch zynqmp -process_bitstream bin -o adrc.bit.bin -w
```

> [!TIP]
> `bootgen` ships with Vivado/Vitis. Source the settings script first if it is not on your `PATH`:
> ```bash
> source /tools/Xilinx/Vivado/2025.1/settings64.sh
> ```

### 3.5 Write `shell.json`

```json
{
	"shell_type": "XRT_FLAT",
	"num_slots": "1",
	"dtbo_filename": "adrc.dtbo",
	"bitstream_filename": "adrc.bit.bin"
}
```

`XRT_FLAT` is correct for a flat (non-DFX, non-partial-reconfiguration) design, which is what you want here.

### 3.6 Deploy the firmware to the NFS root

```bash
sudo mkdir -p $NFSROOT/lib/firmware/xilinx/adrc
sudo cp adrc.bit.bin adrc.dtbo shell.json $NFSROOT/lib/firmware/xilinx/adrc/
sudo chown -R root:root $NFSROOT/lib/firmware/xilinx/adrc
```

> [!CAUTION]
> **`dfx-mgrd` discovers new applications using inotify, and inotify does not propagate over NFS.** Files you copy from the Fedora host are invisible to the daemon on the board until you force a rescan. This produces a confusing failure where the files are plainly present in `ls` but `xmutil loadapp` reports the application does not exist.
>
> Force a rescan on the board with `sudo xmutil listapps`. If that is not enough:
> ```bash
> sudo systemctl restart dfx-mgrd
> ```

### 3.7 Smoke-test the bitstream alone

Before involving overlays or drivers, confirm the `.bin` conversion is valid. On the board:

```bash
sudo fpgautil -b /lib/firmware/xilinx/adrc/adrc.bit.bin
cat /sys/class/fpga_manager/fpga0/state
```

The state should read `operating`. If this fails, the problem is in Step 3.4 and there is no point debugging anything downstream.

---

## Part 4: ADRC controller — kernel module side

### 4.1 Write the platform driver

Your ADRC module must be a **platform driver** whose match table contains the `compatible` string from Step 3.2. Create `~/kr260/modules/adrc/adrccontroller.c`:

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/io.h>

/* AXI4-Lite register map - adjust to match your IP */
#define ADRC_REG_CTRL		0x00
#define ADRC_REG_STATUS		0x04
#define ADRC_REG_SETPOINT	0x08
#define ADRC_REG_FEEDBACK	0x0C

struct adrc_dev {
	struct device	*dev;
	void __iomem	*base;
};

static int adrc_probe(struct platform_device *pdev)
{
	struct adrc_dev *adrc;
	u32 status;

	adrc = devm_kzalloc(&pdev->dev, sizeof(*adrc), GFP_KERNEL);
	if (!adrc)
		return -ENOMEM;

	adrc->dev = &pdev->dev;

	adrc->base = devm_platform_ioremap_resource(pdev, 0);
	if (IS_ERR(adrc->base))
		return dev_err_probe(&pdev->dev, PTR_ERR(adrc->base),
				     "failed to map registers\n");

	platform_set_drvdata(pdev, adrc);

	status = readl(adrc->base + ADRC_REG_STATUS);
	dev_info(&pdev->dev, "ADRC controller probed, status = 0x%08x\n", status);

	return 0;
}

static void adrc_remove(struct platform_device *pdev)
{
	struct adrc_dev *adrc = platform_get_drvdata(pdev);

	/* Halt the controller before the overlay is torn down */
	writel(0, adrc->base + ADRC_REG_CTRL);
	dev_info(&pdev->dev, "ADRC controller removed\n");
}

static const struct of_device_id adrc_of_match[] = {
	{ .compatible = "xlnx,adrc-controller-1.0" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, adrc_of_match);

static struct platform_driver adrc_driver = {
	.driver = {
		.name		= "adrccontroller",
		.of_match_table	= adrc_of_match,
	},
	.probe	= adrc_probe,
	.remove	= adrc_remove,
};

module_platform_driver(adrc_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Drew Currie");
MODULE_DESCRIPTION("ADRC controller driver for KR260 PL");
```

> [!NOTE]
> On kernel 6.11 and later `.remove` returns `void`. On 6.8 (Ubuntu 24.04) it may still expect `int` — if you get a prototype mismatch warning, change the signature to `static int adrc_remove(...)` and `return 0;`.

> [!CAUTION]
> `MODULE_DEVICE_TABLE(of, ...)` is what writes the compatible string into `modules.alias`. **Omitting it means the kernel will never auto-load your driver** when the overlay creates the device. You would have to `insmod` manually every time.

### 4.2 Makefile

```makefile
obj-m += adrccontroller.o

KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
```

### 4.3 Build and install

Same container, same procedure as Part 2:

```bash
podman run --rm -it --platform linux/arm64 -v ~/kr260/modules:/work:Z ubuntu:24.04 bash
# inside:
cd /work/adrc && make && exit
```

```bash
sudo cp ~/kr260/modules/adrc/adrccontroller.ko $NFSROOT/lib/modules/$KVER/extra/
sudo depmod -b $NFSROOT $KVER
```

Confirm the alias was registered:

```bash
grep adrc $NFSROOT/lib/modules/$KVER/modules.alias
```

You should see a line mapping `of:N*T*Cxlnx,adrc-controller-1.0*` to `adrccontroller`. **If this line is absent, the driver will not auto-bind.**

---

## Part 5: Bringing it all up, in order

Order matters here. Doing these steps out of sequence is the most common source of silent failures.

### 5.1 On the KR260, after a clean boot

```bash
# 1. Confirm the module is installed and the alias is registered
modinfo adrccontroller | head -3

# 2. Force dfx-mgrd to rescan the NFS-mounted firmware tree
sudo xmutil listapps

# 3. Clear any previously loaded PL application
sudo xmutil unloadapp

# 4. Load the ADRC application (programs PL + applies overlay)
sudo xmutil loadapp adrc
```

### 5.2 Verify, layer by layer

```bash
# The PL was actually configured
cat /sys/class/fpga_manager/fpga0/state          # expect: operating

# The overlay created the platform device
ls /sys/bus/platform/devices/ | grep adrc        # expect: a0000000.adrc_controller

# The driver bound to that device
ls /sys/bus/platform/drivers/adrccontroller/     # expect a symlink to the device

# The module actually loaded
lsmod | grep adrccontroller

# probe() ran
sudo dmesg | grep -i adrc
```

You are looking for `ADRC controller probed, status = 0x...` in the kernel log.

### 5.3 Tear down

```bash
sudo xmutil unloadapp
```

This removes the overlay, which triggers your `remove()` and unbinds the driver. Verify with `dmesg` that your cleanup path ran.

> [!TIP]
> Your iteration loop after this point is short: rebuild in the container, `cp` the `.ko` into `$NFSROOT`, then on the board `xmutil unloadapp && xmutil loadapp adrc`. Because the rootfs lives on your host's disk, there is no file transfer step at all.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `insmod: Invalid module format` | Module built against wrong kernel headers | Compare `modinfo hello.ko \| grep vermagic` against `uname -r` on the board |
| `cannot execute binary file` during `make` | Method B on x86 host; arm64 host tools in headers package | Run `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- scripts` in `$KDIR`, or switch to Method A |
| `modprobe: module not found` | `depmod` not run after copying `.ko` | `sudo depmod -b $NFSROOT $KVER` |
| `xmutil loadapp` says app does not exist, but files are present | inotify does not work over NFS | `sudo xmutil listapps`, then `sudo systemctl restart dfx-mgrd` |
| Overlay load fails with unresolved phandle errors | `.dtbo` compiled without `-@` | Recompile with `dtc -@ ...` |
| `fpga0/state` is not `operating` | Bad `.bit.bin` conversion | Re-run bootgen; test standalone with `fpgautil -b` |
| Device appears in `/sys/bus/platform/devices` but driver never binds, no error message | `compatible` string mismatch between overlay and `of_match_table` | Diff them character by character; check `modules.alias` contains the entry |
| Board hangs silently at end of kernel boot | `update-misc-config.sh` patch missing from rootfs | Re-apply the NFS-root MAC patch from `KR260_BootDocumenation.md` |
| U-Boot: `could not find configuration` / `Wrong Image Type` | `/srv/tftp/image.ub` overwritten by a PetaLinux build | Restore from your known-good backup; verify with `dumpimage -l` |

---

## Alternative: userspace access via generic-UIO

If the ADRC controller turns out to be mostly register reads and writes, `uio_pdrv_genirq` lets you drive the PL from userspace through `/dev/uioN` with no kernel module at all. Add `compatible = "generic-uio", "xlnx,adrc-controller-1.0";` to the overlay node and pass `uio_pdrv_genirq.of_id=generic-uio` on the kernel command line.

Trade-offs: substantially faster to iterate on and debug, but you lose deterministic interrupt latency and take a syscall penalty on every register access. Whether that matters depends entirely on your ADRC loop rate. It is worth prototyping in UIO first and moving into the kernel only once the algorithm is settled.

---

## Quick reference

```bash
# --- Host setup (once per session) ---
export NFSROOT=/srv/nfs/shared/petalinux-nfs
export KVER=6.8.0-1017-xilinx-zynqmp

# --- Build ---
podman run --rm -it --platform linux/arm64 -v ~/kr260/modules:/work:Z ubuntu:24.04 bash
#   inside: apt update && apt install -y build-essential linux-headers-$KVER
#   inside: cd /work/<module> && make

# --- Deploy module ---
sudo cp <module>.ko $NFSROOT/lib/modules/$KVER/extra/
sudo depmod -b $NFSROOT $KVER

# --- Deploy PL firmware ---
sudo mkdir -p $NFSROOT/lib/firmware/xilinx/adrc
sudo cp adrc.bit.bin adrc.dtbo shell.json $NFSROOT/lib/firmware/xilinx/adrc/

# --- On the board ---
sudo xmutil listapps
sudo xmutil unloadapp
sudo xmutil loadapp adrc
sudo dmesg | grep -i adrc
```
