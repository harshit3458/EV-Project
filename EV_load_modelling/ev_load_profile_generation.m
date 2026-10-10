clear;
clc;
close all;
rng(1);

%% User Parameters

N = 200;
mu_hour = 18;
sigma_hour = 3;
num_days = 365;

battery_options = [40 60 80];
charging_options = [3.3 7 11];

noise_min = 0.85;
noise_max = 1.15;

%% Generate EV Arrival Times

mu_min = mu_hour * 60;
sigma_min = sigma_hour * 60;

arrival_raw = mu_min + sigma_min * randn(N,1);
arrival_times = mod(arrival_raw ,1440);
arrival_times = round(arrival_times);
arrival_times = sort(arrival_times);

%% Generate EV Parameters
Battery_Capacity = battery_options(randi(length(battery_options),N,1))';
Charging_Rating = charging_options(randi(length(charging_options),N,1))';
Initial_SOC = 20 + (50 - 20) * rand(N,1);
Final_SOC = 90 + (100 - 90) * rand(N,1);

%% Plot Arrival Time Histogram

figure;
histogram(arrival_times,48);
xlabel('Arrival Time (minutes of day, 1-1440)');
ylabel('Number of EVs');
title('Distribution of EV Arrival Times for Residential Charging');
xlim([1 1440]);
grid on;

%% Energy and Charging Duration

Energy_Needed =  Battery_Capacity .* (Final_SOC - Initial_SOC) / 100;
Charge_Duration = Energy_Needed ./ Charging_Rating;
Start_Hour = arrival_times / 60;

%% Convert Arrival Time to HH:MM

arrival_hh = floor(arrival_times / 60);
arrival_mm = mod(arrival_times,60);

%% Prepare EV Data for Excel

Initial_SOC_excel = round(Initial_SOC,2);
Final_SOC_excel = round(Final_SOC,2);
Energy_Needed_excel = round(Energy_Needed,2);
Charge_Duration_excel = round(Charge_Duration,2);

%% Save EV Data to Excel

EV_ID = (1:N)';

T_EV = table( ...
    EV_ID, ...
    arrival_times, ...
    arrival_hh, ...
    arrival_mm, ...
    Battery_Capacity, ...
    Charging_Rating, ...
    Initial_SOC_excel, ...
    Final_SOC_excel, ...
    Energy_Needed_excel, ...
    Charge_Duration_excel);

T_EV.Properties.VariableNames = { ...
    'EV_ID', ...
    'Arrival_Minute', ...
    'Arrival_Hour', ...
    'Arrival_Min', ...
    'Battery_Capacity_kWh', ...
    'Charging_Rating_kW', ...
    'Initial_SOC_percent', ...
    'Final_SOC_percent', ...
    'Energy_Needed_kWh', ...
    'Charging_Duration_hours'};

writetable(T_EV,'ev_arrival_data.xlsx');


%% Time-Accurate Base Hourly Load Calculation

Base_Load = zeros(24,1);

for i = 1:N

    t_current = Start_Hour(i);
    remaining = Charge_Duration(i);

    while remaining > 0

        t_mod = mod(t_current,24);
        h = floor(t_mod);
        hr_passed = t_mod - h;
        space = 1 - hr_passed;
        charge_seg = min(remaining,space);

        Base_Load(h+1) = Base_Load(h+1) + Charging_Rating(i) * charge_seg;

        remaining = remaining - charge_seg;
        t_current = t_current + charge_seg;

    end
end


%% Apply Independent Random Noise
% Every hour of every day has independent randomness

Load_all = zeros(24,num_days);

hourly_noise = noise_min + (noise_max - noise_min) * rand(24,num_days);

for d = 1:num_days

    Load_all(:,d) = Base_Load .* hourly_noise(:,d);
end

%% Calculate Average Daily Profile

Load_avg = mean(Load_all,2);
hours = 0:23;

%% Plot All 365 Daily Load Curves

figure;
hold on;
for d = 1:num_days

    plot(hours, Load_all(:,d),'LineWidth',1);
end

xlabel('Hour of Day (0-23)');
ylabel('Load (kW)');

title('Residential EV Charging Load Profiles - 365 Days');
xticks(0:23);
grid on;
hold off;

%% Plot Average Load Profile as Histogram

figure;
histogram( 'BinEdges',0:24,'BinCounts',Load_avg);

xlabel('Hour of Day (0-23)');
ylabel('Average Load (kW)');
title('Average Residential EV Charging Load Profile');
xlim([0 23]);
xticks(0:23);
grid on;

%% Save All 365 Daily Profiles to Excel

Load_all_excel = round(Load_all,2);
T_daily = array2table( ...
    [hours' Load_all_excel]);

T_daily.Properties.VariableNames = [ {'Hour'}, ...
    arrayfun(@(x) sprintf('Day_%d',x), ...
    1:num_days, ...
    'UniformOutput',false)];

writetable(  T_daily, 'ev_load_profile_365days.xlsx');

%% Save Average Load Profile to Excel
Load_avg_excel = round(Load_avg,2);
T_average = table(hours',Load_avg_excel);
T_average.Properties.VariableNames = { 'Hour', 'Average_EV_Load_kW'};

writetable(T_average, 'ev_average_load_profile.xlsx');

save('ev_average_load_profile.mat', ...
    'hours', ...
    'Load_avg');

%% Display Results

disp(' ');
disp('==============================================');
disp('365-DAY EV LOAD PROFILE GENERATION COMPLETED');
disp('==============================================');

fprintf('Number of EVs: %d\n',N);
fprintf('Number of days: %d\n',num_days);
fprintf('Mean arrival time: %.2f hour\n',mu_hour);
fprintf('Arrival time standard deviation: %.2f hour\n',sigma_hour);
fprintf('Peak average EV load: %.2f kW\n',max(Load_avg));
fprintf('Average daily EV energy: %.2f kWh/day\n', sum(Load_avg));

disp(' ');
disp('Files generated:');
disp('1. ev_arrival_data.xlsx');
disp('2. ev_load_profile_365days.xlsx');
disp('3. ev_average_load_profile.xlsx');
disp('4. ev_average_load_profile.mat');
disp('==============================================');