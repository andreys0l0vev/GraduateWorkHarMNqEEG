clear;
clc;

eeg_dir  = 'eegs/first_files/closed';

eeg_dir_str  = char(eeg_dir);
eeg_dir_name = strrep(eeg_dir_str, 'eegs/', '');
eeg_dir_name = strrep(eeg_dir_name, '/', '_');

% addpath обязателен для всех папок
addpath(genpath('.'));

norm_dir      = 'norm';
refM_path     = fullfile(norm_dir, 'refM_riemlogm_global_1564.mat');
norm_log_path = fullfile(norm_dir, 'norm_log_gfavfa_bfvf_study.mat');
norm_riem_path= fullfile(norm_dir, 'norm_riemlogm_gfavfa_bava_study.mat');

data_dir      = fullfile('data', [eeg_dir_name, '_data']);
inter_res_dir = 'intermediate_result';
step_dir      = fullfile(inter_res_dir, eeg_dir_name);   % внутри — подпапки по ЭЭГ
result_dir    = fullfile('result', eeg_dir_name);        % внутри — подпапки по ЭЭГ

if ~exist(step_dir,   'dir'); mkdir(step_dir);   end
if ~exist(result_dir, 'dir'); mkdir(result_dir); end

eeg_files = dir(fullfile(eeg_dir, '*.set'));
if isempty(eeg_files)
    error('No .set files in %s', eeg_dir);
end

fprintf('=== START PIPELINE FOR: %s ===\n', eeg_dir_name);
fprintf('  EEG input: %s\n', eeg_dir);
fprintf('  Found %d EEG files\n', length(eeg_files));

for i = 1:length(eeg_files)
    data_code = eeg_files(i).name(1:end-4);
    fprintf('\n========== [%d/%d] %s ==========\n', i, length(eeg_files), data_code);

    % персональные папки для этого ЭЭГ
    file_step_dir   = fullfile(step_dir,   data_code);
    file_result_dir = fullfile(result_dir, data_code);
    if ~exist(file_step_dir,   'dir'); mkdir(file_step_dir);   end
    if ~exist(file_result_dir, 'dir'); mkdir(file_result_dir); end

    fprintf('\n[1/4] Preprocessing %s...\n', data_code);
    refBatch = my_preprocessing(eeg_dir, data_dir, data_code);
    if isempty(refBatch)
        fprintf('  SKIP %s: preprocessing failed\n', data_code);
        continue;
    end

    fprintf('\n[2/4] Step 0: Metadata for %s...\n', data_code);
    try
        run_step0(data_dir, file_step_dir, data_code);
    catch ME
        fprintf('  SKIP %s: step0 failed: %s\n', data_code, ME.message);
        continue;
    end
    metadata_table = fullfile(file_step_dir, [data_code, '_metadata.xlsx']);

    fprintf('\n[3.a/4] Step 1 Log DPs for %s...\n', data_code);
    log_ok = false;
    try
        run_step1(metadata_table, file_step_dir, 'log', [], data_code);
        dps_log_path = fullfile(file_step_dir, sprintf('DPs_log_1_%s.csv', data_code));
        log_ok = exist(dps_log_path, 'file') == 2;
    catch ME
        fprintf('  ERROR %s log step1: %s\n', data_code, ME.message);
    end

    fprintf('\n[3.b/4] Step 1 Riemannian DPs for %s...\n', data_code);
    riem_ok = false;
    try
        run_step1(metadata_table, file_step_dir, 'riemlogm', refM_path, data_code);
        dps_riem_path = fullfile(file_step_dir, sprintf('DPs_riemlogm_1_%s.csv', data_code));
        riem_ok = exist(dps_riem_path, 'file') == 2;
    catch ME
        fprintf('  ERROR %s riemlogm step1: %s\n', data_code, ME.message);
    end

    if log_ok
        fprintf('\n[4.a/4] Step 2 Log Z-scores for %s...\n', data_code);
        try
            run_step2(dps_log_path, norm_log_path, file_result_dir, data_code, refBatch);
        catch ME
            fprintf('  ERROR %s log step2: %s\n', data_code, ME.message);
        end
    end

    if riem_ok
        fprintf('\n[4.b/4] Step 2 Riemannian Z-scores for %s...\n', data_code);
        try
            run_step2(dps_riem_path, norm_riem_path, file_result_dir, data_code, refBatch);
        catch ME
            fprintf('  ERROR %s riemlogm step2: %s\n', data_code, ME.message);
        end
    end

    % очистка памяти для отдельной ЭЭГ
    clear refBatch metadata_table dps_log_path dps_riem_path;
end

fprintf('\n=== PIPELINE COMPLETED ===\n');
fprintf('Final Z-score tables are in: %s\n', result_dir);