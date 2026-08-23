function RFR_05_DKK_covered_bonds(config, source, connectionSettings) 
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   This function moves market data of yields of the DKK index
    %   as set out in section 10.C.4 of the technical documentation
    
    %   IMPORTANT:  The excel file should respect exactly the template

    
    if ~ismember(source, {'XLS','BDL','BRF', 'DSS'})
      info_message = 'The source selected for this function is not available. CRA import can not be executed';     
      RFR_log_register('01_Import', 'RFR_01_Download', 'ERROR', info_message,...
          config);
            
      throw(MException('DKKImport:UnknownSourceException',...
          ['Unknown data source ''' source '''.']));
    end
%   =======================================================================
%%  1. Loading configuration and existing database of yields and durations  
%   =======================================================================
    %   Loading to workspace the history of ECB government rates
    %   --------------------------------------------------------
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download   = 'RFR_basic_curves';           
        %   Name of the MatLab numeric 2-D matrix with the historical
        %   serie of interest rates of corporate curvea

    load(fullfile(folder_download, file_download));

    
    %   Loading to workspace the corporate bonds curves
    %   -----------------------------------------------
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download   = 'Str_Corporates';           
        %   Name of the MatLab numeric 2-D matrix with the historical
        %   serie of interest rates of corporate curvea

     load(fullfile(folder_download, file_download), 'DKK_Nykredit');
    
       
%   =======================================================================
%%  2. Reading excel file and preparing new data
%      (including interpolation of the missing dates)
%   =======================================================================
    
    switch source
        case 'XLS'
            file_to_read = fullfile(folder_download, 'DKK_Nykredits_index.xlsx');    

            if ~exist(file_to_read, 'file')
                info_message = [file_to_read ...
                        'doesn''t exist. NO DATA TO IMPORT FOR DKK RATES'];            

                RFR_log_register('01_Import', '05_Download', 'ERROR',...
                    info_message, config);
                return
            end

            info = 'Importing DKK data from XLS.';
            RFR_log_register('01_Import', 'RFR_05_Download', 'INFO',...
                    info, config); 

            [V1C_new_yields,C1C_new_dates] = xlsread(file_to_read, 'RFR', ...
                'K11:L10000');

            V1C_new_dates = datenum(C1C_new_dates, 'dd/mm/yyyy');

        case 'BDL'
            info = 'Importing DKK data from BBL Data License.';
            RFR_log_register('01_Import', 'RFR_05_Download', 'INFO',...
                    info, config); 

            [V1C_new_yields,V1C_new_dates,V1C_new_durations] = RFR_05_DKK_covered_bonds_BBL(...
                source, connectionSettings);
        case 'BRF'
            info = 'Importing DKK data from BBL request output files.';
            RFR_log_register('01_Import', 'RFR_05_Download', 'INFO',...
                    info, config); 

            [V1C_new_yields,V1C_new_dates,V1C_new_durations] = RFR_05_DKK_covered_bonds_BBL(...
                source, char(connectionSettings.DKK));
        case 'DSS'
            info = 'Importing DKK data from the TRTH API.';
            RFR_log_register('01_Import', 'RFR_05_Download', 'INFO',...
                    info, config); 

            [V1C_new_yields,V1C_new_dates,V1C_new_durations] = ...
                RFR_05_DKK_covered_bonds_REF(config, connectionSettings);
    end
    
     V1C_new_yields(isnan(V1C_new_yields)) = 0;
     V1C_new_durations(isnan(V1C_new_durations)) = 0;
     
%   =======================================================================
%%  3. Write the new data into the M2D_DKK_Nykredit array
%   =======================================================================
    oldest_date_to_import = datenum('01/01/2015', 'dd/mm/yyyy');
    
    % Remove dates before the first date to import from the new import data
    rowsBefore = V1C_new_dates < oldest_date_to_import;
    V1C_new_yields(rowsBefore) = [];
    V1C_new_dates(rowsBefore) = [];
    V1C_new_durations(rowsBefore) = [];
    
    % Overwrite existing data
    [ia,locb] = ismember(V1C_new_dates, DKK_Nykredit.M2D_DKK_Nykredit(:,1));
    DKK_Nykredit.M2D_DKK_Nykredit(locb(ia),2) = V1C_new_yields(ia);
    DKK_Nykredit.Duration_DKK_Nykredit(locb(ia),2) = ...
        V1C_new_durations(ia);
    
    % Extend the array with new data (if there is new data)
    DKK_Nykredit.M2D_DKK_Nykredit = [DKK_Nykredit.M2D_DKK_Nykredit;
        [V1C_new_dates(~ia),V1C_new_yields(~ia)]];
    DKK_Nykredit.M2D_DKK_Nykredit = sortrows(DKK_Nykredit.M2D_DKK_Nykredit);
    
    DKK_Nykredit.Duration_DKK_Nykredit = [DKK_Nykredit.Duration_DKK_Nykredit;
        [V1C_new_dates(~ia),V1C_new_durations(~ia)]];
    DKK_Nykredit.Duration_DKK_Nykredit = sortrows(DKK_Nykredit.Duration_DKK_Nykredit);

%   =======================================================================
%%  4. Saving to hard disk
%   =======================================================================
          
    save(fullfile(folder_download, 'Str_Corporates'), 'DKK_Nykredit', '-append');
    
    if strcmp(source, 'BDL') || strcmp(source, 'BRF')
        % Write imported data to an Excel workbook for validation purposes
        writeImportDataToExcel(config, V1C_new_dates(1), ...
            V1C_new_dates(end), 'DKK');
    end
end