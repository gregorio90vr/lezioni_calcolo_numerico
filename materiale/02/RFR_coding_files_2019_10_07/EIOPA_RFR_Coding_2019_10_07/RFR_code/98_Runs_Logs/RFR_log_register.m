function RFR_log_register(module, id_function, action, info, config)
    %   This function adds to the relevant element (identified by 'module')
    %   of the MATLAB structure 'RFR_run_log' the event defined by 'action'
    %   and   'message', triggered by function  'name_function'.

    %   Once added the event, the MATLAB structure is stored on the hardisk

    if config.RFR_Str_config.loggingEnabled
        folder_download = config.RFR_Str_config.folders.path_RFR_98_Runs_Logs; 
        file_download = 'RFR_Str_Runs_Logs_register';       

        load(fullfile(folder_download, file_download));

        C1R_new_event = {datestr(today,'yyyymmdd'), datestr(now), module,...
            id_function, action, info};

        RFR_Str_Runs_Logs_register = [RFR_Str_Runs_Logs_register;C1R_new_event];

        save(fullfile(config.RFR_Str_config.folders.path_RFR_98_Runs_Logs, ...
                            'RFR_Str_Runs_Logs_register'), 'RFR_Str_Runs_Logs_register');
    end
end