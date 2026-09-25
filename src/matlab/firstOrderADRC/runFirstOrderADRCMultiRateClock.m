%% Run the Minimum Footprint Active Disturbance Rejection Control model
% with the update Nema23 Stepper Motor that matches the Mini-Tech mill

clear;
clc;
close all hidden;
% sample time
% This is set based on the FPGA's base clock speed. Additional multi-rate
% clocking is handled in the Simulink Model
Ts=2e-5;

%% Stepper Motor Parameters
% motor parameters
RT=50 ; 
L=0.0027;
r=0.9;
Km=0.3771;
PsiM=Km/RT;

Jm=3.5e-5;
Bm=8e-4;
TL=0.0;
Js=3.46831e-5;
Jn=3.3833e-7;
J=Jm+Js+Jn;

%% PCB and testbench Parameters 
% TODO: Adjust the voltage saturation in the Simulink model to handle the
% max of ~66% of 64V.  For now, allowing for 48V is fine without the PWM
% generation in the model. 

% source voltage
vs=48.0; 
% PWM Saturation voltage 
PWMVoltage = 48;

%% ADC Constants


%ADC Constants
ADC_VREF = 5;
ADC_Precision = 16;

% This may need to be changed in the future. Going with a smaller resistor
% and a larger gain is the recommended option for the INA241 and general
% shunt amp usage. 
Shunt_Amp_Gain = 10;
% This is set at the resistance of the shunts on the board. A calibrated
% value should be used in the final version. 
Shunt_Resistance = .1;

% These are used to emulate the ADCS
ADC_Emulated_conversion_factor = Shunt_Resistance*Shunt_Amp_Gain;
VoltagetoADCValue = (2^ADC_Precision)/5;

% These are used to convert from the ADC 16 bit register to a voltage value
inverseVoltagetoADCValue = 1/VoltagetoADCValue;
inverseADC_Emulated_Conversion_factor= 1/ADC_Emulated_conversion_factor;

% New simulation parameters with updated timing and new constants
% This section supports ADC decoding with the real 16 bit data 
% along with, encoder position decoding, and separated stepper motor
convert_adc_to_integer = 1/13107;
% 5v at the shunt amp with configuration to offset to 1/2 V_ref
% This will need to be adjusted because the filters each have a slight
% offset applied to the final value. 
Shunt_Amp_Offset = 5/2;

% Shunt amp offset value for decoding the ADC reading this is 5/2 as an 
% unsigned value of just bits. This is so the math is fast in the FPGA
% and takes advantage of bitwise operations 
ADC_Offset = fi(32768, 0, 16,0);
%% Encoder Constants
% The encoder is a 5,000 count quadrature encoder producing 20,0000 counts
% per full mechanical revolution
% This means for a full electrical revolution, it is 400 counts
CountsPerRev = 5000*4;
% Divide by 50 for 50 pole pairs. 
electricalCountsPerRev = CountsPerRev/50;
% This might seem like overkill to have pi calculated out this far however,
% because this value of pi is compared to and subtracted off of other
% values this needs to be a very precise constant to prevent small errors
% from building during run time. This means getting the full 32 bit values
% for the number. 
precise_pi = fi(3.1415927410125732421875, 1,32,28);
precise_step_radians = fi((2*precise_pi)/CountsPerRev, 1, 64,57);

mechanicalRadiansPerCount = fi((2*precise_pi)/CountsPerRev, 1, 128, 64);

electricalRadiansPerCount = fi((2*precise_pi)/400, 1, 128, 64);


%% Control Parameters
% Position Control Constants

KPth=150; % position  proportional gain 

% Velocity Control Constants 
wCL_s=750;                     % closed loop bandwidth (closed loop poles) 
zCL_s=exp(-wCL_s*Ts);           % discrete control poles
keso_s = 8;                     % multiplication factor for observer bandwidth
zESO_s=exp(-keso_s*wCL_s*Ts);   % discrete observer poles

%TODO: Establish correct bs parameter. 
bs=50*PsiM/J;
%bs=1/J;
[k1_s,alpha_s,beta_s,gam_s]=MFP_ADRC_1st_params_multirate(bs,zCL_s,zESO_s,Ts);

% Control Control Constants
KPiqd=10000.0; 
wCL_iqd=KPiqd;                  % closed loop bandwidth (closed loop poles)
zCL_iqd=exp(-wCL_iqd*Ts);       % discrete control poles

keso_iqd = 1.5;                  % multiplication factor for observer bandwidth
zESO_iqd=exp(-keso_iqd*wCL_iqd*Ts); % discrete observer poles

bid=1/L;
biq=1/L;
[k1_iqd,alpha_iqd,beta_iqd,gam_iqd]=MFP_ADRC_1st_params_multirate(biq,zCL_iqd,zESO_iqd,Ts);

steps = 1;
theta_ref=steps*1.8*pi/180; 
stepTime=0.0;
%zIC=[0;0]; % delay initial values

%% Feedback Filter Parameters

% Low pass filter for velocity 
wf = 5000;             
af = 1 - exp(-wf*Ts);     

%% Simulation Parameters

ParamType = fixdt(1,32,20);
% Recording position of the motor requires more non-fractional accuracy 
PosType = fixdt(1,32,16); 
% Also turned out to be the perfect value for tracking ADC values in addition to encoder counts
CountType = fixdt(1,32,0); 
% Additional parameters for use in the ADRC loops. 
% The ADRC for velocity requires holding large values > 10,000
% The current control ADRC requires holding small numbers < 1
SpeedLoopType = fixdt(1,32,16);   % ±32768, LSB 1.5e-5
CurrLoopType  = fixdt(1,32,20);   % ±2048,  LSB 9.5e-7
%Bitwise logical operator data type
bitwiseOperator = fixdt(0,32,0);
%% Simulate
% Important: Run the updated Simulink Model
simOut=sim("stepperMotorADRCFirstOrder",'StopTime','0.05')
    

%% Plotting
time=simOut.tout;
thetam=simOut.theta_m_degrees.data;
target = ones(size(time,1),1).*(theta_ref*180/pi);

% Create figures and plots
figure
plot(time,thetam,'r',time,target);
xlabel("time (sec)")
ylabel("rotor angle (deg)") 
figure
plot(simOut.calculated_phase_a_current, 'r')
hold on; grid on;
plot(simOut.calculated_phase_b_current, 'b')
plot(simOut.true_phase_a_current, 'r--')
plot(simOut.true_phase_b_current, 'b:')
legend('Calculated Phase A Current', 'Calculated Phase B Current', 'True Phase A Current', 'True Phase B Current')

