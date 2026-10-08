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
%Bm = 5e-3;
TL=0.0;
Js=3.46831e-5;
Jn=3.3833e-7;
Jf = 1e-4;
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
precise_step_radians = (2*pi)/20000;

mechanicalRadiansPerCount = fi((2*precise_pi)/CountsPerRev, 1, 128, 64);

electricalRadiansPerCount = fi((2*precise_pi)/400, 1, 128, 64);

%% Loadcell Parameters
% Unit conversion constants 
lbf_to_N = 4.448222;
in_to_m = 0.0254;

% Offset measured on PCB
loadcell_offset = 0;

% Loadcell Constants
excitation = 5; %volts
sensitivity = 14.99e-6; %volts
rated_capacity = 667.2; %Newtons (150 lbs)

% Spring values 
spring_constant = 5; % Units of lbf inch (Standard for most McMaster Carr Springs)
% Convert the spring constant to Newton Meters for SI units
spring_constant = (spring_constant * lbf_to_N)/in_to_m;
%% Ballscrew Parameters
ballscrew_lead_mm = 5; %mm/rev
ballscrew_pitch = ballscrew_lead_mm/1000; %m/rev
ballscrew_efficiency = 0.9; 

%Added useful gains to cutdown on extra blocks in simulink
ballscrew_travel_per_rad = ballscrew_pitch/(2*pi);
ballscrew_travel_per_force = ballscrew_pitch/(2*pi*ballscrew_efficiency);

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

steps = 16000;
theta_ref=steps*1.8*pi/180; 
%theta_ref = 0.000314159 * 1000;

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
VelType = fixdt(1,128, 64);
%% Simulate
% Important: Run the updated Simulink Model
% simOut=sim("stepperMotorADRCFirstOrder",'StopTime','0.07')
% 
% 
% %% Plotting
% t_T  = out.motor_torque.Time;   T  = double(squeeze(out.motor_torque.Data));
% t_iq = out.iq_reference.Time;   iq = double(squeeze(out.iq_reference.Data));
% 
% fig = figure('Color','w','Units','inches','Position',[1 1 6.5 4]);
% 
% yyaxis left
% plot(t_T*1e3, T, '-', 'LineWidth', 1.5, 'Color', [0 0.447 0.741])
% ylabel('Motor torque (N·m)')
% set(gca,'YColor',[0 0.447 0.741])
% 
% yyaxis right
% plot(t_iq*1e3, iq, '-', 'LineWidth', 0.8, 'Color', [0.85 0.325 0.098])
% ylabel('q-axis current reference, i_q^* (A)')
% set(gca,'YColor',[0.85 0.325 0.098])
% 
% xlabel('Time (ms)')
% title('Motor torque and q-axis current reference')
% legend('Torque','i_q^*','Location','northwest','Box','off')
% grid on; box on
% set(gca,'FontName','Times New Roman','FontSize',11,'TickDir','out')
% xlim([0 60])
% 
% exportgraphics(fig,'torque_iq.pdf','ContentType','vector')   % or .png with 'Resolution',300
% 
% 
% win = [0.008 0.045];                       % clean linear window (s)
% iT  = t_T  >= win(1) & t_T  <= win(2);
% iI  = t_iq >= win(1) & t_iq <= win(2);
% 
% pT = polyfit(t_T(iT),  T(iT),  1);         % pT(1) = torque slope (N·m/s)
% pI = polyfit(t_iq(iI), iq(iI), 1);         % pI(1) = current slope (A/s)
% 
% Kt = pT(1)/pI(1);
% fprintf('dT/dt = %.2f N·m/s, diq/dt = %.2f A/s, Kt = %.3f N·m/A\n', pT(1), pI(1), Kt)