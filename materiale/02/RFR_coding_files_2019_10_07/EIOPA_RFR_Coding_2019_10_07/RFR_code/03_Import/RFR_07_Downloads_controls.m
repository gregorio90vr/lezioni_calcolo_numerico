function  RFR_07_Downloads_controls(config, date_calc) 


%%  EXPLANATION OF THIS FUNCTION
%   -----------------------------------------------------------------------

%   This function monitors whether the market data downloaded
%   may include non plausible data(e.g. due to IT failures)

%   The outputs are written in excel file 'RFR_Downloads_controls'


        
%  ========================================================================
%%  1. Load of necessary variables into the workspace
%  ========================================================================

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_SWPGVT = config.RFR_Str_lists.Str_numcol_curncy.SWP_GVT;
    col_CRA_IBOR_rate = config.RFR_Str_lists.Str_numcol_curncy.CRA_IBOR_rate;
    col_CRA_OIS_rate = config.RFR_Str_lists.Str_numcol_curncy.CRA_OIS_rate;
    
    %   number of the column in cell array
    %   'config.RFR_Str_lists.C2D_list_curncy'  containing ISO3166 and ISO4217
    %   for each of the currencies / countries considered

    
    load(fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'RFR_basic_curves'))
    
    load(fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'RFR_CRA'))
    
    load(fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'Str_Corporates'))
    
                    
    VecRow_terms = 1:60;
    
    validationFile = fullfile(config.RFR_Str_config.folders.path_RFR_03_Import, ...
                            'RFR_Downloads_controls.xlsx');
                        
    validationDays = config.refDate - config.startDate + 1;

%  ========================================================================
%%  2. Creating 3-D matrix to store results for each currency and maturity
%  ========================================================================

    V1C_countries_codes = config.RFR_Str_lists.C2D_list_curncy(:,col_ISO4217);
    num_countries = size(config.RFR_Str_lists.C2D_list_curncy, 1); 
    num_statistics = 3;    
    num_terms = length(VecRow_terms);

    M3D_Downloads_controls = zeros(num_countries, num_terms, num_statistics);

    message= 'Calculating plausibility control of downloaded data ';   
    mssge_wait_bar = waitbar(0.2, message);
   
    % Write the number of days used for the validation to the Excel file
    xlswrite(validationFile, validationDays, 'Swaps_1', 'B6');
    
%  ========================================================================
%%  3. Loop for swaps curves
%  ========================================================================


    for run_country = 1:num_countries
                
        if run_country > 1  && strcmp('EUR', V1C_countries_codes(run_country))
            % no calculation for the concrete countries of Euro area
            % only first run calculation for the Euro as a whole 
            continue
        end
        
        % Ignore countries with only GVT curves
        if strcmp(config.RFR_Str_lists.C2D_list_curncy(run_country,col_SWPGVT), 'GVT')
            continue
        end
        
        name_curve = strcat(V1C_countries_codes{run_country}, ...
                             '_RAW_SWP_BBL');

        if ~strcmp(fieldnames(RFR_download_BBL_Mid), name_curve)
            continue
        end
        
        M2D_download = RFR_download_BBL_Mid.(name_curve);

        rows_to_use =(M2D_download(:,1) <= date_calc)  &  ...
                     (M2D_download(:,1) >= date_calc - validationDays);
        
        dltPoints = logical(cell2mat(config.RFR_basic_ADLT_SWP(run_country,11:end)));
        
        % Determine the quartiles per maturity of the daily differences in 
        % order to estimate outliers out of quartile +/- 3 * interquartile
        % range
        rates = M2D_download(~rows_to_use,2:end);
        
        if size(rates, 1) >= 760
            rates = rates((end-759):end,:);
        end
        
        rates(rates == 0) = NaN;
        dr = diff(rates, 1, 1);
        
        quart75 = prctile(dr(:,dltPoints), 75, 1);
        quart25 = prctile(dr(:,dltPoints), 25, 1);
        
        iqr = quart75 - quart25;
        
        upperBound = quart75 + 3*iqr;
        lowerBound = quart25 - 3*iqr;
        
        M2D_download = M2D_download(rows_to_use, 2:end);
        
        
        %   Control 1. Number of dates with no market data
        %   -----------------------------------------------------------
        M3D_Downloads_controls(run_country,dltPoints,1) = ...
                                        sum((M2D_download(:,dltPoints) == 0), 1);

                                    
        %   Control 2. Successive dates with the same rates (no change)
        %   -----------------------------------------------------------
        M3D_Downloads_controls(run_country,dltPoints,2) = ...
                        sum((diff(M2D_download(:,dltPoints), 1, 1) == 0), 1);

                            
        %   Control 3. Number of outliers (outside 3*IQR of QRT 1 and 3)
        %   ---------------------------------------------------------------
        M3D_Downloads_controls(run_country,dltPoints,3) = ...
                      sum(diff(M2D_download(:,dltPoints), 1, 1) > upperBound | ...
                          diff(M2D_download(:,dltPoints), 1, 1) < lowerBound);
                       
    end
 
    %   Output of the results to Excel 
    %   -------------------------------------------------------------------
    close(mssge_wait_bar) 

    message= { ['Writing control for swap mid rates in Excel file ', validationFile]};   
    mssge_wait_bar = waitbar(0.4, message);

    
    for k = 1:3

        switch k
            case 1
                sheet_to_write = 'Swaps_1';
            case 2
                sheet_to_write = 'Swaps_2';
            case 3
                sheet_to_write = 'Swaps_3';
        end
                
        range_to_write = calcexcelrange(11, 3, num_countries, num_terms);
                        
        xlswrite(validationFile, M3D_Downloads_controls(:,:,k),...
                  sheet_to_write, range_to_write);

        range_to_write = calcexcelrange(11, 2, num_countries, 1);

        xlswrite(validationFile, config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166) , ...
                  sheet_to_write, range_to_write);

        range_to_write = calcexcelrange(9, 3, 1, num_terms);

        xlswrite(validationFile, VecRow_terms, ...
                  sheet_to_write, range_to_write);
    end
    
    
    
