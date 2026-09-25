%% Stepper
clear;
% sample time
Ts=2e-5;

% motor parameters
RT=50 ; 
L=0.019;
r=15;
Km=0.385;
PsiM=Km/RT;

J=4.5e-5;
Bm=8e-4;
TL=0.0;

% position

KPth=30; % postion  proprortional gain

% speed 
wCL_s=500;% closed loop bandwith (closed loop poles)
zCL_s=exp(-wCL_s*Ts); % discrete control poles
keso_s = 20; % multiplication factor for observer bandwidth
zESO_s=exp(-keso_s*wCL_s*Ts); % discrete observer poles
bs=PsiM/J;
bs=1/J;
[k1_s,alpha_s,beta_s,gam_s]=stepperMotorADRCFirstOrder_Alternative(bs,zCL_s,zESO_s,Ts);

%electrical
KPiqd=4000.0;
wCL_iqd=KPiqd;% closed loop bandwith (closed loop poles)
zCL_iqd=exp(-wCL_iqd*Ts); % discrete control poles

keso_iqd = 10; % multiplication factor for observer bandwidth
zESO_iqd=exp(-keso_iqd*wCL_iqd*Ts); % discrete observer poles

bid=1/L;
biq=1/L;
[k1_iqd,alpha_iqd,beta_iqd,gam_iqd]=stepperMotorADRCFirstOrder_Alternative(biq,zCL_iqd,zESO_iqd,Ts);

theta_ref=1.8*pi/180; 

vs=12.0; % source voltage
stepTime=0.0;
zIC=[0;0]; % delay initial values

%% Caleb Added Values 


% Encoder
CountsPerRev = 5000*4;
simParams.CountsPerRev = CountsPerRev;
DegreesPerCount = 360/CountsPerRev;
RadiansPerCount = (2*pi)/CountsPerRev;

% Motor
RT = 50;

%ADC Constants
ADC_VREF = 5;
ADC_Precision = 16;

Shunt_Amp_VREF = 5;
Shunt_Amp_Offset = Shunt_Amp_VREF/2;
Shunt_Amp_Gain = 10;

Shunt_Resistance = .1;
ADC_Emulated_conversion_factor = Shunt_Resistance*Shunt_Amp_Gain;
VoltagetoADCValue = (2^ADC_Precision)/5;

inverseVoltagetoADCValue = 1/VoltagetoADCValue;
inverseADC_Emulated_Conversion_factor= 1/ADC_Emulated_conversion_factor;


% Motor Driver Constants 
PWMVoltage = 24;
simParams.PWMVoltage = PWMVoltage;



%% New simulation parameters with updated timing and new constants
% This section supports ADC decoding with the real 16 bit data 
% along with, encoder position decoding, and separated stepper motor
convert_adc_to_integer = 1/13107;
% 5v at the shunt amp with configuration to offset to 1/2 V_ref
% This will need to be adjusted because the filters each have a slight
% offset applied to the final value. 
adc_gain = 5/2;

% Encoder parameters
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
mechanicalRadiansPerCount = fi((2*precise_pi)/CountsPerRev, 1, 128, 64);

electricalRadiansPerCount = fi((2*precise_pi)/400, 1, 128, 64);


% Custom fixed point values for the ADRC model 
% This splits the types into two standard data sizes to streamline the
% process of configuring the appropriate data types. This does come with a
% size hit on the FPGA, however the AXI bus already expects the data to be
% in 32 bit format so in practice on the KR260 specifically, there's no hit
% to resource usage but improves the data precision considerably 

ParamType = fixdt(1,32,20);
% Recording position of the motor requires more non-fractional accuracy 
PosType = fixdt(1,32,16); 
CountType = fixdt(1,32,0);
%% Simulate
% simOut=sim("Stepper_MFP_ARDC_1",'StopTime','0.5')
% 
% time=simOut.tout;
% thetam=simOut.Closed.data(:,1);
% 
% figure
% plot(time,thetam*180/pi,'r',time,theta_ref*180/pi*ones(size(time,1)));
% xlabel("time (sec)")
% ylabel("rotor angle (deg)")

