function V1C_CRA_date_calc = RFR_05_basic_CRA_calculation ...
                          (config, date_calc, ...
                            M2D_raw_curves, M2D_DLT)
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%   The output of this function is a column vector with as many rows
%   as countries/currencies considered in the calculations
%   containing the value IN UNITS (upto 2 decimals precision) of the credit risk adjustment
%   to the basic risk free interest rate term structure.
%
%   The function calculates the credit risk adjustment according to
%   the Level 2 delegated act and section 5 of the Technical Documentation.
%   

%   -----------------------------------------------------------------------
%%  1. Loading configuration and historical data on interest rates for CRA
%   -----------------------------------------------------------------------        
        

    %   Loading to workspace the configuration data
    %   -------------------------------------------    
    
    col_EEA     = config.RFR_Str_lists.Str_numcol_curncy.EEA;
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    
    countries = config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166);
    
    % Row indices of the EUR and USD CRA in the output vector
    % V1C_CRA_date_calc needed for special cases.
    row_EUR = find(strcmp(countries, 'EUR'), 1);
    row_USD = find(strcmp(countries, 'USD'), 1);
                
    %   number of the column in cell array
    %   'RFR_Str_lists.C2D_list_curncy'  containing 
    %   for each of the currencies / countries considered
    %   whether the basic RFR is based on swaps/government bond rates,
    %   and whether the country belongs to the EEA or not.

    %   Loading to workspace market data inputs for CRA calculation
    %   -----------------------------------------------------------
        
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    file_mat_storage = 'RFR_CRA';
    
    load(fullfile(folder_download, file_mat_storage));  
         
    M3D_CRA_complete = M3D_CRA_BBL;
    M3D_CRA_complete(isnan(M3D_CRA_complete)) = 0;
    
   %    M3D_CRA_BBL is a 3-D matrix with
   %        rows containing dates of market observation
   %            (market data are captured on daily basis)
   %        first column the date in MatLab format number
   %        second to end columns: each country/currency
   %            (including a column per each country of Euro zone)
   %        first panel IBOR rates and second panel OIS rates)
    

    
%   -----------------------------------------------------------------------
%%  2. Selecting data referred only to last year and disregarding the rest
%      (according to the formula set out in the Level 2 Delegated Act)
%   -----------------------------------------------------------------------        


    %   Identifying the row of the 3-D matrix with market rates 
    %   for the date of calculation (newest data to consider)

    if month(date_calc) == 2 && day(date_calc) == 29
        date_ini_CRA = datenum(year(date_calc)-1, month(date_calc), day(date_calc));
    else
        date_ini_CRA = datenum(year(date_calc)-1, month(date_calc), day(date_calc)+1);
    end

    row_date_calc = find(M3D_CRA_complete(:,1,1) <= date_calc, 1, 'last');
    
    if isempty(row_date_calc)
        row_date_calc = size(M3D_CRA_complete, 3);
    end

    
    %   Identifying the date of the 3-D matrix with market rates 1 year
    %   before the date of calculation (oldest data to consider)  
    row_date_ini = find(M3D_CRA_complete(:,1,1) <=  date_ini_CRA, 1, 'last');
    

    %   Counting the number of dates during last year with market rates
    %   for both swap markets and overnight swap markets   
    
    M3D_CRA_last_year = M3D_CRA_complete(row_date_ini:row_date_calc,:,:);
    
    num_rates_last_year = size(M3D_CRA_last_year,1);
    
    VecRow_dates_with_data = sum((M3D_CRA_last_year(:,2:end,1) ~= 0) .* ...
                                   (M3D_CRA_last_year(:,2:end,2) ~= 0), ...
                                    1);
    
    %   row vector, where each column refers to each country and
    %   reflects the number of dates with market data existing
    %   for both the IBOR rates and the overnight rates
    %   (before the interpolation applied in the following step)

    %   this vector will govern different alternatives for 
    %   the calculation of the credit risk adjustment
    
    
        