%  ========================================================================
%%  4. Loop for government curves
%  ========================================================================
    for run_country = 1:num_countries

        name_curve = strcat(V1C_countries_codes{run_country}, ...
                             '_RAW_GVT_BBL');

        if ~strcmp(fieldnames(RFR_download_BBL_Mid), name_curve)           
            continue
        end
        
        dltPoints = logical(cell2mat(config.RFR_basic_ADLT_GVT(run_country,11:end)));
         
        M2D_download = RFR_download_BBL_Mid.(name_curve);

        rows_to_use =(M2D_download(:,1) <= date_calc)  &  ...
                     (M2D_download(:,1) >= date_calc - validationDays);
                     
        % Determine the quartiles per maturity of the daily differences in 
        % order to estimate outliers out of quartile +/- 3 * interquartile
        % range
        rates = M2D_download(~rows_to_use,2:end);
        
        if size(rates, 1) >= 760
            rates = rates((end-759):end,:);
        end
        
        rates(rates == 0) = NaN;
        dr = diff(rates, 1, 1);
        
        quart75 = prctile(dr(:,dltPoints), 75, 1);
        quart25 = prctile(dr(:,dltPoints), 25, 1);
        
        iqr = quart75 - quart25;
        
        upperBound = quart75 + 3*iqr;
        lowerBound = quart25 - 3*iqr;
        
        
        M2D_download = M2D_download(rows_to_use, 2:end);
        
        %   Control 1. Number of dates with no market data
        %   -----------------------------------------------------------
        M3D_Downloads_controls(run_country,dltPoints,1) = ...
                                        sum((M2D_download(:,dltPoints) == 0), 1);

                                    
        %   Control 2. Successive dates with the same rates(no change)
        %   -----------------------------------------------------------
        M3D_Downloads_controls(run_country,dltPoints,2) = ...
                        sum((diff(M2D_download(:,dltPoints), 1, 1) == 0), 1);

     
        %   Control 3. Number of outliers (outside 3*IQR of QRT 1 and 3)
        %   ---------------------------------------------------------------
        M3D_Downloads_controls(run_country,dltPoints,3) = ...
                      sum(diff(M2D_download(:,dltPoints), 1, 1) > upperBound | ...
                          diff(M2D_download(:,dltPoints), 1, 1) < lowerBound);

                        
    end

    
    %   Output of the results to Excel
    %   -------------------------------------------------------------------

    close(mssge_wait_bar) 

    message= { ['Writing control for government bond rates in Excel file ' , validationFile]};   
    mssge_wait_bar = waitbar(0.6, message);

    
    for k = 1:3

        switch k
            case 1
                sheet_to_write = 'Govts_1';
            case 2
                sheet_to_write = 'Govts_2';
            case 3
                sheet_to_write = 'Govts_3';
        end
                
        range_to_write = calcexcelrange(11, 3, num_countries, num_terms);
                        
        xlswrite(validationFile, M3D_Downloads_controls(:,:,k) ,...
                  sheet_to_write, range_to_write);

        range_to_write = calcexcelrange(11, 2, num_countries, 1);

        xlswrite(validationFile, config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166), ...
                  sheet_to_write, range_to_write);

        range_to_write = calcexcelrange(9, 3, 1, num_terms);

        xlswrite(validationFile, VecRow_terms, ...
                  sheet_to_write, range_to_write);

    end
  
    
    
