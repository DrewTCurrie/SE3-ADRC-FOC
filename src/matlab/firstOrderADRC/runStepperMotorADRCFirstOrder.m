%% Stepper
clear;
% sample time
Ts=0.001;

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
[k1_s,alpha_s,beta_s,gam_s]=MFP_ARDC_1st_parms_alt(bs,zCL_s,zESO_s,Ts);

%electrical
KPiqd=4000.0;
wCL_iqd=KPiqd;% closed loop bandwith (closed loop poles)
zCL_iqd=exp(-wCL_iqd*Ts); % discrete control poles

keso_iqd = 10; % multiplication factor for observer bandwidth
zESO_iqd=exp(-keso_iqd*wCL_iqd*Ts); % discrete observer poles

bid=1/L;
biq=1/L;
[k1_iqd,alpha_iqd,beta_iqd,gam_iqd]=MFP_ARDC_1st_parms_alt(biq,zCL_iqd,zESO_iqd,Ts);

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
VoltagetoADCValue = (2^ADC_Precision - 1)/5;

inverseVoltagetoADCValue = 1/VoltagetoADCValue;
inverseADC_Emulated_Conversion_factor= 1/ADC_Emulated_conversion_factor;


% Motor Driver Constants 
PWMVoltage = 24;
simParams.PWMVoltage = PWMVoltage;


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

