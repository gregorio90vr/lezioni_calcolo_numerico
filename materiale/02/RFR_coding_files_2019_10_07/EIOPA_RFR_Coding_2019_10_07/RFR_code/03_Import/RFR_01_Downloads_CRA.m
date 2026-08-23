function RFR_01_Downloads_CRA(config, source, settings)

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%   This function imports to MatLab
%   daily data from financial markets regarding the two following 
%   financial references set out in Level 2 Delegated Act

%       (a) IBOR fixing for swaps of each country/currency

%       (b) Fixed rate of Overnight swaps to the same term as IBOR fixing
%           (except for the euro, where the comparison is
%             Euribor 03M versus O/N 3 months instead of using 6 months)

%   Data from financial markets should be previously downloaded in
%   the excel sheet    'Download_CRA.xlsx'   

%   This function passes such data to a 3-D MatLab matrix,
%        M3D_CRA_BBL  for data from Bloomberg
%   
%   adding new data downloaded from Bloomberg
%   to the historical series stored in those 3-D matrices

        %   ' M3D_RFR_CRA_BBL ' is a 3-dimensional matrix
        %   stored in MatLab 'mat' file  ' RFR_CRA.mat ' 
        %   The 3-dimensions are
        %       rows    = dates of observation
        %       columns = dates + one column per country/currency
        %       pannels = first pannel IBOR rates, second O/N rates
        
%   If there are data for the same date in 
%   both the historical serie and the new downloaded data, 
%   the first ones are removed and the latter one are added
%       (new data override old data for the same date)

%   The function has the following sections

%       Section 1.- Preparing the workspace with inputs needed later
%                   and reading of the excel file with the new market data
%
%       Section 2.- Loop with as many runs as currencies/countries
%                   where data read from the excel file are identified
%                   and approrpiately stored
%
%       Section 3.- Merging new market data and data previously stored
%                   In case of dates in both sides, old data are removed

%   The results are saved in the hard disk in a file named
%       'RFR_CRA.mat' in a 3-D matrix named  M3D_RFR_CRA_BBL

% INPUTS
%   RFR_config_mat_file - path to the RFR config file
%   source - char array, either 'XLS' for Excel as a data source, 'BRF' for
%            Bloomberg request output files or 'BDL' for the Bloomberg DL 
%            FTP server.
%   settings - if the data source is either 'BRF' or 'BDL', settings should
%              contain the output struct (settings) of
%              RFR_00B_BBL_settings.
%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------

    if ~ismember(source, {'XLS','BDL','BRF', 'DSS'})
      info_message = 'The source selected for this function is not available. CRA import can not be executed';     
      RFR_log_register('01_Import', 'RFR_01_Download', 'ERROR', info_message,...
          config);
            
      return
    end
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    file_mat_storage    = 'RFR_CRA';
    load(fullfile(folder_download, file_mat_storage), 'M3D_CRA_BBL');

    %   'M3D_RFR_CRA_BBL' is a 3-dimensional matrix
    %   stored in MatLab 'mat' file  ' RFR_CRA.mat ' 
    %   The 3-dimensions are
    %       rows    = dates of observation
    %       columns = dates + one column per country/currency
    %       panels = first panel IBOR rates, second O/N rates
    M3D_CRA_storage = M3D_CRA_BBL;

    switch source
        case 'XLS'
            info = 'Importing CRA data from XLS.';
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [V1C_dates_new,M3D_rates_new_download] = ...
                RFR_01_Downloads_CRA_Excel(config);
        case 'BDL'
            info = 'Importing CRA data from BBL Data License.';
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [V1C_dates_new,M3D_rates_new_download] = ...
                RFR_01_Downloads_CRA_BBL(config, source, settings);
        case 'BRF'
            info = 'Importing CRA data from BBL request output files.';
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [V1C_dates_new,M3D_rates_new_download] = ...
                RFR_01_Downloads_CRA_BBL(config, source, settings.CRA);
        case 'DSS'
            info = 'Importing CRA data from the DSS API.';
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [V1C_dates_new,M3D_rates_new_download] = ...
                RFR_01A_Downloads_CRA_REF(config, settings);           
    end

    %  ----------------------------------------------------------------
    %%  2.C. Merging old data and new data and saving in hard disk
    %        In case of same dates, data already stored are removed 
    %  ----------------------------------------------------------------           

    nCountries  = size(config.RFR_Str_lists.C2D_list_curncy, 1);
    
    V1C_dates_storage = M3D_CRA_storage(:,1,1);
    
    V1C_dates_complete = unique([V1C_dates_storage;V1C_dates_new]);

    M3D_complete = zeros(length(V1C_dates_complete), nCountries + 1, 2);
    
    earliest_date_new = min(V1C_dates_new);
    latest_date_new = max(V1C_dates_new);
    
    M3D_complete(:,:,1) = ...
       [M3D_CRA_storage((V1C_dates_storage < earliest_date_new),:,1); ...
         M3D_rates_new_download(:,:,1);...
         M3D_CRA_storage((V1C_dates_storage > latest_date_new),:,1)];
     
    M3D_complete(:,:,2) = ...
       [M3D_CRA_storage((V1C_dates_storage < earliest_date_new ),:,2); ...
         M3D_rates_new_download(:,:,2);...
         M3D_CRA_storage((V1C_dates_storage > latest_date_new ),:,2)]; 
                                                

   M3D_CRA_BBL = M3D_complete;                     
   M3D_CRA_BBL(isnan(M3D_CRA_BBL))= 0;

   save(fullfile(folder_download, file_mat_storage), 'M3D_CRA_BBL', '-append');

   if ismember(source, {'BDL','BRF','DSS'})
        % Write imported data to an Excel workbook for validation purposes
        writeImportDataToExcel(config, V1C_dates_new(1), ...
            V1C_dates_new(end), 'CRA');
   end
end