%  ========================================================================
%%  5. Loop for corporate curves
%  ========================================================================

    C1C_corps_names_curves = sort(fieldnames(Str_Corporates_iBoxx_Bid));

    num_corps = length(C1C_corps_names_curves);
    
    VecRow_terms = 1:6;
    num_terms = length(VecRow_terms);
    
    M3D_Downloads_controls = zeros(num_corps, num_terms, num_statistics);

    
    for run_corps = 1:num_corps   % = length(C1C_corps_names_curves)
                
        
        name_curve = C1C_corps_names_curves{run_corps};
        
        M2D_download = Str_Corporates_iBoxx_Bid.(name_curve);

        rows_to_use =(M2D_download(:,1) <= date_calc)  &  ...
                     (M2D_download(:,1) >= date_calc - validationDays);

        % Determine the quartiles per maturity of the daily differences in 
        % order to estimate outliers out of quartile +/- 3 * interquartile
        % range
        rates = M2D_download(~rows_to_use,2:end);
        
        % Consider ~3 years of data
        if size(rates, 1) >= 760
            rates = rates((end-759):end,:);
        end
        
        rates(rates == 0) = NaN;
        dr = diff(rates, 1, 1);
        
        quart75 = prctile(dr, 75, 1);
        quart25 = prctile(dr, 25, 1);
        
        iqr = quart75 - quart25;
        
        upperBound = quart75 + 3*iqr;
        lowerBound = quart25 - 3*iqr;
        
        M2D_download = M2D_download(rows_to_use,2:end);
        
        
        %   Control 1. Number of dates with no market data
        %   -----------------------------------------------------------
        M3D_Downloads_controls(run_corps,:,1) = ...
                                        sum((M2D_download == 0), 1);

                                    
        %   Control 2. Successive dates with the same rates(no change)
        %   -----------------------------------------------------------
        M3D_Downloads_controls(run_corps,:, 2) = ...
                        sum((diff(M2D_download, 1, 1) == 0), 1);

                            
        %   Control 3. Maximum variations among sucessive dates
        %   -----------------------------------------------------------          
        M3D_Downloads_controls(run_corps,:,3) = ...
                      sum(diff(M2D_download, 1, 1) > upperBound | ...
                          diff(M2D_download, 1, 1) < lowerBound);
                      
    end     % this refers to the loop for each currency

    
    %   Output of the results to Excel
    %   -------------------------------------------------------------------

    close(mssge_wait_bar) 

    message= { ['Writing control for corporate bond rates in Excel file ', validationFile]};   
    mssge_wait_bar = waitbar(0.8, message);

    
    for k = 1:3

        switch k
            case 1
                sheet_to_write = 'Corps_1';
            case 2
                sheet_to_write = 'Corps_2';
            case 3
                sheet_to_write = 'Corps_3';
        end
                
        range_to_write = calcexcelrange(11, 3, num_corps, num_terms);
                        
        xlswrite(validationFile, M3D_Downloads_controls(:,:,k) ,...
                  sheet_to_write, range_to_write);

        range_to_write = calcexcelrange(11, 2, num_corps, 1);

        xlswrite(validationFile, C1C_corps_names_curves, ...
                  sheet_to_write, range_to_write);

        range_to_write = calcexcelrange(9, 3, 1, num_terms);

        xlswrite(validationFile, VecRow_terms, ...
                  sheet_to_write, range_to_write);

    end

    close(mssge_wait_bar);
     
