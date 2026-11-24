function ref_batch = my_preprocessing(egg_dir, result_dir, data_code)
    ref_batch = '';
    fprintf('=== Start my_preprocessing for %s ===\n', data_code);

    if ~exist(result_dir, 'dir')
        mkdir(result_dir);
    end

    desired_order = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2',...
                     'F7','F8','T3','T4','T5','T6','Fz','Cz','Pz'};
    rename_map = {'T7','T3'; 'T8','T4'; 'P7','T5'; 'P8','T6'};
    epoch_sec = 2.56;
    amplitude_threshold = 150;
    min_epochs = 4;

    filename = [data_code, '.set'];
    if ~exist(fullfile(egg_dir, filename), 'file')
        fprintf('  File %s not found. Skip.\n', filename);
        return;
    end

    try
        meta_file = fullfile(egg_dir, [data_code, '_meta.txt']);
        if ~exist(meta_file, 'file')
            fprintf('  Metadata %s not found. Skip.\n', meta_file);
            return;
        end
        metadata = read_metadata(meta_file);

        % --- ref_batch формируется сразу после read_metadata ---
        ref_batch = sprintf('%s %s', metadata.device, metadata.country);
        fprintf('  File batch: "%s"\n', ref_batch);

        EEG = pop_loadset('filename', filename, 'filepath', egg_dir);

        % удаляем ICA
        EEG.icaweights = [];
        EEG.icasphere = [];
        EEG.icawinv = [];
        EEG.icaact = [];
        EEG.icachansind = [];

        % переименование каналов 10-10 -> 10-20
        chan = {EEG.chanlocs.labels};
        for j = 1:size(rename_map, 1)
            idx = find(strcmpi(chan, rename_map{j,1}));
            if ~isempty(idx); chan{idx} = rename_map{j,2}; end
        end
        for j = 1:length(chan)
            EEG.chanlocs(j).labels = chan{j};
        end

        % восстановление отсутствующих каналов
        [is_found, ~] = ismember(lower(desired_order), lower(chan));
        if any(~is_found)
            missing_chans = desired_order(~is_found);
            fprintf('  Missing channels: %s. Attempting reconstruction...\n', ...
                    strjoin(missing_chans, ', '));

            if ~isfield(EEG.chanlocs, 'X') || isempty(EEG.chanlocs(1).X)
                EEG = pop_chanedit(EEG, 'lookup', 'standard_1005.elc');
            end

            for m = 1:length(missing_chans)
                new_chan_name = missing_chans{m};
                if any(strcmpi({EEG.chanlocs.labels}, new_chan_name))
                    continue;
                end
                num_chan = length(EEG.chanlocs);
                EEG.chanlocs(num_chan + 1).labels = new_chan_name;

                switch lower(new_chan_name)
                    case 'cz'
                        EEG.chanlocs(num_chan + 1).X = 0;
                        EEG.chanlocs(num_chan + 1).Y = 0;
                        EEG.chanlocs(num_chan + 1).Z = 1;
                        EEG.chanlocs(num_chan + 1).theta = 0;
                        EEG.chanlocs(num_chan + 1).radius = 0;
                        EEG.chanlocs(num_chan + 1).sph_theta = 0;
                        EEG.chanlocs(num_chan + 1).sph_phi = 0;
                        EEG.chanlocs(num_chan + 1).sph_radius = 1;
                        EEG.chanlocs(num_chan + 1).type = 'EEG';
                    case 'fcz'
                        EEG.chanlocs(num_chan + 1).X = 0;
                        EEG.chanlocs(num_chan + 1).Y = 0.5;
                        EEG.chanlocs(num_chan + 1).Z = 0.866;
                        EEG.chanlocs(num_chan + 1).theta = 0;
                        EEG.chanlocs(num_chan + 1).radius = 0.5;
                        EEG.chanlocs(num_chan + 1).sph_theta = 0;
                        EEG.chanlocs(num_chan + 1).sph_phi = 0;
                        EEG.chanlocs(num_chan + 1).sph_radius = 1;
                        EEG.chanlocs(num_chan + 1).type = 'EEG';
                    case 'pz'
                        EEG.chanlocs(num_chan + 1).X = 0;
                        EEG.chanlocs(num_chan + 1).Y = -1;
                        EEG.chanlocs(num_chan + 1).Z = 0;
                        EEG.chanlocs(num_chan + 1).theta = 180;
                        EEG.chanlocs(num_chan + 1).radius = 1;
                        EEG.chanlocs(num_chan + 1).sph_theta = 180;
                        EEG.chanlocs(num_chan + 1).sph_phi = 0;
                        EEG.chanlocs(num_chan + 1).sph_radius = 1;
                        EEG.chanlocs(num_chan + 1).type = 'EEG';
                    otherwise
                        try
                            tmp_locs = readlocs('standard_1005.elc');
                            ref_loc_idx = find(strcmpi({tmp_locs.labels}, new_chan_name), 1);
                            if ~isempty(ref_loc_idx)
                                EEG.chanlocs(num_chan + 1) = tmp_locs(ref_loc_idx);
                                EEG.chanlocs(num_chan + 1).labels = new_chan_name;
                            else
                                EEG.chanlocs(num_chan + 1) = [];
                                continue;
                            end
                        catch
                            EEG.chanlocs(num_chan + 1) = [];
                            continue;
                        end
                end

                EEG.data(num_chan + 1, :, :) = zeros(1, size(EEG.data, 2), size(EEG.data, 3));
                EEG.nbchan = EEG.nbchan + 1;
                fprintf('    Channel %s added.\n', new_chan_name);
            end

            try
                EEG = pop_interp(EEG, missing_chans, 'spherical');
            catch ME
                fprintf('  Interpolation failed: %s\n', ME.message);
            end

            chan = {EEG.chanlocs.labels};
        end

        % 19 каналов
        [~, idx_19] = ismember(lower(desired_order), lower(chan));
        data_19 = EEG.data(idx_19, :, :);

        % эпохи
        fs = EEG.srate;
        epoch_len = round(epoch_sec * fs);
        n_epochs  = floor(size(data_19, 2) / epoch_len);

        if n_epochs < min_epochs
            fprintf('  Too few epochs. Skip.\n');
            ref_batch = '';
            return;
        end

        data_19 = data_19(:, 1:n_epochs * epoch_len);
        data_epoched = reshape(data_19, [19, epoch_len, n_epochs]);
        %% насколько нужно выбирать "чистые" эпохи по амплитуде???
        is_clean = true(1, n_epochs);
        for e = 1:n_epochs
            if any(abs(data_epoched(:, :, e)) > amplitude_threshold, 'all')
                is_clean(e) = false;
            end
        end
        data_clean = data_epoched(:, :, is_clean);
        n_clean = size(data_clean, 3);
        %%
        fprintf('  Epochs: %d all, %d clean.\n', n_epochs, n_clean);

        if n_clean < min_epochs
            fprintf('  After cleaning left < %d epochs. Skip.\n', min_epochs);
            ref_batch = '';
            return;
        end

        [data_struct, err] = data_gatherer(data_clean, fs, desired_order, data_code, ...
            metadata.reference, metadata.age, metadata.sex, metadata.country, metadata.device);

        if ~isempty(err)
            fprintf('  Error data_gatherer: %s\n', err);
            ref_batch = '';
            return;
        end

        save(fullfile(result_dir, [data_code, '.mat']), 'data_struct');
        fprintf('  Success. Tensor saved in %s\n', result_dir);

    catch ME
        fprintf('  Error: %s\n', ME.message);
        ref_batch = '';
    end
end

function metadata = read_metadata(filepath)
    fid = fopen(filepath, 'r');
    metadata = struct('age', [], 'sex', '', 'country', '', 'device', '', 'reference', '');

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line) || startsWith(line, '#') || startsWith(line, '*')
            continue;
        end
        parts = strsplit(line, '=');
        if length(parts) == 2
            key = lower(strtrim(parts{1}));
            val = strtrim(parts{2});
            switch key
                case 'age',       metadata.age       = str2double(val);
                case 'sex',       metadata.sex       = val;
                case 'country',   metadata.country   = val;
                case 'device',    metadata.device    = val;
                case 'reference', metadata.reference = val;
            end
        end
    end
    fclose(fid);

    if isnan(metadata.age),          error('Field "Age" is not a valid number.'); end
    if isempty(metadata.sex),        error('Field "Sex" is empty.');              end
    if isempty(metadata.country),    error('Field "Country" is empty.');          end
    if isempty(metadata.device),     error('Field "Device" is empty.');           end
    if isempty(metadata.reference),  error('Field "Reference" is empty.');        end
end