# FOC Stepper Motor: Simulation Experiment Plan

### Formatting notes for the plots: 
- Label every axis with units.
- Use a legend when there is more than one line.
- Leave the plot title off the thesis version. The thesis caption replaces it. A title is fine on a working copy.
- Use color only when it carries meaning (MSU formatting rule).

---

### 1. Phase currents vs. electrical angle

**Goal:** Show that the two phase currents are sinusoidal, 90° apart, and locked to the rotor electrical angle. This is the visual proof that FOC is commutating the motor.

**Why it matters:** This is the first figure a reader needs to believe the motor is being driven by FOC and not just stepped.

**Setup:** Use the baseline run script and the original position target. Turn on logging (or add To Workspace blocks) for `ia`, `ib` and `theta_r` from the plant, and for the decoded phase currents on the controller side.

**Procedure:**
1. Run the baseline simulation.
2. Plot `ia` and `ib` against time over a window where the motor is turning at roughly constant speed.
3. Wrap the electrical angle into the range [−π, π] and plot it on a second axis, or on a stacked subplot that shares the time axis.
4. Make a second plot of `ia` and `ib` against electrical angle (x-axis: θ_e, from −π to π). If FOC is working, the points fall on a cosine and a sine.
5. Measure the phase offset between `ia` and `ib` using zero crossings or a cross-correlation.

**Record:** Both plots, the measured phase offset in degrees, and the time window you used.

---

### 2. d-axis current regulation

**Goal:** Show that i_d stays near zero while i_q carries the load.

**Why it matters:** In the thesis argument, i_d is "wasted" current. Showing it is held near 0 A while i_q tracks torque supports the claim that i_q alone produces torque.

**Setup:** Log the i_d reference, the measured i_d, the i_q reference and the measured i_q. These are the outputs of the Park transform (`Park Transform1`) and the saturation blocks.

**Procedure:**
1. Run the baseline simulation.
2. Plot measured i_d and i_q on the same axes.
3. Calculate the mean and RMS of i_d over the steady-motion window, for example 8–45 ms.
4. Calculate the ratio RMS(i_d) / RMS(i_q) over the same window.

**Record:** The plot, mean(i_d), RMS(i_d) and the ratio.


---

### 3. Reprocess the Raspberry Pi load cell data

**Goal:** Turn the existing Raspberry Pi (cascaded PID) hardware logs into one clean summary figure of i_q against load cell force.

**Why it matters:** This is the only hardware data from the project. Even if it is noisy, a careful plot with an honest error estimate is useful as preliminary evidence and motivation.

**Setup:** Get the folder of Raspberry Pi run logs from sharepoint.

**Procedure:**
1. Write a loader that reads every run into one MATLAB table, with one row per run and the time series stored inside.
2. For each run, find the steady-load windows and calculate the mean i_q (or the phase-current offset, whichever was logged) and the mean load cell force.
3. Convert force to motor torque with T = F · p / (2π · η), using p = 0.00254 m and η = 0.9.
4. Scatter i_q against torque for all runs. Fit a line and report the slope, the intercept and R².


### 4. Steady-state load steps (i_q vs. torque)

**Goal:** Measure i_q at several **constant** load torques and show the relationship is linear, with slope equal to K_t.

**Why it matters:** This is the central result. Constant loads remove the acceleration and startup terms that distort the current ramp-based estimate.

**Setup:**
- With correct units, the spring rig cannot reach a meaningful torque within a short simulation. **Apply the load directly at the motor's `TL` input** with a Step or Constant block, and bypass the spring for this test.
- Use a velocity or position target that keeps the motor turning at a steady speed. Pick one reference speed to begin with, for example 10 rad/s.