%  ========================================================================
%%  6. CRA Rates
%  ========================================================================
    % Determine the currencies with IBOR & OIS rates according to the DLT
    % assessment.
    ibor = config.RFR_Str_lists.C2D_list_curncy(:,col_CRA_IBOR_rate);
    ois = config.RFR_Str_lists.C2D_list_curncy(:,col_CRA_OIS_rate);
    % Replace '[]' by empty strings
    ibor = strrep(ibor, '[]', '');
    ois = strrep(ois, '[]', '');
    
    idxCRA = cellfun(@(x) ~isempty(x), ibor) & ...
        cellfun(@(x) ~isempty(x), ois);
    craCurrencies = config.RFR_Str_lists.C2D_list_curncy(idxCRA,col_ISO4217);
    
    craDates = M3D_CRA_BBL(:,1,1);
    marketData = M3D_CRA_BBL(:,[false;idxCRA],:);
     
    % Filter the data under consideration
    controlRows = (craDates <= date_calc)  &  ...
                     (craDates >= date_calc - validationDays);
                 
    % Number of days with no market data
    numZerosIBOR = sum(marketData(controlRows,:,1) == 0, 1)';
    numZerosOIS = sum(marketData(controlRows,:,2) == 0, 1)';
        
    % Outlier detection
    if size(marketData, 1) >= 760
        marketData = marketData((end-759):end,:,:);
        controlRows = controlRows((end-759):end,:,:);
    end

    marketData(marketData == 0) = NaN;
    
    outliers = zeros(length(craCurrencies), 2);
    
    for i=1:2
        dr = diff(marketData(:,:,i), 1, 1);

        quart75 = prctile(dr, 75, 1);
        quart25 = prctile(dr, 25, 1);

        iqr = quart75 - quart25;

        upperBound = quart75 + 3*iqr;
        lowerBound = quart25 - 3*iqr;
        
        
        outliers(:,i) = sum(diff(marketData(controlRows,:,i), 1, 1) > upperBound | ...
                            diff(marketData(controlRows,:,i), 1, 1) < lowerBound);
                      
    end

    message = {['Writing control for the CRA in Excel file ',validationFile]};   
    mssge_wait_bar = waitbar(0.8, message);
    
    % Write the currencies under consideration to the currency column
    range_to_write = calcexcelrange(11, 2, length(craCurrencies), 1);
    xlswrite(validationFile, craCurrencies,...
              'CRA_1', range_to_write);
    xlswrite(validationFile, craCurrencies,...
              'CRA_2', range_to_write);
   
    % Write the number of dates without market data
    range_to_write = calcexcelrange(11, 3, length(craCurrencies), 1);
    xlswrite(validationFile, numZerosIBOR,...
              'CRA_1', range_to_write);
    range_to_write = calcexcelrange(11, 4, length(craCurrencies), 1);
    xlswrite(validationFile, numZerosOIS,...
              'CRA_1', range_to_write);
          
    % Write the outliers to the CRA_2 sheet
    range_to_write = calcexcelrange(11, 3, length(craCurrencies), 1);
    xlswrite(validationFile, outliers(:,1),...
              'CRA_2', range_to_write);
    range_to_write = calcexcelrange(11, 4, length(craCurrencies), 1);
    xlswrite(validationFile, outliers(:,2),...
              'CRA_2', range_to_write);
    
    
    close(mssge_wait_bar);
    
% =========================================================================
%%  7. DKK
% =========================================================================
    dkkData = DKK_Nykredit.M2D_DKK_Nykredit;
    controlRows = (dkkData(:,1) <= date_calc)  &  ...
                     (dkkData(:,1) >= date_calc - validationDays);
    
    numZerosDKK = sum(dkkData(controlRows,2) == 0);
    numSameRates = sum(diff(dkkData(controlRows,2)) == 0);
    
    if size(dkkData, 1) >= 760
        dkkData = dkkData((end-759):end,:);
        controlRows = controlRows((end-759):end,:);
    end

    dkkData(dkkData == 0) = NaN;
    
    dr = diff(dkkData(:,2), 1, 1);

    quart75 = prctile(dr, 75, 1);
    quart25 = prctile(dr, 25, 1);

    iqr = quart75 - quart25;

    upperBound = quart75 + 3*iqr;
    lowerBound = quart25 - 3*iqr;

    outliers = sum(diff(dkkData(controlRows,2), 1, 1) > upperBound | ...
                      diff(dkkData(controlRows,2), 1, 1) < lowerBound);
    
    message = {['Writing control for DKK data in Excel file ',validationFile]};   
    mssge_wait_bar = waitbar(0.8, message);
    
    range_to_write = calcexcelrange(11, 3, 1, 1);
    xlswrite(validationFile, numZerosDKK,...
              'DKK', range_to_write);
    range_to_write = calcexcelrange(11, 4, 1, 1);
    xlswrite(validationFile, numSameRates,...
              'DKK', range_to_write);
    range_to_write = calcexcelrange(11, 5, 1, 1);
    xlswrite(validationFile, outliers,...
              'DKK', range_to_write);
          
    close(mssge_wait_bar) 

end