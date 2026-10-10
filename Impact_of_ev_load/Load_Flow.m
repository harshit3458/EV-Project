clc;
clear;
close all;

%% 1. System parameters
nbus = 33;
baseMVA = 100;
Vbase = 12.66e3;
Zbase = Vbase^2/(baseMVA*1e6);

%% 2. Read branch data from Excel
% Columns: From_Bus, To_Bus, R_ohm, X_ohm
branch = readmatrix('Branch_Data.xlsx','Range','A2:D33');

R = branch(:,3)/Zbase;
X = branch(:,4)/Zbase;

[parent,pbranch,order] = build_tree(branch,nbus);

%% 3. Distributed generation
% [Bus number, active generation in kW]
DG = [18 200; 22 200; 25 200; 33 200];

Pg = zeros(nbus,1);
Pg(DG(:,1)) = DG(:,2);

%% 4. Read base load data
Pdata = readmatrix('Base_Load_data.xlsx', ...
    'Sheet',1,'Range','A3:Y35');

Qdata = readmatrix('Base_Load_data.xlsx', ...
    'Sheet',2,'Range','A3:Y35');

Pd = Pdata(:,2:end);    % Active load (kW)
Qd = Qdata(:,2:end);    % Reactive load (kVAr)

%% 5. Read EV profile from MAT file
ev = load('ev_average_load_profile.mat');

hours = ev.hours(:);
EV = ev.Load_avg(:);    % Assumed to be in kW

%% 6. Run hourly load flow
V_noEV = zeros(nbus,24);
V_EV = zeros(nbus,24);
Loss_noEV = zeros(24,1);
Loss_EV = zeros(24,1);

for h = 1:24

    % Case 1: Without EV
    P = Pd(:,h) - Pg;
    Q = Qd(:,h);

    [V,L] = bfs(P,Q,parent,pbranch,order,R,X,baseMVA);
    V_noEV(:,h) = abs(V);
    Loss_noEV(h) = L;

    % Case 2: With EV; allocate EV load across buses 2 to 33
    weights = max(Pd(2:end,h),0);

    if sum(weights) > 0
        weights = weights/sum(weights);
    else
        weights = ones(32,1)/32;
    end

    P_ev = P;
    P_ev(2:end) = P_ev(2:end) + EV(h)*weights;

    [V,L] = bfs(P_ev,Q,parent,pbranch,order,R,X,baseMVA);
    V_EV(:,h) = abs(V);
    Loss_EV(h) = L;
end

%% 7. Plot voltage profile at peak EV load
[~,peak] = max(EV);

figure;
plot(1:33,V_noEV(:,peak),'-o', ...
     1:33,V_EV(:,peak),'-s','LineWidth',1.5);
xlabel('Bus Number');
ylabel('Voltage (p.u.)');
title(sprintf('Voltage Profile at Hour %d',hours(peak)));
legend('Without EV','With EV','Location','best');
grid on;

%% 8. Plot minimum voltage over 24 hours
figure;
plot(hours,min(V_noEV,[],1),'-o', ...
     hours,min(V_EV,[],1),'-s','LineWidth',1.5);
xlabel('Hour');
ylabel('Minimum Voltage (p.u.)');
title('Minimum Voltage Over 24 Hours');
legend('Without EV','With EV');
xticks(0:23);
grid on;

%% 9. Plot power losses
figure;
plot(hours,Loss_noEV,'-o', ...
     hours,Loss_EV,'-s','LineWidth',1.5);
xlabel('Hour');
ylabel('Power Loss (kW)');
title('Power Loss With and Without EV');
legend('Without EV','With EV');
xticks(0:23);
grid on;

%% 10. Save voltage results
T1 = array2table([(1:33)' V_noEV V_EV]);
T1.Properties.VariableNames = ...
    [{'Bus'}, ...
     arrayfun(@(h)sprintf('NoEV_Hour_%d',h),hours', ...
     'UniformOutput',false), ...
     arrayfun(@(h)sprintf('EV_Hour_%d',h),hours', ...
     'UniformOutput',false)];

writetable(T1,'Voltage_Results.xlsx');

%% 11. Save loss results
T2 = table(hours,Loss_noEV,Loss_EV, ...
    'VariableNames',{'Hour','Loss_NoEV_kW','Loss_EV_kW'});

writetable(T2,'Loss_Results.xlsx');

%% 12. Display summary
fprintf('Peak EV load hour: %d\n',hours(peak));
fprintf('Minimum voltage without EV: %.4f p.u.\n',min(V_noEV(:)));
fprintf('Minimum voltage with EV: %.4f p.u.\n',min(V_EV(:)));
fprintf('Load flow completed.\n');

