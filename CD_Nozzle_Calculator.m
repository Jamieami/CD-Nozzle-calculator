%% DE LAVAL NOZZLE DESIGN CALCULATOR
% Ideal 1-D, steady, isentropic flow of a calorically perfect gas.
% Run this entire script. Change inputs only in Section 1.
clear; clc; close all;

% Edit These Inputs 
gamma = 1.4;          % specific heat ratio
R = 287.05;          % gas constant for air [J/(kg*K)]
P0_psia = 100;        % inlet stagnation pressure [psia, absolute]
T0 = 300;            % inlet stagnation temperature [K]
Pa_psia = 14.7;      % ambient/back pressure [psia, absolute]
Me = 2;            % desired exit Mach number (>1)
Dt_mm = 10;          % throat diameter [mm]
Din_mm = 20;         % inlet diameter [mm], must exceed throat
alpha_deg = 20;      % converging WALL HALF-ANGLE [deg]
beta_deg = 10;       % diverging WALL HALF-ANGLE [deg]
nCon = 100;          % samples in converging section
nDiv = 150;          % samples in diverging section
exportCSV = true;    % save contour points for CAD

%% 2. UNIT CONVERSIONS AND INPUT VALIDATION
% P[Pa] = P[psia] * 6894.757293; D[m] = D[mm]/1000.
assert(gamma>1 && R>0 && T0>0 && P0_psia>0 && Pa_psia>0, ...
    'Gas properties, temperature and absolute pressures must be positive.');
assert(Me>1, 'Use a target exit Mach number greater than 1.');
assert(Dt_mm>0 && Din_mm>Dt_mm, 'Inlet diameter must exceed throat diameter.');
assert(alpha_deg>0 && alpha_deg<90 && beta_deg>0 && beta_deg<90, ...
    'Wall half-angles must lie between 0 and 90 degrees.');
assert(nCon>=2 && nDiv>=2, 'At least two points per nozzle section are required.');
P0 = P0_psia*6894.757293;  % [Pa]
Pa = Pa_psia*6894.757293;  % [Pa]
Dt = Dt_mm/1000;           % [m]
Din = Din_mm/1000;         % [m]

%% 3. THROAT AND EXIT AREA
% A* = pi*Dt^2/4 (Throat area)
At = pi*Dt^2/4;  % throat area [m^2]
% Ae/A* = (1/Me)*[(2/(gamma+1))*(1+(gamma-1)*Me^2/2)]^((gamma+1)/(2*(gamma-1))) 
areaMach = @(M) (1./M).*((2/(gamma+1)).* ...
    (1+(gamma-1).*M.^2/2)).^((gamma+1)/(2*(gamma-1)));
expansionRatio = areaMach(Me);  % Ae/At, dimensionless
Ae = At*expansionRatio;         % exit area [m^2]
% D = sqrt(4*A/pi)
De = sqrt(4*Ae/pi);             % exit diameter [m]

%% 4. WALL GEOMETRY 
% L = (r_large-r_small)/tan(wall half-angle)
Lc = ((Din-Dt)/2)/tand(alpha_deg);  % converging length [m]
Ld = ((De-Dt)/2)/tand(beta_deg);   % diverging length [m]
% Coordinate x=0 at throat; inlet at -Lc, exit at +Ld.
xCon = linspace(-Lc,0,nCon);
xDiv = linspace(0,Ld,nDiv);
rCon = Dt/2 + (-xCon)*tand(alpha_deg);
rDiv = Dt/2 + xDiv*tand(beta_deg);
x = [xCon xDiv(2:end)];           % axial coordinates [m]
r = [rCon rDiv(2:end)];           % inner radius [m]
A = pi*r.^2;                      % local flow area [m^2]
AR = A/At;                        % local area ratio

%% 5. SOLVING AREA-MACH EQUATION ALONG THE NOZZLE
% For A/A* > 1, two solutions exist: subsonic and supersonic.
M = ones(size(x));
for k = 1:numel(x)
    if abs(x(k))<1e-12
        M(k) = 1;
    elseif x(k)<0
        M(k) = fzero(@(m) areaMach(m)-AR(k), [1e-6,1]);
    else
        M(k) = fzero(@(m) areaMach(m)-AR(k), [1, max(3,Me+1)]);
    end
end

%% 6. ISENTROPIC PRESSURE AND TEMPERATURE
% T/T0 = 1/[1+(gamma-1)*M^2/2]
T = T0./(1+(gamma-1).*M.^2/2);         % static temperature [K]
% P/P0 = [1+(gamma-1)*M^2/2]^(-gamma/(gamma-1))
P = P0.*(1+(gamma-1).*M.^2/2).^(-gamma/(gamma-1)); % static pressure [Pa]

%% 7. IDEAL GAS LAW, SPEED OF SOUND, AND VELOCITY
% rho = P/(R*T)
rho = P./(R.*T);                        % local density [kg/m^3]
% a = sqrt(gamma*R*T); V = M*a
a = sqrt(gamma*R.*T);                  % local sound speed [m/s]
V = M.*a;                              % local velocity [m/s]

