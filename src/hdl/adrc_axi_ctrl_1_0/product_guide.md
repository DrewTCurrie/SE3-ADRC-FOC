# adrc_axi_ctrl v1.0 — Product Guide

**Active Disturbance Rejection Controller, AXI4-Lite Slave**

AXI4-Lite peripheral wrapping `Subsystem.vhd`, a MATLAB/Simulink HDL Coder
export implementing an ADRC control chain for a two-phase stepper motor
(outer position loop → inner current loop, with Park / inverse-Park
transforms for field-oriented control).

---

## Project

Graduate research project, **SE3 Research Lab, Montana State University**.

| Role | Name |
|---|---|
| Principal Investigator | Dr. David Miller |
| Project Advisor | Dr. Michael Edens |
| Primary Contributors | Caleb Binfet, Timothy Currie |

### Goal

Drive a two-phase stepper motor continuously under **Field Oriented Control**,
rather than in conventional open-loop step mode, so that the motor's own
current control loop can be used as a sensing element during machining
operations (mill and lathe work). The primary target is **linear force sensing
through current control** — inferring cutting load from the current required
to hold commanded position — with additional sensing modalities anticipated as
the platform matures.

Running the motor as a synchronous AC machine under FOC gives smooth,
continuous torque production and makes the q-axis current a usable proxy for
applied load. The ADRC outer loop provides disturbance rejection so that
cutting forces appear as an estimable disturbance term rather than as
uncorrected position error.

---

## Target Hardware

| Item | Value |
|---|---|
| Board | AMD/Xilinx Kria KR260 Robotics Starter Kit |
| Device | `xck26-sfvc784-2LV-c` (K26 SOM) |
| Tools | Vivado 2025.2, PetaLinux |
| Bus | AXI4-Lite slave, 32-bit data |
| IP repository | `hardware/ip_repo/adrc_axi_ctrl_1_0` |

---

## Interfaces

| Interface | Type | Notes |
|---|---|---|
| `S00_AXI` | AXI4-Lite slave | `C_S00_AXI_DATA_WIDTH = 32`, `C_S00_AXI_ADDR_WIDTH = 7` |
| `s00_axi_aclk` | Clock | Drives the entire IP including `Subsystem` |
| `s00_axi_aresetn` | Reset | Active low; inverted internally to `Subsystem`'s active-high `reset` |

Address block `S00_AXI_reg` is declared with a 4 KB range (the minimum
aperture the Vivado address editor allocates). The IP itself decodes only the
low 7 address bits; the register file occupies `0x00`–`0x58`.

There are currently **no external pins**. All feedback is supplied over AXI
(see *Known Limitations*).

---

## Register Map

Byte offsets from the assigned base address. Word-addressed internally via
`axi_awaddr(6 downto 2)`.

| Offset | Name | Access | Width | Format |
|---|---|---|---|---|
| `0x00` | `CONTROL` | RW | bit 0 | bit0 = `clk_enable` (0 = freeze, 1 = run) |
| `0x04` | `Position_Target` | RW | [15:0] | sfix16_En8 |
| `0x08` | `KPth` | RW | [15:0] | sfix16_En8 |
| `0x0C` | `K1_s_bs` | RW | [15:0] | sfix16_En8 |
| `0x10` | `beta_s_1` | RW | [15:0] | sfix16_En8 |
| `0x14` | `beta_s_2` | RW | [15:0] | sfix16_En8 |
| `0x18` | `gam_s_1` | RW | [15:0] | sfix16_En8 |
| `0x1C` | `gam_s_2` | RW | [15:0] | sfix16_En8 |
| `0x20` | `alpha_s_1` | RW | [15:0] | sfix16_En8 |
| `0x24` | `alpha_s_2` | RW | [15:0] | sfix16_En8 |
| `0x28` | `id_ref` | RW | [15:0] | sfix16_En8 |
| `0x2C` | `k1_iqd_biq` | RW | [15:0] | sfix16_En8 |
| `0x30` | `beta_iqd_1` | RW | [15:0] | sfix16_En8 |
| `0x34` | `beta_iqd_2` | RW | [15:0] | sfix16_En8 |
| `0x38` | `gam_iqd_1` | RW | [15:0] | sfix16_En8 |
| `0x3C` | `gam_iqd_2` | RW | [15:0] | sfix16_En8 |
| `0x40` | `alpha_iqd_1` | RW | [15:0] | sfix16_En8 |
| `0x44` | `alpha_iqd_2` | RW | [15:0] | sfix16_En8 |
| `0x48` | `ADC_Current_Value` | RW | [15:0] | uint16 — *synthetic feedback* |
| `0x4C` | `ADC_Current_Value1` | RW | [15:0] | uint16 — *synthetic feedback* |
| `0x50` | `EncoderFeedback` | RW | [31:0] | int32 — *synthetic feedback* |
| `0x54` | `O1` | RO | [31:0] | sfix32_En27 |
| `0x58` | `O2` | RO | [31:0] | sfix32_En27 |

