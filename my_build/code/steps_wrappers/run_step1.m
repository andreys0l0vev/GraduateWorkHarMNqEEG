function run_step1(metadata_table, out_dir, typeLog, refM_path, study_name)
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    T = readtable(metadata_table);
    if isempty(T)
        error('run_step1: empty metadata table %s', metadata_table);
    end
    dataFilter = {'study', T.study{1}};

    if strcmpi(typeLog, 'riemlogm')
        load(refM_path, 'refM');
        gaussianize_DPs_predict(metadata_table, out_dir, refM, typeLog, [], dataFilter, [], study_name);
    else
        gaussianize_DPs_predict(metadata_table, out_dir, [], typeLog, [], dataFilter, [], study_name);
    end
    fprintf('  Step 1 (%s) done. Results in %s\n', typeLog, out_dir);
end