# SE3-ADRC-FOC

**Active Disturbance Rejection Control (ADRC) for Field-Oriented Control (FOC) of a stepper motor, on AMD/Xilinx Kria KR260**

Graduate research project, **SE3 Research Lab, Montana State University**.

| Role | Name |
|---|---|
| Principal Investigator | Dr. David Miller |
| Project Advisor | Dr. Michael Edens |
| Primary Contributors | Caleb Binfet, Timothy (Drew) Currie |

---

## Project Goal

Drive a two-phase stepper motor continuously under **Field Oriented Control**,
rather than in conventional open-loop step mode, so that the motor's own
current control loop can be used as a sensing element during CNC machining
operations (mill and lathe work). The primary target is **linear force
sensing through current control** — inferring cutting load from the current
required to hold commanded position — with additional sensing modalities
anticipated as the platform matures.

Running the motor as a synchronous AC machine under FOC gives smooth,
continuous torque production and makes the q-axis current a usable proxy for
applied load. An outer ADRC (Active Disturbance Rejection Control) loop
provides disturbance rejection so that cutting forces appear as an estimable
disturbance term rather than as uncorrected position error, all implemented
in the FPGA fabric of the KR260 for hard real-time control.

### Relationship to prior work

This project is the graduate-level continuation of an undergraduate research
project also conducted at Montana State University: **[FAMP — Force-Aware
Manufacturing Processes](https://github.com/Direxfire/FAMP)** (see
`README-Example.md` in this repo for that project's own README, kept here as
a reference). The undergraduate work established the case for FOC-based force
feedback on small CNC machines (e.g. the Pocket NC) using software/MCU-based
current control (see the related
[StepperMotorFOC](https://github.com/Direxfire/StepperMotorFOC),
[CPID](https://github.com/Direxfire/CPID), and
[SSPID](https://github.com/Direxfire/SSPID) repositories). This project moves
that control loop into FPGA fabric on a Kria KR260, using an
HDL-Coder-generated ADRC controller wrapped in a custom AXI4-Lite peripheral,
to get the loop rates and determinism needed for a production-viable
implementation.

---

## Target Hardware

| Item | Value |
|---|---|
| Board | AMD/Xilinx Kria KR260 Robotics Starter Kit |
| Device | `xck26-sfvc784-2LV-c` (K26 SOM) |
| Vivado / Vitis | 2025.2 |
| Embedded Linux | PetaLinux (Yocto-based), `zynqmp-generic` machine |
| Custom IP | `adrc_axi_ctrl` v1.0 — AXI4-Lite slave, 32-bit data |

---

## Repository Layout

```
SE3-ADRC-FOC/
├── create_project.tcl        # Regenerates the Vivado project + block design from scratch
├── src/
│   ├── constraints/           # XDC constraints (bd/ holds block-design-scoped constraints)
│   └── hdl/
│       └── adrc_axi_ctrl_1_0/ # Custom AXI4-Lite IP: the ADRC/FOC controller
│           ├── hdl/           # VHDL sources (HDL Coder export of the Simulink model + AXI wrapper)
│           ├── drivers/       # Bare-metal driver (Vitis) for the IP's register map
│           ├── xgui/          # Vivado IP packager customization GUI definition
│           └── product_guide.md  # Deep-dive: register map, fixed-point formats, bring-up, known limitations
├── vivado_project/            # Generated Vivado project lives here (gitignored contents)
├── petalinux-docker/          # Dockerized PetaLinux build environment
│   ├── Dockerfile             # Ubuntu 22.04 image with PetaLinux build dependencies
│   ├── docker-compose.yml     # Bind-mounts workspace/, petalinux-install/, and the sstate/downloads cache
│   ├── launchPetaLinux.sh     # Convenience script to drop into the build container
│   ├── petalinux-cache/       # Local sstate-cache / downloads mirror, reused across container runs
│   └── workspace/
│       └── KR260_ADRC/        # The actual PetaLinux project (BSP config, meta-user layer, hw-description)
└── petalinux-install/         # Mount point for the installed PetaLinux SDK/tools (see setup below)
```

The most detailed technical documentation — register map, fixed-point
formats, bring-up procedure, and a running list of known limitations — lives
in
[`src/hdl/adrc_axi_ctrl_1_0/product_guide.md`](src/hdl/adrc_axi_ctrl_1_0/product_guide.md).
**Read that file before making changes to the controller IP.**

---

## Getting Started

This section is written for someone setting this project up for the first
time — e.g. a new lab member picking up the project.

### Prerequisites

- **Vivado / Vitis 2025.2** with support for the Kria KR260 board files
  (`xilinx.com:kr260_som:part0:1.1`). Install via the AMD/Xilinx Unified
  Installer; make sure the Kria SOM board definitions are enabled during
  install (or added afterward under `board_files`).
- **Docker** (with `docker compose`), for the PetaLinux build environment.
  PetaLinux itself only builds reliably on Linux, so the Docker image handles
  that regardless of your host OS.
- **AMD/Xilinx PetaLinux tools installer**, downloaded separately from the
  [AMD/Xilinx downloads page](https://www.xilinx.com/support/download.html)
  (requires accepting the Xilinx EULA, so it isn't checked into this repo).
- A KR260 Robotics Starter Kit for hardware bring-up, plus a way to write the
  SD card image (e.g. `dd`, balenaEtcher).

### 1. Clone the repository

```sh
git clone https://github.com/DrewTCurrie/SE3-ADRC-FOC-.git
cd SE3-ADRC-FOC-
```

### 2. Build the Vivado project

The Vivado project itself is **not** checked into the repo (see
`vivado_project/` and `.gitignore`) — it's regenerated from
`create_project.tcl`, which builds the block design, instantiates the custom
`adrc_axi_ctrl` IP, and wires it to the KR260 base platform.

```sh
cd vivado_project
vivado -mode batch -source ../create_project.tcl
```

Or, from the Vivado GUI Tcl console (`cd` to `vivado_project/` first so the
generated project lands there):

```tcl
source ../create_project.tcl
```

The custom IP at `src/hdl/adrc_axi_ctrl_1_0/` needs to be visible as an IP
repository — if it isn't picked up automatically, add it under **Project
Settings → IP → Repository** and point it at `src/hdl/`.

Once the project is open, connect and validate the block design, generate
the bitstream, and export the hardware (**File → Export → Export Hardware**,
include bitstream) to produce the `.xsa` used by PetaLinux in the next step.

### 3. Build the PetaLinux image (Docker)

The PetaLinux build toolchain is heavy and Linux-only, so it's wrapped in
Docker:

```sh
cd petalinux-docker
docker build -t petalinux-builder:22.04 .
```

Install the actual PetaLinux SDK into `petalinux-install/` at the repo root —
that directory is bind-mounted into the container at `/home/builder/petalinux`
so the installed toolchain persists across container runs instead of being
re-installed every time. Run the AMD/Xilinx PetaLinux installer against that
path (either on the host, or from inside a throwaway container using this
same Docker image).

Then drop into the build environment:

```sh
./launchPetaLinux.sh
```

This runs `docker compose run --rm petalinux-builder bash`, which mounts:

| Host path | Container path | Purpose |
|---|---|---|
| `petalinux-docker/workspace/` | `/home/builder/workspace` | The PetaLinux project (`KR260_ADRC/`) |
| `petalinux-install/` | `/home/builder/petalinux` | Installed PetaLinux SDK/tools |
| `petalinux-docker/petalinux-cache/downloads` | `/home/builder/downloads` | Yocto downloads cache |
| `petalinux-docker/petalinux-cache/sstate` | `/home/builder/sstate` | Yocto sstate-cache (speeds up rebuilds) |

Inside the container, source the PetaLinux settings script, `cd` into
`workspace/KR260_ADRC`, update the hardware description with the `.xsa`
exported from Vivado (`petalinux-config --get-hw-description=<path-to-xsa>`),
and build:

```sh
source /home/builder/petalinux/settings.sh
cd workspace/KR260_ADRC
petalinux-config --get-hw-description=<path to exported .xsa>
petalinux-build
```

### 4. Deploy to the KR260

The KR260 uses the Kria **accelerated-application** model rather than baking
the bitstream into `BOOT.BIN`. After building, place the bitstream, device
tree overlay, and shell manifest in `/lib/firmware/xilinx/<app-name>/` on the
target and load at runtime:

```sh
xmutil loadapp <app-name>
```

See the *Programming Sequence* section of
[`product_guide.md`](src/hdl/adrc_axi_ctrl_1_0/product_guide.md) for how to
bring up and exercise the `adrc_axi_ctrl` register interface once the PL
image is loaded (including a `devmem`-based smoke test that validates the
PS↔PL path before any motor is connected).

---

## Project Status

| Item | Status |
|---|---|
| AXI4-Lite register interface (`adrc_axi_ctrl`) | Complete |
| ADRC/FOC control subsystem integration (HDL Coder export) | Complete |
| First-boot PS↔PL integration test | In progress |
| Sample-rate enable generator (fixes `clk_enable` — see limitations) | Planned |
| Quadrature encoder interface block (dual output) | Planned |
| ADC interface block | Planned |
| SVPWM modulator / gate drive | Planned |
| Fixed-point and gain validation against physical hardware | Planned |
| Force estimation from q-axis current | Research objective |

The controller currently runs against **synthetic feedback** written over
AXI rather than a live ADC/encoder — see *Known Limitations* in the product
guide for what's stubbed out and why (notably: `clk_enable` is not yet a true
sample-rate pulse, so the discretized gains from the Simulink model won't
behave as simulated until that's fixed).

---

## Contributing / Handoff Notes

If you're picking this project up new:

1. Start with this README for the big picture, then read
   [`product_guide.md`](src/hdl/adrc_axi_ctrl_1_0/product_guide.md) end to
   end — it documents the register map, fixed-point formats, and every known
   issue in detail, including recommended fixes.
2. The Simulink/MATLAB model that HDL Coder exported into `Subsystem.vhd` and
   its submodules is the source of truth for the control algorithm — treat
   the VHDL as generated output, and prefer regenerating from the model over
   hand-editing generated files where possible.
3. When you do touch the generated HDL directly, follow the
   *Re-packaging after HDL edits* steps in the product guide exactly — the
   Vivado IP cache silently reuses stale synthesis results if you skip the
   cache clear.
4. `vivado_project/` and the PetaLinux `build/`, `images/`, and `components/`
   directories are gitignored — don't expect them to be present after a fresh
   clone; regenerate them per *Getting Started* above.
