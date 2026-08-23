function  RFR_write_log_to_CSV(config)

    %   This function writes in an Excel workbook the log of events

    
    %   1.1. Loading to workspace the configuration data
    %   ------------------------------------------------    

    folder_download = config.RFR_Str_config.folders.path_RFR_98_Runs_Logs; 
    file_download   = 'RFR_Str_Runs_Logs_register';       

    load(fullfile(folder_download, file_download));

    %   1.2. Relevant rows in cell array  'RFR_Str_Runs_Logs_register'  
    %   are identified
    %   -------------------------------------------------------------------
       
    rows_to_write =(datenum(RFR_Str_Runs_Logs_register(:,1), 'yyyymmdd') >= ...
                      today-7);
    
    
    logData = [ RFR_Str_Runs_Logs_register(1,:);...
                      RFR_Str_Runs_Logs_register(rows_to_write,:)];
              
    %  first row has the headlines with the content of each columns
    
    logFile = fullfile(config.RFR_Str_config.folders.path_RFR_98_Runs_Logs, ...
                              'Log.csv');

    fid = fopen(logFile, 'w');                      
       
    for i = 1:size(logData, 1)
       fprintf(fid, '"%s","%s","%s","%s","%s","%s"\n', logData{i,1}, logData{i,2},...
           logData{i,3}, logData{i,4}, logData{i,5}, char(logData{i,6})); 
    end
    fclose(fid);
end

