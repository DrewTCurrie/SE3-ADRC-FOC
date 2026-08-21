%% Stepper
clear;
% sample time
Ts=0.001;

% motor parameters
RT=50 ; 
L=0.019;
r=15;
Km=0.385;
KT=Km/RT;
PsiM=KT;

J=4.5e-5;
Bm=8e-4;
TL=0.0;



% position/speed 
wCL_ts=100;% closed loop bandwith (closed loop poles)
zCL_ts=exp(-wCL_ts*Ts); % discrete control poles
keso_ts = 20; % multiplication factor for observer bandwidth
zESO_ts=exp(-keso_ts*wCL_ts*Ts); % discrete observer poles
b_ts=1/J;
[k1_ts,alpha_ts,beta_ts,gam_ts]=MFP_ARDC_2nd_parms_alt(b_ts,zCL_ts,zESO_ts,Ts);

%electrical
KPiqd=3000.0;
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


% simOut=sim("Stepper_MFP_ARDC_2",'StopTime','.5')
% 
% time=simOut.tout;
% thetam=simOut.Closed.data(:,1);
% 
% figure
% plot(time,thetam*180/pi,'r',time,theta_ref*180/pi*ones(size(time,1)));
% xlabel("time (sec)")
% ylabel("rotor angle (deg)")