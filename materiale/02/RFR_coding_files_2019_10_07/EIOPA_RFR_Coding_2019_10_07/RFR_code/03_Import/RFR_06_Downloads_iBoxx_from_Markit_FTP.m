function [bdates] = ...
    RFR_06_Downloads_iBoxx_from_Markit_FTP(RFR_config_mat_file, markitConfig)

    % Download the MARKIT CSV files and import the data
    load(RFR_config_mat_file);
    bdates = {};

    %% FTP settings
    % Read in the iBoxx FTP settings from the config file
    folder_import = RFR_Str_config.folders.path_RFR_03_Import;
    iboxxFile = fullfile(folder_import, 'iBoxx_FTP_inventory.xlsx');
    
    if ~exist(iboxxFile, 'file')
        info_message = [iboxxFile ...
                ' doesn''t exist. Configuration file couldn''t be found. Aborting...'];            
                             
        RFR_log_register('01_Import', '06_Download', 'ERROR',...
            info_message, RFR_config_mat_file);
        return
    end
    
    [~,txt] = xlsread(iboxxFile, 'iBoxx_Settings', 'B11:E500');
    
    % Columns in the settings file are: Type of Index, Path, Archive Path
    % and corresponding file pattern
    indices = txt(:,1);        
    idxPath = txt(:,2);
    idxArPath = txt(:,3);  
    idxPattern = txt(:,4);
    
    for i=1:length(indices)
        markitConfig.data.(indices{i}).path = idxPath{i};
        markitConfig.data.(indices{i}).pathHistory = idxArPath{i};
        markitConfig.data.(indices{i}).fileRegExp = idxPattern{i};
    end

    %% Local settings
    markitConfig.RETRIES = 20;
    markitConfig.TIMEOUT = 1200000;

    %% FTP connection
    connected = false;

    for i=1:markitConfig.RETRIES
        ftpServer = ftp;
        ftpServer.host = markitConfig.server;
        ftpServer.username = markitConfig.user;
        ftpServer.password = markitConfig.password;
        
        ftpStruct = struct(ftpServer);
        ftpStruct.jobject.enterLocalPassiveMode();
        % Set the timeout to 100s
        ftpStruct.jobject.setDefaultTimeout(markitConfig.TIMEOUT);
        ftpStruct.jobject.setDataTimeout(markitConfig.TIMEOUT);
        
        connected = ~isempty(dir(ftpServer));

        if connected
            break
        else
            close(ftpServer);
            clear ftpStruct;
        end
    end

    if ~connected
       close(ftpServer);
       
        info_message = 'Couldn''t connect to the Markit FTP server. Aborting...';            
                             
        RFR_log_register('01_Import', '06_Download', 'ERROR',...
            info_message, RFR_config_mat_file);
        return
    end


    %% Dates to download
    dates = markitConfig.bdate:markitConfig.edate;
    eomdates = unique(eomdate(dates), 'stable');
    dates = dates(isbusday(dates)' | ismember(dates, eomdates));
    dates = cellstr(datestr(dates, 'yyyymmdd'));

    %% Download the data
    fields = fieldnames(markitConfig.data);

    for nCurrency = 1:length(fields)
        currency = fields{nCurrency};
        bdates = {};
        
        if strfind(currency, 'EUR')
           localDir = strrep(currency, 'EUR', 'Euro');
        else
           localDir = currency;
        end
           
        for state = {'current','historic'}
            
            if strcmp(state{:}, 'current')
                path = 'path';
                downloadDates = dates;
            else
                path = 'pathHistory';
                downloadDates = bdates;
                
                % If there are no dates that couldn't be found, continue
                % with the next currency.
                if isempty(downloadDates)
                    continue
                end
            end

           dList = retry(@() dir(ftpServer, markitConfig.data.(currency).(path)), ...
               markitConfig.RETRIES);

           if isempty(dList)
               info_message = ['Couldn''t retrieve directory listing for '...
                   currency '. Retrying...'];        
                             
                RFR_log_register('01_Import', '06_Download', 'WARNING',...
                    info_message, RFR_config_mat_file);
           else

               % Check existence of data file. If it can't be found in the standard
               % directory, check the historical files. If it isn't there either, issue
               % a warning.
                [downloadFiles,bdates] = getFilesForDates({dList.name}, downloadDates, ...
                    markitConfig.data.(currency).fileRegExp);
                cd(ftpServer, markitConfig.data.(currency).(path));
                
                
                for i=1:length(downloadFiles)    
                    connected = ~isempty(dir(ftpServer));
                    
                    if ~connected
                        ftpServer = ftp;
                        ftpServer.host = markitConfig.server;
                        ftpServer.username = markitConfig.user;
                        ftpServer.password = markitConfig.password;

                        ftpStruct = struct(ftpServer);
                        ftpStruct.jobject.enterLocalPassiveMode();
                        % Set the timeout to 100s
                        ftpStruct.jobject.setDefaultTimeout(markitConfig.TIMEOUT);
                        ftpStruct.jobject.setDataTimeout(markitConfig.TIMEOUT);

                        connected = ~isempty(dir(ftpServer));

                        cd(ftpServer, markitConfig.data.(currency).(path));
                    end
                            
                    for tries = 1:markitConfig.RETRIES
                        success = false;

                        try
                            ftpStruct.jobject.sendNoOp();
                            mget(ftpServer, downloadFiles{i}, ...
                                    fullfile(markitConfig.dpath, localDir));

                            % Get server side hash
                            ftpStruct.jobject.sendCommand('XMD5', downloadFiles{i});
                            reply = char(ftpStruct.jobject.getReplyString());

                            if ~isempty(reply)
                                reply = strsplit(reply);
                                % Reply is of the format "StatusCode Reply"
                                reply = reply{2};

                                % Compare the hashes
                                if getHashOfFile(fullfile(markitConfig.dpath,...
                                    localDir, downloadFiles{i})) == reply
                                    success = true;
                                    break
                                else                                      
                                    info_message = ['Checksums differ for ' ...
                                        downloadFiles{i} '. Retrying download...'];            

                                    RFR_log_register('01_Import', '06_Download', 'WARNING',...
                                        info_message, RFR_config_mat_file);
                                end
                            end

                         catch
                            % Reconnect
                            disp('Lost connection! Retrying!');
                            close(ftpServer);
                        end
                    end
                    
                    if ~success
                        info_message = ['Couldn''t download ' ...
                                            downloadFiles{i} ' without errors.'];            

                        RFR_log_register('01_Import', '06_Download', 'ERROR',...
                            info_message, RFR_config_mat_file);
                    end
                end
           end
        end
        
        if ~isempty(bdates)
            info_message = [currency ': Couldn''t download files for the dates ' ...
                             strjoin(bdates, ',') '.'];            

                        RFR_log_register('01_Import', '06_Download', 'WARNING',...
                            info_message, RFR_config_mat_file);
            disp(bdates);
        end
    end
    
    close(ftpServer);
end