%% не используем getMetaDataTable, чтобы обрабатывать файлы по одному, а не всю директорию

function run_step0(spectrum_dir, out_dir, data_code)
    if ~exist(out_dir, 'dir'); mkdir(out_dir); end

    mat_file = fullfile(spectrum_dir, [data_code, '.mat']);
    if ~exist(mat_file, 'file')
        error('run_step0: file not found: %s', mat_file);
    end

    S  = load(mat_file, 'data_struct');
    ds = S.data_struct;

    % нормализация пола — как в genMetaDataTable
    switch ds.sex
        case {'F','w','female','Female'}, sex_norm = 'F';
        case {'M','m','male','Male'},     sex_norm = 'M';
        otherwise,                        sex_norm = ds.sex;
    end

    % набор колонок genMetaDataTable
    T = table();
    T.name      = {data_code};                    % (в оригинале — study_<file>, здесь чистое имя)
    T.country   = {ds.pais};
    T.age       = ds.age;
    T.sex       = {sex_norm};
    T.ref       = {ds.ref};
    T.device    = {ds.EEGMachine};
    T.pathology = {'Unknown'};                    % как в предыдущих вызовах с genMetaDataTable(...,'Unknown')
    T.study     = {data_code};                    % переопределяем: у каждого файла свой study
    T.srate     = ds.srate;
    T.dnames    = {strjoin(ds.dnames, '')};
    T.nt        = ds.nt;
    T.nepochs   = ds.nepochs;
    T.fmin      = ds.fmin;
    T.fmax      = ds.fmax;
    T.freqres   = ds.freqres;
    T.path      = {mat_file};
    T.filelog   = {'full info'};

    out_file = fullfile(out_dir, [data_code, '_metadata.xlsx']);
    writetable(T, out_file);
    fprintf('  Step 0 done: %s\n', out_file);
end