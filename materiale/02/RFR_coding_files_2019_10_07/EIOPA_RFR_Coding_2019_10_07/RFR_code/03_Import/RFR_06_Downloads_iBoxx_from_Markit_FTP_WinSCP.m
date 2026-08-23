function [bdates] = ...
    RFR_06_Downloads_iBoxx_from_Markit_FTP_WinSCP(config, markitConfig)

    % Change in future versions to a path in the mat config
    winscpAssembly = fullfile(pwd, '96_extLib', 'WinSCPnet.dll');
    NET.addAssembly(winscpAssembly);
    
    % Check if the download directory exists and if not, create it
    if exist(markitConfig.dpath, 'dir') == 0
        mkdir(markitConfig.dpath);
    end
    
    % Download the MARKIT CSV files and import the data
    bdates = {};

    %% FTP settings
    % Read in the iBoxx FTP settings from the config file
    folder_import = config.RFR_Str_config.folders.path_RFR_03_Import;
    iboxxFile = fullfile(folder_import, 'iBoxx_FTP_inventory.xlsx');
    
    if ~exist(iboxxFile, 'file')
        info_message = [iboxxFile ...
                ' doesn''t exist. Configuration file couldn''t be found. Aborting...'];            
                             
        RFR_log_register('01_Import', '06_Download', 'ERROR',...
            info_message, config);
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
        sessionOptions = WinSCP.SessionOptions;
        sessionOptions.Protocol = WinSCP.Protocol.Sftp;
        sessionOptions.HostName = markitConfig.server;
        sessionOptions.UserName = markitConfig.user;
        sessionOptions.Password = markitConfig.password;
        sessionOptions.TimeoutInMilliseconds = markitConfig.TIMEOUT;
        sessionOptions.SshHostKeyFingerprint = markitConfig.fingerprint;
        
        session = WinSCP.Session;
        session.Open(sessionOptions);
        
        connected = session.Opened;
        
        if connected
            break
        end
    end

    if ~connected
        session.Close();
       
        info_message = 'Couldn''t connect to the Markit FTP server. Aborting...';            
                             
        RFR_log_register('01_Import', '06_Download', 'ERROR',...
            info_message, config);
        return
    else
        transferOption = WinSCP.TransferOptions();
        transferOption.TransferMode = WinSCP.TransferMode.Ascii;
    end


    %% Dates to download
    dates = markitConfig.bdate:markitConfig.edate;
    eomdates = unique(eomdate(dates), 'stable');
    dates = dates(isbusday(dates,NaN)' | ismember(dates, eomdates));
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
        
       
        downloadDir = fullfile(markitConfig.dpath, localDir);
        
        if exist(downloadDir, 'dir') == 0
            mkdir(downloadDir);
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

           dList = listDir(session, markitConfig.data.(currency).(path));

           if isempty(dList)
               info_message = ['Couldn''t retrieve directory listing for '...
                   currency '. Retrying...'];        
                             
                RFR_log_register('01_Import', '06_Download', 'WARNING',...
                    info_message, config);
           else

               % Check existence of data file. If it can't be found in the standard
               % directory, check the historical files. If it isn't there either, issue
               % a warning.
                [downloadFiles,bdates] = getFilesForDates(dList, downloadDates, ...
                    markitConfig.data.(currency).fileRegExp);
                remoteDir = markitConfig.data.(currency).(path);
                
                
                for i=1:length(downloadFiles)            
                    for tries = 1:markitConfig.RETRIES
                        success = false;

                        try
                            if ~session.Opened
                                session.Open(sessionOptions);
                                connected = session.Opened;
                            end
                            
                            transferOpRes = session.GetFiles(strcat(remoteDir,...
                                downloadFiles{i}), fullfile(downloadDir,...
                                downloadFiles{i}), false, transferOption);
                            
                            transferOpRes.Check();
                            
                            success = true;
                            break;
                            
                           
                         catch
                            % Reconnect
                            connected = false;
                            disp('Lost connection! Retrying!');
                            session.Close();
                        end
                    end
                    
                    if ~success
                        info_message = ['Couldn''t download ' ...
                                            downloadFiles{i} ' without errors.'];            

                        RFR_log_register('01_Import', '06_Download', 'ERROR',...
                            info_message, config);
                    end
                end
           end
        end
        
        if ~isempty(bdates)
            info_message = [currency ': Couldn''t download files for the dates ' ...
                             strjoin(bdates, ',') '.'];            

                        RFR_log_register('01_Import', '06_Download', 'WARNING',...
                            info_message, config);
            disp(bdates);
        end
    end
    
    session.Close();
end

function [lst] = listDir(session, directory)
    lst = {};
    
    col = session.ListDirectory(directory);
    
    if col.Files.Count > 0
        lst = cell(col.Files.Count, 1);
        
        for i=0:(col.Files.Count - 1)
           rfi = col.Files.Item(i);
           lst{i+1} = char(rfi.Name);
        end
    end
end