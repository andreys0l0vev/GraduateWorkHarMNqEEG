clear;
clc;

% вывод параметров кЭЭГ
EEG = pop_loadset('filename', 'Chi_path_024_fon1_closed.set', 'filepath', 'my_build/qEEGs/first_files/closed');
chan = {EEG.chanlocs.labels};
fprintf('Channels:\n');
fprintf('Total channels count: %d\n', length(chan));
disp(chan);
desired_order = {'Fp1'    'Fp2'    'F3'    'F4'    'C3'    'C4'    'P3'    'P4'    'O1'    'O2'    'F7'    'F8'    'T3'    'T4'    'T5'    'T6'    'Fz'    'Cz'    'Pz'};
% таблица эквивалентности из generate_cross_spectrum - заранее убираем различия в монтаже электродов
rename_map = {'T7','T3'; 'T8','T4'; 'P7','T5'; 'P8','T6'};
chan_renamed = chan;
for i = 1:size(rename_map, 1)
    idx = find(strcmpi(chan_renamed, rename_map{i,1}));
    if ~isempty(idx)
        chan_renamed{idx} = rename_map{i,2};
        fprintf('  %s was renamed to %s\n', rename_map{i,1}, rename_map{i,2});
    end
end

% проверка присутствия каждого из 19 каналов
fprintf('\n=== Required 19 channels check ===\n');
[found, od] = ismember(lower(desired_order), lower(chan_renamed));
fprintf('%-6s %-10s %s\n', 'Idx', 'Channel', 'Status');
fprintf('%s\n', repmat('-', 1, 30));
for i = 1:length(desired_order)
    if found(i)
        fprintf('%-6d %-10s OK (idx = %d)\n', i, desired_order{i}, od(i));
    else
        fprintf('%-6d %-10s MISSING\n', i, desired_order{i});
    end
end
n_found = sum(found);
fprintf('\nFound %d / %d required channels\n', n_found, length(desired_order));

if n_found < length(desired_order)
    missing = desired_order(~found);
    fprintf('Missing channels: %s\n', strjoin(missing, ', '));
    fprintf('WARNING: data_gatherer will reject this file\n');
else
    fprintf('OK: all required channels present\n');
end

% проверка на наличие ICA (не должно быть)
fprintf('\n=== ICA ===\n');
if ~isempty(EEG.icaweights)
    fprintf('ICA decomposition PRESENT (icaweights not empty)\n');
    fprintf('WARNING: HarMNqEEG requires NO ICA preprocessing\n');
else
    fprintf('ICA decomposition absent\n');
end

fs = EEG.srate;         % частота дискретизации
nt = size(EEG.data, 2); % длина эпохи в отсчётах
epoch_sec = nt / fs;    % длина эпохи в секундах
fprintf('\nFreq discretization: %.f Hz\n', fs);
fprintf('\nEpoch length: %.f counts | %.f s (target: 2.56 s)\n', nt, epoch_sec);
ne = size(EEG.data,3);
fprintf('\nEpoch number: %d (must be > 3)\n', ne);

% проверка референса: референтный электрод, относительно которого измеряется эл-й потенциал других электродов
fprintf('\n=== Reference ===\n');
fprintf('Reference: %s\n', EEG.ref); % average - среднее всех электродов

% проверка амплитуд (для оценки артефактов)
fprintf('\n=== Amplitude check ===\n');
data = EEG.data;
fprintf('Max abs amplitude: %.2f µV\n', max(abs(data(:))));
fprintf('RMS amplitude: %.2f µV\n', rms(data(:)));

threshold = 100;  % µV
is_clean = true(1, ne);
for e = 1:ne
    epoch = data(:, :, e);
    if any(abs(epoch(:)) > threshold)
        is_clean(e) = false;
    end
end
fprintf('Epochs with max|ampl| > %d µV: %d / %d\n', threshold, sum(~is_clean), ne);
fprintf('Estimated clean epochs: %d\n', sum(is_clean));