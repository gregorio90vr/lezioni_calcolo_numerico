function [V1C_dates_new,M3D_rates_new_download] = ...
    RFR_01_Downloads_CRA_BBL(config, source, settings)


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

%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------

%  ------------------------------------------------------------------------
%%  1. Preparation of the workspace
%   -----------------------------------------------------------------------


    %   1.A. Loading variables common to following steps in this function
    %   -------------------------------------------------------------------

    col_ISO4217      = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_CRA_IBOR_rate = config.RFR_Str_lists.Str_numcol_curncy.CRA_IBOR_rate;
    col_CRA_OIS_rate = config.RFR_Str_lists.Str_numcol_curncy.CRA_OIS_rate;
    
        %   number of the column in cell array
        %   'config.RFR_Str_lists.C2D_list_curncy'  containing ISO4217 and
        %   Bloomberg tickers for swap and OIS rates used in CRA
        %   calculation for each of the currencies / countries considered
        
    num_countries  = size(config.RFR_Str_lists.C2D_list_curncy, 1);

    
    %   1.B.    Loading the historical data already stored in MatLab   ----
    %   -------------------------------------------------------------------
   
    
        %   ' M3D_RFR_CRA_BBL ' is a 3-dimensional matrix
        %   stored in MatLab 'mat' file  ' RFR_CRA.mat ' 
        %   The 3-dimensions are
        %       rows    = dates of observation
        %       columns = dates + one column per country/currency
        %       pannels = first pannel IBOR rates, second O/N rates

        
    % In case of 'BDL', download and decrypt the files
    if strcmp(source, 'BDL')
       settings = downloadBDLOutput(settings, settings.outputfiles.CRA, ...
           settings.dlPath, 10);        
        settings = char(settings);
    end
    
    bblData = parseBDLHistory(bdlloader(settings), 'weekdays');

    V1C_dates_new = datenum(bblData.Date);
    
    %  1.D. New market data in the excel file will be imported to 
    %       a 3-D MatLab matrix created with this instruction
    %  ----------------------------------------------------------------
            
    M3D_rates_new_download = zeros(length(V1C_dates_new), num_countries + 1, 2);
    M3D_rates_new_download(:,1,1) = V1C_dates_new;
    M3D_rates_new_download(:,1,2) = V1C_dates_new;
    
            %   3-dimensional matrix where
            %       rows      = dates downloaded
            %       columns   = first column contains dates, 
            %                   rest of columns country/currencies
            %       2-pannels = first pannel IBOR rates, 
            %                   second pannel O/N

 
        
%  ------------------------------------------------------------------------
%%  2. Loop for each country/currency
%  ------------------------------------------------------------------------

    for counter_country = 1:num_countries 
            
        % Countries of the euro zone                                   
        if (counter_country > 1) && ...
                strcmp(config.RFR_Str_lists.C2D_list_curncy(counter_country, col_ISO4217), 'EUR')
               %    country belonging to the euro zone
               
               %    first run is  'Euro'  in general and it is stored
               %    in column 2 (first column contains dates)
               
            M3D_rates_new_download(:,counter_country+1,:) = ...
                                    M3D_rates_new_download(:,2,:);                      
            continue
        end

        %   Control of whether the index IBOR for the currency of the run
        %   has been downloaded

        CRA_swap_id = config.RFR_Str_lists.C2D_list_curncy{counter_country,col_CRA_IBOR_rate};
                 
        num_col_swp = find(strcmpi(...
            strrep(bblData.Properties.VariableNames, '_', ' '), CRA_swap_id));
        
        if num_col_swp > 0            
           M3D_rates_new_download(:,counter_country+1, 1) = ...
                                   bblData{:,num_col_swp};
        end                       
 
        %   Control of whether the index overnight for currency of the run
        %   has been downloaded
        
        CRA_overnight_id = config.RFR_Str_lists.C2D_list_curncy{counter_country,col_CRA_OIS_rate};
        
        num_col_ois = find(strcmpi(...
            strrep(bblData.Properties.VariableNames, '_', ' '), CRA_overnight_id));
        
        if num_col_ois > 0
           M3D_rates_new_download(:,counter_country+1,2) = ...
                                   bblData{:,num_col_ois};
        end
    end
end