%   -----------------------------------------------------------------------
%%  3. Interpolation to fill in dates without market rates
%   -----------------------------------------------------------------------        
    CRA_threshold_option_1 = ... 
                    config.RFR_Str_lists.Parameters.CRA_threshold_option_1 ;    

    for counter_country = 1:size(config.RFR_Str_lists.C2D_list_curncy,1) 

        if VecRow_dates_with_data(counter_country) < ...
            CRA_threshold_option_1*num_rates_last_year                            
           continue
            
            %   CRA for these currencies caculated 
            %   either with option 2 or option 3 as described in
            %   section 5.C of the Technical Documentation
            %   (see below in this function coding sections 4.2. and 4.3)
        end
                

        for panel = 1:2   
            %   Interpolation of swap rates (panel 1) 
            %   and overnight (panel 2),... for the currency of each run
            %   -----------------------------------------------------------

            %   This interpolation is in section 4.C Technical Documentation
            %   Formal transformation for an easier notation
            
            Vector_int = M3D_CRA_complete(:,counter_country+1,panel);            
                %   Reminder: First column of 3D matrix contains dates
                %             Then it has as many columns as countries + 1


            %   if first dates are empty... first non-empty rate copied
            first_nonzero_row = find(Vector_int ~= 0,1,'first');

            if first_nonzero_row > 1
               Vector_int(1:first_nonzero_row) = ...
                            Vector_int(first_nonzero_row);
            end


            %   if last dates are empty... last non-empty rate copied
            last_nonzero_row  = find(Vector_int ~= 0,1,'last');

            if last_nonzero_row < length(Vector_int) 
                last_nonzero_rate = Vector_int(last_nonzero_row);
                Vector_int(last_nonzero_row+1:end) = last_nonzero_rate;
            end

            
            %   linear interpolation properly speaking
            nonzero_rows = (Vector_int ~= 0);

            M3D_CRA_complete(:,counter_country+1,panel) = ...
                      interp1(M3D_CRA_complete(nonzero_rows,1,panel),...
                                Vector_int(nonzero_rows), ...
                                M3D_CRA_complete(:,1,panel),'linear');
                        
        end
    end

    M3D_CRA_last_year = M3D_CRA_complete(row_date_ini:row_date_calc,:,:);

    %   'M3D_CRA_last_year'  is updated with the values including
    %   interpolated dates
 
%   -----------------------------------------------------------------------
%%  4. Calculation of the CRA for different cases
%   -----------------------------------------------------------------------        

    %   Column vector to receive the output of this function
    %   CRA expressed in units for each country (row)
                                
    V1C_CRA_date_calc = zeros(size(config.RFR_Str_lists.C2D_list_curncy,1),1);

    %  4.1. CURRENCIES WITH DLT OVERNIGHT MARKETS (SITUATION 1)
    %  ----------------------------------------------------------------        

    %   For these cases, Article 45 of Regulation 2015/35/UE and
    %   also section 5.C (first situation) of the EIOPA Technical  
    %   Documentation (as published on May 18th, 2016) apply.

    %  In the case of the Euro, all columns for the countries
    %  of the Euro zone arrive at this point with the same content
    %  and are calculated as 'if' having their own currency.
    %  ----------------------------------------------------------------
    sit1_countries = VecRow_dates_with_data >= ...
                        CRA_threshold_option_1*num_rates_last_year;
    
    info = ['CRA - Situation 1 countries: ',  ...
        strjoin(countries(sit1_countries),',')];
    RFR_log_register('04_Basic', 'RFR_05_basic_CRA', 'INFO', info, config);
    
    % Adjust for the date column in the market data and calculate the CRA
    V1C_CRA_date_calc(sit1_countries) = 0.50*mean...
        (M3D_CRA_last_year(:,[false sit1_countries],1) - ...
         M3D_CRA_last_year(:,[false sit1_countries],2));

    %  4.2. EEA Countries which are not in the first situation.
    %       (SITUATION 2)
    %       The CRA for the Euro applies.
    %  ----------------------------------------------------------------

    %   For these cases, the second situation of section 5.C of 
    %   the EIOPA Technical Documentation (as published on May 18th, 2016) 
    %   applies.

    %   Neither IBOR nor OIS rates are downloaded for those currencies/
    %   countries. Therefore, VecRow_dates_with_data(counter_country) == 0. 
    sit2_countries = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_EEA),...
            'EEA') & V1C_CRA_date_calc(:) == 0;
    
    info = ['CRA - Situation 2 countries: ',  ...
        strjoin(countries(sit2_countries),',')];
    RFR_log_register('04_Basic', 'RFR_05_basic_CRA', 'INFO', info, config);
    
    V1C_CRA_date_calc(sit2_countries) = V1C_CRA_date_calc(row_EUR);

    %  4.3. OTHER CASES (SITUATION 3)
    %  ----------------------------------------------------------------

    %   For these cases, situation 3 in section 5.C of the EIOPA  
    %   Technical Documentation (as published on May 18th, 2016)
    %   applies.
    sit3_index = find(V1C_CRA_date_calc == 0);

    info = ['CRA - Situation 3 countries: ',  ...
        strjoin(countries(sit3_index),',')];
    RFR_log_register('04_Basic', 'RFR_05_basic_CRA', 'INFO', info, config);
    
    % First we have a look where there is missing data to find the
    % non-missing data; non-missing data is a combined result from any non-missing raw rates with
    % non-missing USD-rates. Hence: the calculation is based on equal availability of rates/maturities
    % in both numerator and denominator
    V1C_non_missing_raw_rates = (M2D_raw_curves(sit3_index,1:10) ~= 0) & ...
      repmat(M2D_raw_curves(row_USD,1:10)~= 0,size(sit3_index));

    % To proceed with the calculation, we take only the non-missing rates that
    % meet the DLT requirement,cf. section 5.C of the technical documentation par. 103.
    
    V1C_rates_for_calc = M2D_DLT(sit3_index,1:10) .* ...
                  repmat(M2D_DLT(row_USD,1:10),size(sit3_index)) .* ...
                  V1C_non_missing_raw_rates;

    % If the sum of DLT USD rates is zero or negative apply special
    % CRA definition of 35 bp.
    % Note: denominator is being calculated by use of an inner product
    denominator = V1C_rates_for_calc * M2D_raw_curves(row_USD,1:10)';
    
    % Issue a warning in case the denominator is very close to 0, because
    % floating-point precision could come into play here.
    if any(abs(denominator) < 1e-5)
        warn = ['CRA - Warning: The situation three denominator is in some cases ',...
            'close to zero. Investigate possible catastrophic cancellation.'];
        warning(warn);
        
        RFR_log_register('04_Basic', 'RFR_05_basic_CRA', 'WARNING', warn, config);
    end
    
    sit3CRA = zeros(size(denominator)); % Initialisation step
    
    % 35 bps constraint for 0 or negative denominator
    sit3CRA(denominator <= 0) = 0.35;
    
    % Situation 3 calculation
    posDen_index = find(denominator > 0);
    if ~isempty(posDen_index)
        sit3Raw = M2D_raw_curves(sit3_index,1:10);

        sit3CRA(posDen_index) = V1C_CRA_date_calc(row_USD) .* ...
          sum(sit3Raw(posDen_index,:).*V1C_rates_for_calc(posDen_index,:),2) ./ ...
          denominator(posDen_index); 
    end
   
    V1C_CRA_date_calc(sit3_index) = sit3CRA;