**Procedure:**
1. Choose load levels of 0, 0.2, 0.4, 0.6, 0.8, 1.0 and 1.2 N·m. Holding torque is 1.6 N·m, so stay below it.
2. For each level, run long enough for i_q to settle, then average i_q over a settled window, for example the last 20 ms.
3. Also record the standard deviation of i_q in that window.
4. Plot mean i_q (y-axis) against load torque (x-axis), with error bars of ±1 standard deviation.
5. Fit T = K_t · i_q + c. Report K_t, c, R² and the residuals.
6. Compare the fitted K_t with the model value (0.3771 N·m/A).

**Record:** The scatter plot with the fit line, a residual plot, a table of load against mean i_q, standard deviation and speed error, and the fit values.

---

### 5. K_t sweep in the plant model

**Goal:** Show that the measured i_q-to-torque slope follows the motor's real K_t, not a value built into the controller.

**Why it matters:** Recovering the same 0.377 that was entered into the model could look circular to a reviewer. If you change the plant's K_t while leaving the controller alone, and the recovered slope follows the plant, the method is shown to be measuring the motor.

**Setup:** Change only the **plant's** `Km` (and with it `PsiM`). Keep the controller parameters, including `bs`, at their nominal values. You'll have to double check that Km and PsiM are not used anywhere but the motor model. I don't think they are but worth checking.

**Procedure:**
1. Set the plant K_t to 80%, 90%, 100%, 110% and 120% of 0.3771 N·m/A.
2. For each value, run the E5 load steps (a subset of 4 load levels is enough).
3. Fit K_t for each plant value.
4. Plot fitted K_t against plant K_t, with a y = x reference line.

**Record:** The plot and a table of plant K_t, fitted K_t and % error.

---

### 6. Open-loop vs. FOC under load

**Goal:** Compare open-loop stepping with FOC under the same increasing load. Record current draw, position error, and the load at which each stalls or slips.

**Why it matters:** This is the "why bother with FOC on a stepper" argument. Open loop always draws full current and can lose sync. FOC draws current in proportion to load and stays synchronized.

**Setup:** The open loop simulink model is ```runStepperMotor_TestBench```  Use the same load profile for both modes: a torque ramp applied at `TL`, from 0 up to about 1.5 N·m.

**Procedure:**
1. Run open loop and FOC with the same load ramp and motion target.
2. Plot phase current amplitude against time for both modes.
3. Plot position error (target minus θ_m) against time for both modes.
4. Note the torque at which open loop slips (a sudden jump in position error) and at which FOC fails, if it does.
5. Calculate copper loss for both modes: P = R · (i_a² + i_b²), averaged over the run. 

**Record** The two comparison figures, the slip/stall torques, and the average copper loss for each mode.

---

### 7. Linearity at different speeds

**Goal:** Check that the i_q-to-torque slope stays the same at different motor speeds.

**Why it matters:** Back-EMF rises with speed. If the slope changed with speed, i_q could not be used as a load measurement on its own. This also tells us where voltage limits start to matter.

**Procedure:** Repeat a reduced version of E5 (4 load levels) at reference speeds of 5, 10, 20 and 35 rad/s. The 35 rad/s case is the machining feedrate limit. Plot fitted K_t against speed.

**Record:** The plot and a table that also lists the peak |v_dq| against the bus voltage at each speed.

---

### 8. Torque ramp rate and the inertia term

**Goal:** Measure how the speed of the load ramp biases the slope-based K_t estimate.

**Why it matters:** The original result used a ramp. While the motor is accelerating, i_q also supplies J·dω/dt and B·ω. This experiment shows how large that error is, and whether the original method needs a correction.

**Procedure:**
1. Apply load ramps to 1.0 N·m over 20, 60, 200 and 1000 ms.
2. Run the existing slope-ratio method (`polyfit` on T and i_q) on each.
3. Also calculate the corrected value K_t = (T + J·dω/dt + B·ω) / i_q at each sample, and average it.
4. Compare both estimates against 0.3771.

**Record:** A table of ramp duration, slope-method K_t and corrected K_t.

**Note:** You have the table and a short note on which method you would recommend.

---