### Field placement

All 16-bit parameters occupy the **lower half-word** of their register. The
upper half-word is unused: it reads back as whatever was written and is not
consumed by `Subsystem`. No sign conversion is required in software —
`Subsystem`'s ports are `std_logic_vector`, and the wrapper slices
`slv_reg(n)(15 downto 0)` directly.

### Fixed-point conversion

**sfix16_En8** — signed, 8 fractional bits.

```
raw = round(value * 256)          value = raw / 256.0
range: -128.0 .. +127.996         resolution: 1/256 ≈ 0.0039
```

Position quantities are in **radians**: the encoder scaling inside `Subsystem`
converts counts to radians before the position loop, so `Position_Target` is a
mechanical angle in radians, En8.

**sfix32_En27** — signed, 27 fractional bits. Bit 27 is unity.

```
value = raw / 134217728.0
```

`O1` and `O2` are the inverse-Park outputs after saturation and normalisation
gain, and are bounded to **±1.0** — i.e. they are normalised modulation
indices, directly consumable by a PWM modulator without rescaling.

**uint16** — unsigned raw ADC codes, converted to current internally by
`ADC_to_Current_Converter1` / `2`.

**int32** — raw encoder count. The model's scaling constant assumes a
**20000 count/rev** encoder.

### Write protection

Registers 0–20 (`0x00`–`0x50`) accept AXI writes. Registers 21–22
(`0x54`/`0x58`) are driven every clock from `Subsystem`'s outputs and ignore
writes.

---

## Programming Sequence

Bring-up procedure from userspace on the KR260:

1. Load the PL image (`xmutil loadapp <app-name>`).
2. Read the base address assigned in the Vivado Address Editor.
3. Write `CONTROL = 0` to hold the controller frozen.
4. Write all gain registers (`0x08`–`0x44`) and `id_ref`.
5. Write initial synthetic feedback values (`0x48`, `0x4C`, `0x50`).
6. Write `Position_Target`.
7. Write `CONTROL = 1` to release.
8. Poll `O1` / `O2` to observe controller output.

Quick check with `devmem` (substitute the real base address):

```sh
BASE=0xA0000000
devmem $((BASE+0x00)) 32 0          # freeze
devmem $((BASE+0x08)) 32 0x0100     # KPth = 1.0 in En8
devmem $((BASE+0x04)) 32 0x0200     # Position_Target = 2.0 rad
devmem $((BASE+0x00)) 32 1          # run
devmem $((BASE+0x54)) 32            # read O1
```

A successful AXI round-trip — writing a parameter and reading a non-zero,
changing `O1` — validates the entire PS↔PL path before any motor is connected.

---

## Known Limitations

These are understood and deferred; the current build targets first-boot system
integration, not correct control behaviour.

### `clk_enable` is a static level, not a sample-rate pulse

`Subsystem` was generated with a base rate of **2e-07 s (5 MHz)** and expects
`clk_enable` to pulse once per sample period. It is presently driven by a
register bit held high, so the model steps on **every** AXI clock edge. The
observer and integrator gains were discretised for the 200 ns rate and will
not behave as simulated.

*Fix:* insert a rate divider driving `clk_enable` with a single-cycle pulse,
with the divisor exposed in a register. If a different loop rate is wanted,
change the sample time in Simulink and regenerate — do not simply retune the
divider, as the gains are rate-dependent.

