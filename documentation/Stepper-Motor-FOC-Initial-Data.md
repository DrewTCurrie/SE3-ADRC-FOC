# FOC Stepper Motor Initial Findings
This documentation records the first data showing a relationship between the quadrature (q-axis) current in the stepper motor and the torque load applied to it.
Written by Drew Currie 10/07/2026

### Key Findings:
- The q-axis current rises linearly with the applied torque load
- The ratio of the two slopes gives $K_t \approx 0.377\ {N·m/A}$, within about 2% of the value calculated from the motor ratings ($0.385\ {N·m/A}$)
- The position control loop output was not being saturated correctly and has been fixed

### What is not covered:
- Tuning of the position, velocity, and current loops
- The root cause of the current oscillation at high torque load

## Table of contents
[[TOC]]

## Controller Change Before Data Collection
The most important change before collecting this data was to the output of the position control loop. This output was **not** being saturated correctly; the limit had been left far too high from some initial testing.

The limit was changed to $35.5\ {rad/s}$ ($\approx 339\ {rpm}$). This corresponds to approximately $60\ {in/min}$, which is a reasonable feedrate for machining 6061 aluminum.

## Results

### Torque load
The torque load measured at the motor rotor ramps almost linearly from $0$ to about $1.25 {N·m}$ over $60\ {ms}$.

![Measured Torque](Simulink-Plots/10-07-2026%20FOC%20Results/Measured%20Torque%20Load.png)

### Quadrature current
The plot below shows the q-axis current reference (`Saturation4`) and the measured q-axis current (`Rate Transition3`).

![Quadrature Current Reference and Measured Current](Simulink-Plots/10-07-2026%20FOC%20Results/Iq%20Target%20and%20Iq%20Measured.png)

Both signals are noisy, but both rise at a clear, constant slope that follows the torque ramp.

> [!NOTE]
> Two regions of this plot do not follow the linear trend:
> - **Startup (first ~5 ms):** the reference starts clamped at its limit of about $4.16\ {A}$ and then drops sharply. This is the initial current needed to start the motor rotating.
> - **High load (after ~45 ms):** the current begins to oscillate with growing amplitude, and the reference is clamped at its limit again near $58\ {ms}$.

## Estimating the Torque Constant
Since $T = K_t \, i_q$, the ratio of the two slopes gives the torque constant directly. Using the slopes rather than the raw values removes the offset caused by the startup current.

Taking the slope of both signals:

$$
\begin{aligned}
\frac{dT}{dt} &= 21.54\ {N·m/s} \\
\frac{di_q}{dt} &= 57.07\ {A/s}
\end{aligned}
$$

Comparing the two:

$$
K_t = \frac{dT/dt}{di_q/dt} = \frac{21.54}{57.07} = 0.377\ {N·m/A}
$$

### Comparison with the motor ratings
The expected torque constant can be calculated from the motor's rated holding torque and current:

$$
\begin{aligned}
T_{holding} &= 1.6\ {N·m} \\
I_{max,rms} &= 2.4\ {A} \\
K_t &= \frac{1.6}{2.4\sqrt{3}} = 0.385\ {N·m/A}
\end{aligned}
$$

The value found from the slopes ($0.377\ {N·m/A}$) is about 2% lower than the value calculated from the ratings ($0.385\ t{N·m/A}$). The small difference is a result of the instability at the end of the run and the initial current needed to start the motor rotation, both of which affect the fitted slopes.

## Torque and Current on One Plot
The plot below shows the torque and the q-axis current reference together, each scaled to its own axis. It shows the relationship more clearly than the separate plots above.

![Torque and Current Reference](Simulink-Plots/10-07-2026%20FOC%20Results/motor%20torque%20and%20q-axis%20current%20reference.png)

>[!TIP]
> Torque is on the left axis and the q-axis current reference is on the right axis. The two axes have different scales, so compare the slopes of the two lines, not where they cross.