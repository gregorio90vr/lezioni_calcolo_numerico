function [V1C_ECB_dates,M2D_ECB_rates] = ...
    RFR_03A_Import_ECB_Excel(importPath)

%   =======================================================================
%   2. Reading ECB data form excel file and preparing for import to MatLab
%   =======================================================================

    ecbFile = fullfile(importPath, 'ECB_yc_ALL_sr.xlsx');
    
    if ~exist(ecbFile, 'file')
        info_message = [ecbFile ...
                'doesn''t exist. NO DATA TO IMPORT FOR ECB RATES'];            
                             
        RFR_log_register('01_Import', '03A_Download', 'ERROR',...
            info_message, RFR_config_mat_file);
        return
    end
    
    [M2D_ECB_rates,C2D_ECB_dates] = xlsread(ecbFile, 'yc_ALL_sr', 'A10:FZ10000');
    
    
    C1C_ECB_dates = C2D_ECB_dates(:,1);  
    
    % only first column relevant - it containes dates  
    clear C2D_ECB_dates
   
    M2D_ECB_rates(isnan(M2D_ECB_rates)) = 0;
    
   
    % ECB rates are provided split into two crunches
    
    %   from 3M to 14Y-11M maturity and below. This set has 181 columns
    %   but only 177 with data, being the four last ones with zeros
    
    %   from 15Y to 30Y maturity. This second set has 181 columns
    
    %   M2D_ECB_rates contains both sets but the second after the first
    
    
    % Identifying the first and last rows for each of the two sets
    %   ECB data serie starts  06/09/2004
        
    first_row_set1 = find(strcmp('06/09/2004', C1C_ECB_dates(:,1)), 1, 'first');
    first_row_set2 = find(strcmp('06/09/2004', C1C_ECB_dates(:,1)), 1, 'last');

    last_row_set1 = find(strcmp('', C1C_ECB_dates(first_row_set1:end,1)),...
        1, 'first') - 1;
    last_row_set2 = first_row_set2 +(last_row_set1 - first_row_set1);

    % ECB rates are provided split into two crunches
    
    %   from 3M to 14Y-11M maturity and below. This set has 181 columns
    %   but only 177 with data, being the four last ones with zeros
    
    %   from 15Y to 30Y maturity. This second set has 181 columns
    
    %   Before the following instruction
    %   M2D_ECB_rates contains both sets but the second after the first
  
    M2D_ECB_rates = [ M2D_ECB_rates(first_row_set1 : last_row_set1 , 1:177) , ...
                      M2D_ECB_rates(first_row_set2 : last_row_set2 , :) ];

    M2D_ECB_rates = M2D_ECB_rates(:,10:12:end);
    
    %   transforming intensity spot rates in annual spot rates
    M2D_ECB_rates = 100 * exp(M2D_ECB_rates/100) - 100;

    % ECB rates are intensities, while EIOPA process uses annual spot rates
    % Furthermore, ECB rates are percentages(hence the \100 and *100)
    V1C_ECB_dates = datenum(C1C_ECB_dates(first_row_set1:last_row_set1), 'dd/mm/yyyy');
    
end