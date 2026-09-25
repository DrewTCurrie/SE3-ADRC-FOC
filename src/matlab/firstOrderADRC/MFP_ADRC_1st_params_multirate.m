%% for implemenetation of 1st order mininum foot print discrete time
% from Tuning and implementation variants of descrete-time ADRC 
% Gernot Herbst and Rafal Madonski, Control Theory and Technology (2023)
% 21:72-88
function [k1,alpha,beta,gam]=MFP_ADRC_1st_params_multirate(bo,zCL,zEso,T)

k1=(1-zCL)/T;

% denominator parameters
alpha_1 = -2*zEso;
alpha_2 = zEso^2;
alpha=[alpha_1,alpha_2];

% CU(z) numerator parameters
beta_0 = (zCL*zEso^2-2*zEso-zCL+2)/(T*bo);
beta_1 = (2*zCL*zEso-2*zCL*zEso^2+zEso^2-1)/(T*bo);
beta=[beta_0,beta_1];

% Cy(z) numerator parameters
gam_0=(zCL*zEso^2-2*zEso+1);
gam_1=(zEso^2-zCL*zEso^2);
gam=[gam_0,gam_1];