Note also that 5 MHz is far faster than a stepper current loop requires
(10–50 kHz is typical); the base rate likely reflects a Simulink solver step
rather than a deliberate hardware choice.

### `ce_out` carries no information

`Subsystem` drives `ce_out <= clk_enable` — a direct passthrough. It cannot be
used as an output-valid qualifier. Any future `ctrl_valid` output must be
derived from the wrapper's own enable pulse plus a known pipeline latency.

### Single encoder port serves two incompatible consumers

`EncoderFeedback` is scaled once and fed both to the position loop (which
needs an unwrapped absolute angle) and, via the pole-pair gain, to the Park
transforms (which need electrical angle modulo 2π). The intermediate is
sfix16_En8, and the ×50 pole multiply truncates without saturation, so the
commutation angle wraps well inside one mechanical revolution at a point that
is not a multiple of 2π — producing a commutation discontinuity on real
hardware that a bounded simulation will not reveal.

*Fix:* split into two ports — an unwrapped count for position and a
modulo-electrical-cycle count for commutation — supplied by the encoder
interface block.

### ADC MSB unloaded

Synthesis reports `ADC_Current_Value[15]` as having no load inside
`ADC_to_Current_Converter2` (one of ~76 similar unconnected-bit warnings from
the HDL Coder fixed-point conversions). The top bit of the current measurement
is discarded, capping usable current-sense range. Revisit with the Simulink
model.

### Simulink constants unvalidated

Encoder counts/rev, pole-pair count, saturation limits, and observer gains are
carried through from the model as-is and have not been verified against the
physical machine.

---

## Integration Notes

### Block design

Connect `S00_AXI` to a PS master (`M_AXI_HPM0_LPD` on the KR260 base design)
via Connection Automation. Assign an address in the Address Editor and record
it for the driver. No XDC changes are required — the IP has no external pins.

### Re-packaging after HDL edits

1. Package IP → **File Groups** → *Merge changes* (confirm all 11 HDL files
   are present in both VHDL Synthesis and VHDL Simulation).
2. **Customization Parameters** → *Merge changes* (confirm
   `C_S00_AXI_ADDR_WIDTH = 7`).
3. **Ports and Interfaces** → *Merge changes*.
4. **Re-Package IP**.
5. In the block-design project: Reports → **Report IP Status** → Upgrade;
   clear the IP cache; re-customize the IP instance to confirm parameter
   values survived the upgrade; Validate Design; regenerate output products.

Skipping the cache clear silently reuses a stale synthesis of the previous IP
version.

### Source files

`Subsystem.vhd` plus its submodules must all be registered in the IP's file
groups. The full set is larger than the block-diagram hierarchy suggests —
it includes a package file (`Subsystem_pkg.vhd`) and generated helpers
(`Interpolation`, `Sine_Cosine`, `datatype`, `WrapUp`, and others). Add by
globbing the `hdl/` directory rather than by enumerating module names.

### Deployment

The KR260 uses the Kria accelerated-application model. Export the XSA with
bitstream, build the PetaLinux image, and place `.bit.bin`, `.dtbo`, and
`shell.json` in `/lib/firmware/xilinx/<app-name>/`. Load at runtime with
`xmutil loadapp <app-name>` rather than baking the bitstream into `BOOT.BIN`.

---

## Roadmap

| Item | Status |
|---|---|
| AXI4-Lite register interface | Complete |
| `Subsystem` integration | Complete |
| First-boot PS↔PL integration test | In progress |
| Version control (Git) on a fresh project copy | Planned |
| Sample-rate enable generator | Planned |
| Quadrature encoder interface block (dual output) | Planned |
| ADC interface block | Planned |
| SVPWM modulator / gate drive | Planned |
| Fixed-point and gain validation against hardware | Planned |
| Force estimation from q-axis current | Research objective |

---

## Revision History

| Version | Date | Notes |
|---|---|---|
| 1.0 | 2026-07 | Initial packaging. 23-register map, synthetic feedback only. |

---

*SE3 Research Lab, Montana State University.*