%   -------------------------------------------------------------------
%%   5. THRESHOLDS LEVEL 2 DELEGATED ACT (applied to all currencies)
%   -------------------------------------------------------------------
   V1C_CRA_date_calc(:) = ...
       min(config.RFR_Str_lists.Parameters.CRA_corridor_upper_limit, ...
       max(config.RFR_Str_lists.Parameters.CRA_corridor_lower_limit, ...
                    V1C_CRA_date_calc(:)));

   %  According to Article 45 of Regulation 2015/35/UE
   %       RFR_Str_lists.Parameters.CRA_corridor_upper_limit = 0.35
   %       RFR_Str_lists.Parameters.CRA_corridor_lower_limit = 0.10

   %    These parameters are set out in sheet  'Parameters'
   %    of excel file   'RFR_excel_config.xlsx'
   %    and moved to  'RFR_Str_lists.Parameters'  in section 2.6
   %    at the end of function 'RFR_01_basic_setting_config.m'.

%   -------------------------------------------------------------------
%%   6. Applying a final rounding (to nearest integer)
%   -------------------------------------------------------------------
              
    V1C_CRA_date_calc = round(100*V1C_CRA_date_calc)/100;
    
%%  7 Special CRA cases

%   7.1 CRA for NORWEGIAN KRONA    
%   --------------------------------------------------------------------

    
    %   According to paragraph 104 of EIOPA Technical 
    %   Documentation as published on May 18th, 2016
    
    row_NOK = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166),'NOK');
    row_SEK = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166),'SEK');

    V1C_CRA_date_calc(row_NOK) = V1C_CRA_date_calc(row_SEK); 

    
%%  8 Currency Adjustments 
%   Currency Adjustement are changes on top of the CRA and as such
%   presented as an integral part of the CRA.
%   Example: If CRA = 35bp as result of upper bound corridor and a currency
%   adjustment of 5bp applies then a CRA of 40bp is reported (which could
%   be misleading/misinterpreted as presented as such given the upper bound
%   CRA corridor of 35bp

%   8.1 Currency Adjustment for BULGARIA, pegged to the euro
%   Calibration according to EIOPA Stress Test 2014
%   -------------------------------------------------------------------

   row_BGN = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166),'BGN');
   V1C_CRA_date_calc(row_BGN) = V1C_CRA_date_calc(row_EUR) + 0.05 ;
   
  
%  8.2 Currency Adjustment for DENMARK, pegged to the euro
%   Calibration according to EIOPA Stress Test 2014
%   ------------------------------------------------------------------- 

   row_DKK = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166),'DKK');
   V1C_CRA_date_calc(row_DKK) = V1C_CRA_date_calc(row_EUR) + 0.01; 

        