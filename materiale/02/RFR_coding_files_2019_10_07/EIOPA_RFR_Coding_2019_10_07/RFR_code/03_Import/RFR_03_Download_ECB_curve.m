function RFR_03_Download_ECB_curve(config, source) 

%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   This funtion moves to MatLab environment market data on yields of 
    %   ECB curve all governments imported in an excel file
    %   as set out in section 9.E. of EIOPA technical documentation
    %  (paragraph 241, version published October 27th, 2015)
    
    %   The function download the historical serie from the date
    %   the user will input during the execution of the function
    %  (i.e. do not preserve the historical serie)
    
    %   IMPORTANT:  The excel file should respect exactly the template
    %               and this function should be executed after having
    %               imported excel files for governments from Bloomberg.
    %               This function will override the data imported 
    %               from Bloomberg(related to ECB curve AAA) 
    
    % ECB rates are INTENSITIES and are provided split into two crunches
    
    %   from 3M to 14Y-11M maturity and below. This set has 181 columns
    %   but only 177 with data, being the four last ones with zeros
    
    %   from 15Y to 30Y maturity. This second set has 181 columns

    
       
%   =======================================================================
%%  1. Loading configuration and existing database of ECB goveernment rates
%   =======================================================================

    %   Loading to workspace the history of ECB government rates
    %   --------------------------------------------------------
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download   = 'RFR_basic_curves';           
        %   Name of the MatLab numeric 2-D matrix with the historical
        %   series of interest rates of corporate curves
        
    load(fullfile(folder_download, file_download));
        
    switch source
        case 'XLS'
            info = 'Importing ECB data from XLS.';
            RFR_log_register('01_Import', 'RFR_03_Download', 'INFO',...
                info, config); 
            
            [V1C_ECB_dates,M2D_ECB_rates] = ...
                RFR_03A_Import_ECB_Excel(folder_download);
        case 'ECB'
            info = 'Importing ECB data from the ECB API.';
            RFR_log_register('01_Import', 'RFR_03_Download', 'INFO',...
                info, config); 
            
            [V1C_ECB_dates,M2D_ECB_rates] = ...
                RFR_03B_Import_ECB_API(config);
        otherwise
            error('No ECB data source selected. Aborting!');
    end

%   =======================================================================
%%  3. Moving data to MatLab
%   =======================================================================
    
    %   Oldest date to include in the import process to MatLab
    %   Date of calculation in format 'dd/mm/yyyy' 
    % ---------------------------------------------------------------------

    oldest_date_to_import = datenum('06/09/2004', 'dd/mm/yyyy');

    % Remove dates before the first date to import from the new import data
    rowsBefore = V1C_ECB_dates < oldest_date_to_import;
    M2D_ECB_rates(rowsBefore,:) = [];
    V1C_ECB_dates(rowsBefore) = [];
    
    % Overwrite existing data
    [ia,locb] = ismember(V1C_ECB_dates, RFR_download_BBL_Mid.EUR_RAW_GVT_BBL(:,1));
    RFR_download_BBL_Mid.EUR_RAW_GVT_BBL(locb(ia),2:(size(M2D_ECB_rates, 2)+1)) = M2D_ECB_rates(ia,:);
    
    % Extend the array with new data (if there is new data)
    if any(~ia)
        extension = zeros(sum(~ia), size(RFR_download_BBL_Mid.EUR_RAW_GVT_BBL, 2));
        extension(:,1:(1+size(M2D_ECB_rates, 2))) = [V1C_ECB_dates(~ia),M2D_ECB_rates(~ia,:)];
        RFR_download_BBL_Mid.EUR_RAW_GVT_BBL = ...
            [RFR_download_BBL_Mid.EUR_RAW_GVT_BBL;extension];
        RFR_download_BBL_Mid.EUR_RAW_GVT_BBL = sortrows(RFR_download_BBL_Mid.EUR_RAW_GVT_BBL);
        
    end       
    
     save(fullfile(folder_download, 'RFR_basic_curves'), 'RFR_download_BBL_Mid',...
         '-append');
     
    % Write imported data to an Excel workbook for validation purposes
    writeImportDataToExcel(config, oldest_date_to_import, ...
        V1C_ECB_dates(end), 'ECB');
    
     save(fullfile(folder_download, 'RFR_basic_curves'), 'RFR_download_BBL_Mid',...
         '-append');
     