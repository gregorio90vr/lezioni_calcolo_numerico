function action = RFR_00_Download_main(config)

%   =======================================================================
%%  0. Setting the folders of data, configuration and results  
%   =======================================================================
    action = 'OK';

    info = ['Starting the import. This run uses coding installed in ', ...
        config.RFR_Str_config.folders.path_RFR_main];
    RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config);     
    

    %   All the folders used in this process should have 
    %       -->   a common parent folder, and
    %       -->   a specific predetermined name.

    %   RFR_01_basic_setting_config.m    is a simple function where
    %   the parent or 'main folder' is identified,
    %   and also the complete paths of the children folders that
    %   will be used in this application.

    %   All the paths are stored in  'config.RFR_Str_config.folders'
    %   (i.e. as an element of the MatLab structure 'config.RFR_Str_config')

    %   The structure 'config.RFR_Str_config' is saved in a MatLab *.mat file
    %   with other structures containing configuration details as well.
    %   The *.mat file is named  'EIOPA_RFR_config.mat'. 

    %   File  'EIOPA_RFR_config.mat'  should always be saved in
    %   a folder named '01_Config',   child of the main folder
    %   (e.g. if the main folfer is   'C:\EIOPA\RFR' , then file
    %   'EIOPA_RFR_config.mat'  should be in 'C:\EIOPA\RFR\01_Config'

    %   The output of this function is a variable string named
    %   'config'  that simply contains the complete name
    %   of the path ending in the folder  '01_Config'

    %   This variable will be used repeteadly in the following 
    %   because it gives access to the configuration files,
    %   which allow to access and govern all the elements of the
    %   application


    % List of checks to be performed in the alignment control
    checks = {};
        
    [action,importSettings] = RFR_00A_Import_settings();

    if strcmp(action, 'Cancel')
        info = 'Import cancelled by the user in the import settings dialogue.';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        return 
    end

    % If BBL was selected as a source, let the user enter the BBL
    % settings.
    if any(strcmp('BBL API', importSettings(:,2)))
        % If connection settings exist, use them to prefill the dialogue
        if isfield(config.RFR_Str_lists.connections, 'BBL')   
            [action,type,settings] = RFR_00B_BBL_settings(importSettings, ...
                config);
        else
            [action,type,settings] = RFR_00B_BBL_settings(importSettings);
        end
        
        if strcmp(action, 'Cancel')
            info = 'Import cancelled by the user in the BBL import settings dialogue.';
            RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
            return 
        end
        
        % In case the BDL server was selected as a data source, generate
        % the request files and upload them to the server. Afterwards, wait
        % for the availability of the files.
        if strcmp(type, 'server')
            
            uploads = strcmp('BBL API', importSettings(:,2));
            
            if any(uploads)
               uploads = importSettings(uploads,1);  
               outputfiles = uploadBDLRequest(config, settings, uploads);
               settings.outputfiles = outputfiles;
            end
        end
    end
    
    % If DSS was selected as a source, instantiate the DatascopeService
    % object and set up the dssSettings structure
    if any(strcmp('DSS API', importSettings(:,2)))
        if isfield(config.RFR_Str_lists.connections, 'REF')
            refSettings = config.RFR_Str_lists.connections.REF;
            refSettings.dssService = DatascopeSelectService(refSettings.datascopeSelect.user, ...
                refSettings.datascopeSelect.password, config.RFR_Str_config.folders.path_RFR_02_Downloads);
            
            refSettings.trthService = TickHistoryService(refSettings.tickHistory.user,...
                refSettings.tickHistory.password, config.RFR_Str_config.folders.path_RFR_02_Downloads);
        else
            info = 'No connection credentials for DSS available. Aborting...';
            RFR_log_register('01_Import', 'RFR_00_download_main', 'ERROR', info, config); 
            return
        end
    end
    

    % If Markit FTP was selected as a source, let the user enter the Markit
    % FTP settings.
    if any(strcmp('MARKIT FTP', importSettings(:,2)))
        % If connection settings exist, use them to prefill the dialogue
        if isfield(config.RFR_Str_lists.connections, 'Markit')   
            [markitAction,markitConfig] = RFR_06_Markit_Settings(...
                config, true);
        else
            [markitAction,markitConfig] = RFR_06_Markit_Settings(config);
        end
        
        if strcmp(markitAction, 'Cancel')
            info = 'Import cancelled by the user in the Markit import settings dialogue.';
            RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
            return
        end   
    end

    % Set up the waitbar
    wbarLevel = 0;
    wbarStep = 1/(size(importSettings, 1) + 2);
    wbar = waitbar(wbarLevel, 'Starting the import...', 'Name', 'Importing data...');
      
%   =======================================================================
%% 1. Select whether DSS, BBL DL or Excel should be used for the import of CRA, GVT, SWP
%   =======================================================================    
    % CRA
    
    [member,src] = ismember('CRA', importSettings);
    
    if member
        waitbar(wbarLevel, wbar, 'Importing the CRA data...');
        wbarLevel = wbarLevel + wbarStep;
        
        info = 'Importing the CRA data...';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        
        src = importSettings{src,2};
        
        switch src
            case 'DSS API'
                RFR_01_Downloads_CRA(config, 'DSS', refSettings);
            case 'BBL API'
                if strcmp(type, 'file')
                    RFR_01_Downloads_CRA(config, 'BRF', settings);
                elseif strcmp(type, 'server')
                    RFR_01_Downloads_CRA(config, 'BDL', settings);
                end
            case 'XLS'
                RFR_01_Downloads_CRA(config, 'XLS');
        end
        
        checks = [checks,'CRA'];
    end

    % GVT
    [member,src] = ismember('GVT', importSettings);
    
    if member
        waitbar(wbarLevel, wbar, 'Importing the GVT data...');
        wbarLevel = wbarLevel + wbarStep;
        
        info = 'Importing the GVT data...';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        
        src = importSettings{src,2};
        
        switch src
            case 'DSS API'
                RFR_02A_Downloads_SWP_GVT(config, 'GVT', 'DSS', refSettings);
            case 'BBL API'
                if strcmp(type, 'file')
                    RFR_02A_Downloads_SWP_GVT(config, 'GVT', 'BRF', settings);
                elseif strcmp(type, 'server')
                    RFR_02A_Downloads_SWP_GVT(config, 'GVT', 'BDL', settings);
                end
            case 'XLS'
                RFR_02A_Downloads_SWP_GVT(config, 'GVT', 'XLS');
        end
        
        checks = [checks,'GVT'];
    end

    % SWP
    [member,src] = ismember('SWP', importSettings);
    
    if member
        waitbar(wbarLevel, wbar, 'Importing the SWP data...');
        wbarLevel = wbarLevel + wbarStep;
        
        info = 'Importing the SWP data...';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        
        src = importSettings{src,2};
        
        switch src
            case 'DSS API'
                RFR_02A_Downloads_SWP_GVT(config, 'SWP', 'DSS', refSettings);
            case 'BBL API'
                if strcmp(type, 'file')
                    RFR_02A_Downloads_SWP_GVT(config, 'SWP', 'BRF', settings);
                elseif strcmp(type, 'server')
                    RFR_02A_Downloads_SWP_GVT(config, 'SWP', 'BDL', settings);
                end
            case 'XLS'
                RFR_02A_Downloads_SWP_GVT(config, 'SWP', 'XLS');
        end
        
        checks = [checks,'SWP'];
    end

    % ECB
    [member,src] = ismember('ECB', importSettings);
    
    if member
        waitbar(wbarLevel, wbar, 'Importing the ECB data...');
        wbarLevel = wbarLevel + wbarStep;
        
        info = 'Importing the ECB data...';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        
        src = importSettings{src,2};
        
        switch src
            case 'ECB API'
                RFR_03_Download_ECB_curve(config, 'ECB');
            case 'CSV'
                RFR_03_Download_ECB_curve(config, 'CSV');
        end
        
        if ~ismember('GVT', checks)
            checks = [checks,'GVT'];
        end
    end
    

    % DKK
    [member,src] = ismember('DKK', importSettings);
    
    if member
        waitbar(wbarLevel, wbar, 'Importing the DKK data...');
        wbarLevel = wbarLevel + wbarStep;
        
        info = 'Importing the DKK data...';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        
        src = importSettings{src,2};
        
        switch src
            case 'BBL API'
                if strcmp(type, 'file')
                    RFR_05_DKK_covered_bonds(config, 'BRF', settings);
                elseif strcmp(type, 'server')
                    RFR_05_DKK_covered_bonds(config, 'BDL', settings);
                end
            case 'DSS API'
                    RFR_05_DKK_covered_bonds(config, 'DSS', refSettings);
            case 'XLS'
                RFR_05_DKK_covered_bonds(config, 'XLS');
        end
        
        checks = [checks,'DKK'];
    end
    

    % CORP
    [member,src] = ismember('CORP', importSettings);
    
    if member
        waitbar(wbarLevel, wbar, 'Importing the CORP data...');
        wbarLevel = wbarLevel + wbarStep;
        
        info = 'Importing the CORP data...';
        RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
        
        src = importSettings{src,2};
        
        if strcmp(src, 'MARKIT FTP')
            % Download the data
            RFR_06_Downloads_iBoxx_from_Markit_FTP_WinSCP(config,...
                markitConfig);
            % Import it
            RFR_06_Downloads_iBoxx_from_Markit(config,...
                markitConfig, true);
        elseif strcmp(src, 'CSV')
            RFR_06_Downloads_iBoxx_from_Markit(config);
        else
            
        end
        
        checks = [checks,'CORP'];
    end
    
    waitbar(1);
    close(wbar);
    
%   ==================================================================================================
%%  5. Control of downloads of swaps mid rates, government govts bonds rates and corporate bonds rates        
%   ==================================================================================================
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;

    file_download = 'RFR_basic_curves';       

    load(fullfile(folder_download, file_download), 'RFR_download_BBL_Mid');

    RFR_07_Downloads_controls(config, config.refDate); 

    info = ['Step 6. Controls written in excel file for last three months for the reference date ' ...
        datestr(config.refDate, 'dd/mm/yyyy')];
    RFR_log_register( '01_Import', 'RFR_07_Download', 'INFO', info, config);

            
%   =======================================================================
%%  6. Align the dates across the databases       
%   =======================================================================
    RFR_08_Alignment_of_the_data_bases(config);
    
    aligned = RFR_02_basic_control_alignment_data_bases(config, checks);          
   
    if ~aligned
        info = 'Section 2. Input data not aligned. Some term structures may not get calculated correctly.';
        RFR_log_register('00_Basic', 'RFR_00_basic', 'WARNING', info, config); 
        
    end

%   ==================================================================================================
%%  7. Final actions to close this module
%   ==================================================================================================
    info = 'Import finished.';
    RFR_log_register('01_Import', 'RFR_00_download_main', 'INFO', info, config); 
    
    RFR_write_log_to_CSV(config);    
        
    start_msg = helpdlg(strcat( {'The import process concluded and the log events were saved on the hard disk'; ''}),...
                                 'IMPORT PROCESS');
    uiwait(start_msg)
end