%% 8. MASS FLOW RATE (CHOKED THROAT)
% mdot = rho*A*V, evaluated at the throat (M=1).
Tt = T0/(1+(gamma-1)/2);                % throat static T [K]
Pt = P0*(1+(gamma-1)/2)^(-gamma/(gamma-1)); % throat static P [Pa]
rhot = Pt/(R*Tt);                       % throat density [kg/m^3]
Vt = sqrt(gamma*R*Tt);                  % throat velocity [m/s]
mdot = rhot*At*Vt;                      % mass flow rate [kg/s]
mdotProfile = rho.*A.*V;               % continuity check [kg/s]

%% 9. BACK-PRESSURE CHECK 
% Ideal adapted expansion requires Pe approximately equal to Pa.
% Pe != Pa can lead to under/over-expansion and shocks/separation.
Pe = P(end);                           % ideal exit static pressure [Pa]
pressureMismatch = (Pe-Pa)/Pa;
criticalRatio = (2/(gamma+1))^(gamma/(gamma-1)); % P*/P0

%% 10. IDEAL THRUST ESTIMATE (OPTIONAL, 1-D)
% F = mdot*Ve + (Pe-Pa)*Ae, assuming negligible inlet momentum.

Fideal = mdot*V(end)+(Pe-Pa)*Ae;        % [N]

%% 11. PRINT ENGINEERING RESULTS
fprintf('\n=== DE LAVAL NOZZLE: IDEAL DESIGN ===\n');
fprintf('Inlet diameter         : %.3f mm\n',Din*1000);
fprintf('Throat diameter        : %.3f mm\n',Dt*1000);
fprintf('Exit diameter          : %.3f mm\n',De*1000);
fprintf('Throat area            : %.4f mm^2\n',At*1e6);
fprintf('Exit area              : %.4f mm^2\n',Ae*1e6);
fprintf('Area ratio Ae/At       : %.5f\n',expansionRatio);
fprintf('Converging length      : %.3f mm\n',Lc*1000);
fprintf('Diverging length       : %.3f mm\n',Ld*1000);
fprintf('Total length           : %.3f mm\n',(Lc+Ld)*1000);
fprintf('Exit Mach              : %.4f\n',M(end));
fprintf('Exit static pressure   : %.3f psia\n',Pe/6894.757293);
fprintf('Ambient pressure       : %.3f psia\n',Pa_psia);
fprintf('Exit static temperature: %.2f K\n',T(end));
fprintf('Exit speed             : %.2f m/s\n',V(end));
fprintf('Mass flow rate         : %.5f kg/s\n',mdot);
fprintf('Ideal thrust estimate  : %.3f N\n',Fideal);
fprintf('Continuity max error   : %.5f %%\n', ...
    100*max(abs(mdotProfile-mdot))/mdot);
fprintf('Choked throat P*/P0    : %.4f\n',criticalRatio);
if abs(pressureMismatch)<0.02
    fprintf('BACK PRESSURE: close to ideal adapted exit (within 2%%).\n');
elseif Pe>Pa
    fprintf('BACK PRESSURE: underexpanded ideal exit (Pe > Pa).\n');
    %fprintf('External expansion may occur; actual flow not solved.\n');
else
    fprintf('BACK PRESSURE: overexpanded ideal exit (Pe < Pa).\n');
    %fprintf('Shocks/separation may occur; actual flow not solved.\n');
end

%% 12. PLOTS: NOZZLE GEOMETRY AND FLOW PROPERTIES
figure('Name','De Laval Nozzle Calculator','Color','w');
subplot(3,2,1)
plot(x*1000,r*1000,'b','LineWidth',1.8); hold on
plot(x*1000,-r*1000,'b','LineWidth',1.8); xline(0,'--k');
axis equal; grid on; xlabel('Axial position (mm)'); ylabel('Radius (mm)');
title('Internal nozzle contour');
subplot(3,2,2)
plot(x*1000,M,'LineWidth',1.8); xline(0,'--k'); yline(1,':k');
grid on; xlabel('Axial position (mm)'); ylabel('Mach number'); title('Mach number');
subplot(3,2,3)
plot(x*1000,P/6894.757293,'LineWidth',1.8); xline(0,'--k');
grid on; xlabel('Axial position (mm)'); ylabel('Static pressure (psia)'); title('Pressure');
subplot(3,2,4)
plot(x*1000,T,'LineWidth',1.8); xline(0,'--k');
grid on; xlabel('Axial position (mm)'); ylabel('Static temperature (K)'); title('Temperature');
subplot(3,2,5)
plot(x*1000,V,'LineWidth',1.8); xline(0,'--k');
grid on; xlabel('Axial position (mm)'); ylabel('Velocity (m/s)'); title('Velocity');
subplot(3,2,6)
plot(x*1000,rho,'LineWidth',1.8); xline(0,'--k');
grid on; xlabel('Axial position (mm)'); ylabel('Density (kg/m^3)'); title('Density');

%% 13. EXPORT CONTOUR AND FLOW DATA FOR CAD/REPORT
% x_mm and radius_mm define the inner nozzle wall profile.
% Revolve the profile about the x axis to construct the flow passage.
if exportCSV
    results = table(x(:)*1000,r(:)*1000,A(:)*1e6,M(:), ...
        P(:)/6894.757293,T(:),V(:),rho(:), ...
        'VariableNames',{'x_mm','radius_mm','area_mm2','Mach', ...
        'pressure_psia','temperature_K','velocity_mps','density_kgm3'});
    writetable(results,'DeLaval_Nozzle_Results.csv');
    fprintf('Exported: DeLaval_Nozzle_Results.csv\n');
end
