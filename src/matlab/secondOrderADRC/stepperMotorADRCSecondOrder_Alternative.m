%% for implemenetation of 2nd order mininum foot print discrete time
% from Tuning and implementation variants of descrete-time ADRC 
% Gernot Herbst and Rafal Madonski, Control Theory and Technology (2023)
% 21:72-88
function [k1,alpha,beta,gam]=MFP_ARDC_2nd_parms_alt(bo,zCL,zESO,T)

k1=(1-zCL)^2/T^2;

% denominator parameters
alpha_1 = -3*zESO;
alpha_2 = 3*zESO^2;
alpha_3 = -zESO^3;
alpha=[alpha_1,alpha_2,alpha_3];

% CU(z) numerator parameters
beta_0 = (0.25*(1+zCL)^2*(1+zESO)^3-2*(zCL^2*zESO^3+2*zCL+3*zESO-2))/(bo*T^2);
beta_1 = (-(1+zCL)^2*(1+zESO)^3+2*(1+zCL)^2+6*(zCL^2*zESO^3+2*zCL*zESO+zESO^2+zESO-1))/(bo*T^2);
beta_2 = (-0.25*(1+zCL)^2*(1+zESO)^3+2*(-2*zCL^2*zESO^3+3*zCL^2*zESO^2+2*zCL*zESO^3+1))/(bo*T^2);
beta=[beta_0,beta_1,beta_2];

% Cy(z) numerator parameters
gam_0=0.125*(1+zCL)^2*(1+zESO)^3-zESO*(zCL^2*zESO^2+3);
gam_1=-0.125*(1+zCL)^2*(1+zESO)^3+3*zESO^2+1;
gam_2=zESO^3*(zCL^2-1);
gam=[gam_0,gam_1,gam_2];