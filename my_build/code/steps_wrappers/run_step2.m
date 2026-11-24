function run_step2(dps_table, norm_path, out_dir, study_name, refBatch)
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    if ~exist(dps_table, 'file')
        error('run_step2: DPs file not found: %s', dps_table);
    end

    % загрузка норм
    mnhs = load(norm_path, 'tregs', 'level', 'batch', 'resp', 'opt');

    mnhs.path_table = dps_table;
    mnhs.path_out   = out_dir;
    % связываем наш study (== data_code) с референсным батчем из метаданных
    mnhs.reRefBatch = {study_name, refBatch};
    mnhs.tag        = 'zscore';

    mnhs = mnh_create_predict(mnhs);
    mnhs = MnhCaller(mnhs);

    fprintf('  Step 2 done. Results in %s\n', out_dir);
end