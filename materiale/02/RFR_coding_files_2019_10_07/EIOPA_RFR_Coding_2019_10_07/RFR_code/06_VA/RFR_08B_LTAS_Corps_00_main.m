function [Str_LTAS] = RFR_08B_LTAS_Corps_00_main ...
                           (config, date_calc, Str_LTAS, k_factor) 
         
 
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   Main references sections 10 and 12 of EIOPA Technical Documentation
    
    %   This funtion delivers the calculation of long term average spread 
    %   for corporate bonds as of the date of calculation of the VA
    
    %   The output is MatLab structure  'Str_LTAS_Govts'   
    %   which contains four 2-dimensional matrices

    %       M2D_corps_LTAS_spreads_raw, 
    %           with the pure long term average
    
    %       M2D_corps_LTAS_counter, 
    %           with the number of dates considered with non zero rates in 
    %           both corporate bonds curves and the basic-risk free curves
                  
    %       M2D_corps_LTAS_spreads_rec, 
    %           with the average spreads after reconstruction of the
    %           historical series
    %           Only from 1-1-2016 onwards this matrix will be different
    %           from matrix M2D_corps_LTAS_spreads_raw
    
    %       M2D_corps_LTAS_first_dates, 
    %           with the first date with data in the historical series
    %           for each currency and each maturity
    
    %   Each matrix has 60 columns with the output for maturities 1 to 60
    %   Rows refer to each country/currency as in the structure
    %       config.RFR_Str_lists.C2D_list_curncy (column 3)
   
    
  
       
%   ========================================================================================
%%  1. Loading configuration data and history of basic risk-free curves and corporate curves   
%   ========================================================================================
        
    %   Loading to workspace corporate bonds curves
    %   -------------------------------------------   
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'Str_Corporates'; 
    
        %   Name of the MatLab structure with all historical series
        %   of interest rates for corporate bonds 
        %   Each serie is a 2-dimensional matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));
    
    
    
    %   Loading to workspace history of basic risk-free curves
    %   ------------------------------------------------------    
    folder_download = config.RFR_Str_config.folders.path_RFR_05_LTAS;    
    file_download = 'Str_History_basic_RFR';   
    
        %   Name of the MatLab structure with the historical
        %   series of basic risk-free interest rates
        %  (all extrapolated for each date and currency with S-W method)
        %   Each serie is a 2-dimensional matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));
     

    
    %   Loading to workspace LTAS as of 31-12-2015
    %   ----------------------------------------------------------  
    
    folder_download = config.RFR_Str_config.folders.path_RFR_06_VA;    
    file_download = 'Str_LTAS_YE2015';   
    
        %   Name of MatLab structure with the long term average spreads
        %   as of 31-12-2015.
        %   This information is used in the reconstruction of the LTAS
        %   developed at the end of this function from 1-1-2016 onwards
	    
    load(fullfile(folder_download, file_download)); 

   date_change_method_LTAS = datenum('31/12/2015', 'dd/mm/yyyy');
    
        %   the coding will run differently depending on whether 
        %   the date of calculation is previous or posterior to 31/12/2015
     
 
    %   Identification of the rows to use in the calculation
    %   based on the History of basic RFR curves
    %   -------------------------------------------------------------------
    
    if date_calc <= date_change_method_LTAS
        
       rows_to_use  =(Str_History_basic_RFR.EUR_RFR_basic_spot(:, 1) <= date_calc);             
            %  'rows_to_use' is a logical vector with 1 for those rows
            %  where the date is <= than the date of calculation
 
    else

       rows_to_use  =(Str_History_basic_RFR.EUR_RFR_basic_spot(:, 1) <= date_calc)  &  ...
                     (Str_History_basic_RFR.EUR_RFR_basic_spot(:, 1) > date_change_method_LTAS);             
            %  'rows_to_use' is a logical vector with 1 for those rows
            %  where: date_change_method_LTAS < selected row dates <= date of calculation
    end
    
      
    
    
%   =======================================================================
%%  2. Preparation of empty variables to receive results   
%   =======================================================================

    %   Creation of the matrices for storing the results

    num_corps = size(config.RFR_Str_lists.C2D_list_corporates, 1);
    
        %   'config.RFR_Str_lists.C2D_list_corporates' is a cell array column
        %   with 14 rows per currency, containing the name of 
        %   the corporate yield indices for the 7 credit quality steps
        %   and for financial and non-financial sectors
        %   Rows 1-7 for each currency refers to financial bonds 
        %   while rows 8-14 refer to non-financial bonds
        
        %   In this version this cell array contains 42 rows
        %  (14 rows per Euro, GBP and USD)
    
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw = zeros(num_corps, 60);
    Str_LTAS.Corps.M2D_corps_LTAS_counter     = zeros(num_corps, 60);
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec = zeros(num_corps, 60);
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates = zeros(num_corps, 60);
    
    
    %       M2D_corps_LTAS_spreads_raw, with the pure long term average
    
    %       M2D_corps_LTAS_counter, 
    %           with the number of dates considered with non zero rates in 
    %           both the government curve are the basic-risk free curve
                  
    %       M2D_corps_LTAS_spreads_rec, 
    %           with the average spreads after reconstruction of the
    %           historical series
    %           Only from 1-1-2016 onwards this matrix will be different
    %           from matrix M2D_govts_LTAS_spreads_raw
    
    %       M2D_corps_LTAS_first_dates, 
    %           with the first date with data in the historical series
    %           for each currency and each maturity
    
    %   Each matrix has 60 columns with the output for maturities 1 to 60
    %   Rows refer to each country/currency as in the structure
    %       config.RFR_Str_lists.C2D_list_curncy (column 3)
       

    
%   =======================================================================
%%  3. Calculation of LTAS for each corporate bond curve   
%   =======================================================================
        
    % GBP and USD corporate curves for CQS4 and CQS5 are those of the Euro
    % The k factor should be applied after the main loop
    
    
    
    %%   3.1. Main loop for each corporate bond curve
    %   ---------------------------------------------
    
    message = { ['Calculating LTAS for corporate curves. Total of ', num2str(num_corps), ' curves. '] ; ...
               ['Date = ',  datestr(date_calc, 24)]};   

    mssge_wait_bar = waitbar(1/num_corps, message);
           

    for row_LTAS = 1:num_corps 

        waitbar(row_LTAS / num_corps)

        %   Pending of the value of  'rwo_LTAS'  
        %   the following corporate bonds are considered in each run
        
            %    1 -  7 EUR Financial  ;   8 - 14 EUR Non-financial 
            %   15 - 21 GBP Financial  ;  22 - 28 GBP Non-financial 
            %   29 - 35 USD Financial  ;  36 - 42 USD Non-financial 
            
            
        if rem(row_LTAS, 7) == 0  %||  ... %  credit quality step 6 
           
           continue
           
            % After the main loop, CQS6 will be equal to CQS5
            
        end

                
                
        %%  3.1.B.  Historical serie corporate curves for CQS each run
        %   ---------------------------------------------------------------
        
        if rem(row_LTAS, 7) == 1 % CQS=0
            %   The following  applies to the three currencies
            %   Section 12.B.1 EIOPA Technical Documentation September 2016
            %   Yields before 01/09/2016 are taken to be 0.85 * Yields CQS1
            %   Afterwards, the yields are calculated according to
            %   Yields CQS0 = Yields CQS1 - 0.15 * abs(Yields CQS1)
            
            name_corp_curve = config.RFR_Str_lists.C2D_list_corporates{row_LTAS+1};
                      
            try    
                M2D_corps_yields = ...
                    Str_Corporates_iBoxx_Bid.(strcat(name_corp_curve, '_yields'));
                
                rowsBeforeSep16 = M2D_corps_yields(:,1) < datenum(2016,9,1);
                
                M2D_corps_yields(rowsBeforeSep16,2:end) = ...
                    0.85 * M2D_corps_yields(rowsBeforeSep16,2:end);
                    
                
                M2D_corps_yields(~rowsBeforeSep16,2:end) = ...
                    M2D_corps_yields(~rowsBeforeSep16,2:end) - ...
                    0.15*abs(M2D_corps_yields(~rowsBeforeSep16,2:end)); 

                M2D_corps_durations = ...
                    Str_Corporates_iBoxx_Bid.(strcat(name_corp_curve, '_durations'));
            catch
                continue
            end
        else % CQS>0
            name_corp_curve = config.RFR_Str_lists.C2D_list_corporates{row_LTAS};
                      
            try    
               M2D_corps_yields = ...
                    Str_Corporates_iBoxx_Bid.(strcat(name_corp_curve, '_yields'));

               M2D_corps_durations = ...
                    Str_Corporates_iBoxx_Bid.(strcat(name_corp_curve, '_durations')); 
                               
            catch
                continue
            end
        end
        
            %   if the curve for the currency and CQS of the run does not
            %   exist, after the main loop appropriate calculations
            %   should be developed based on the existing curves
        
            %   Now the 2-dimensional matrices  'M2D_corps_yields'
            %   and   'M2D_corps_durations'   contain the full historical
            %   series of indices for the corporate sector and CQS
            %   of each run(according to the value of row_LTAS)
 
            
                    
        %%  3.1.B.  Historical serie of basic risk-free rates curves
        %   ---------------------------------------------------------------

        if row_LTAS <= 14
            M2D_history_basic_RFR = ...
                                Str_History_basic_RFR.EUR_RFR_basic_spot;
        end
        
        if row_LTAS > 14  &&  row_LTAS <= 28
            M2D_history_basic_RFR = ...
                        Str_History_basic_RFR.GBP_RFR_basic_spot;                
        end
        
        if row_LTAS > 28
            M2D_history_basic_RFR = ...
                                Str_History_basic_RFR.USD_RFR_basic_spot;
        end
        
                %   'M2D_history_basic_RFR'  is a 2-dimensional matrix with
                %   dates observed in rows and 60 maturities in columns.
                %   First column has the dates in MatLab format number
                %   and columns 2 to 61 the rates for maturities 1 to 60

         
                
        %%  3.1.C.  Removing observations above the date of calculation
        %           from the historical serie of basic risk-free curves
        %          (contained in the matrix  'M2D_history_basic_RFR')
        %   ---------------------------------------------------------------
               
        VecCol_dates = M2D_history_basic_RFR(rows_to_use, 1);
                %   Vector column with the dates
            
        M2D_history_basic_RFR  = ...
                M2D_history_basic_RFR (rows_to_use, 2:end);    

            %   Before these instructions, first column contained dates, 
            %   Dates are now in vector column  'VecCol_dates'
            
            %   After this instruction both 'M2D_history_basic_RFR' 
            %   and  'VecCol_dates '  only contains dates up to 
            %   the date of calculation of the VA
            %   and 60 columns with the rates for maturities 1 to 60
            % (i.e. rows where the logical vector 'rows_to_use' has 0
            %  are not considered)

            
                
        %%  3.1.D.  Aligning dates of corps curves and basic risk-free and interpolating corporate yields
        %           The history of the basic risk-free curves(Bloomberg)
        %           and the history of the corporate curves(Markit-iBoox)
        %           have differente dates.
        %           It is necessary to align dates in both series
        %           The dates of the basic risk-free rates curves are 
        %           used as reference
        %   ---------------------------------------------------------------

        M2D_history_corps_yearly  = zeros(size(M2D_history_basic_RFR));

            %   2-dimensional matrix that will receive the corporate curves
            %   for all the dates of the basic risk-free rates curves
            %  (contained in vector  'VecCol_dates')
            %   Rows will be aligned(referred to the same date)

            
        %   inner loop to match the dates of the historical serie of 
        %   corporate bonds market data(from iBoxx) contained in the
        %   matrices  'M2D_corps_yields' and    'M2D_corps_durations'
        %   with the dates of the basic risk-free rates(from Bloomberg)
        %   contained in  'M2D_history_basic_RFR'
    
        V1C_control_errors = zeros(size(M2D_history_basic_RFR,1),1);
        
            %   This vector will identify the rows where the interpolation
            %   is not possible(fails in the 'try' below)
            
 
        %   The following loop will run data by date the database of the
        %   market yields of the corporate bonds of each run and 
        %   will check whether market information allows to transform 
        %   by linear interpolation
        %   iBoxx data provided as bucktes into a yield curve
        
        
        for k2_run = 1:size(M2D_history_basic_RFR, 1)
            
            row_corps =(M2D_corps_yields(:,1) == VecCol_dates(k2_run));
            
            if ~any(row_corps)
                % this occurs for dates not relevant for the calculation
                continue
            end
            
            
            VecRow_corp_curve = M2D_corps_yields   (row_corps, 2:end);
            VecRow_corp_terms = M2D_corps_durations(row_corps, 2:end);
                %   first column contains dates
                
            %   the following 'if' prevents cases with double dates
            if size(VecRow_corp_curve, 1) > 1
               VecRow_corp_curve = VecRow_corp_curve(end, :);
               VecRow_corp_terms = VecRow_corp_terms(end, :);
            end

            
            %   preventing the cases with no market data
            if ~any((VecRow_corp_curve ~= 0)) || ...
               ~any((VecRow_corp_terms ~= 0))
                continue
            end
            
            
            %   preventing where for the date and curve pof the run
            %   some bucket provided by Markit iBoxx has no data
            %   which would procduce wrong outputs in the interpolation
            %   process below 
            non_zero_rates =(VecRow_corp_curve ~= 0);
            
            VecRow_corp_curve = VecRow_corp_curve(non_zero_rates);
            VecRow_corp_terms = VecRow_corp_terms(non_zero_rates);
            
            
         
            %   Interpolation of the corporate yield curves
            %   -----------------------------------------------------------
            
            if rem(row_LTAS,7) == 5  ||  rem(row_LTAS,7) == 6
                VecRow_curve_complete = ...
                                VecRow_corp_curve(1) * ones(1,600);    
            else
                
                try
                    [ VecRow_curve_complete, ~ ] =  interpolator_curves ...
                          (VecRow_corp_curve, VecRow_corp_terms);

                %   Function  'interpolator_curves'  returns the curve with
                %   market rates inter/extrapolated for all maturities 
                %   with 1 decimal position until 60 years(600 values)
                %   'VecRow_govt_curve' is a row vector with 600 columns
                %  (rates for durations 0.1, 0.2, 0.3,... 1, 1.1,...600)
                %   The second output is row vector(1 : 1; 600)

                %   This functions removes terms without market rates
                %   In case of having no market rates or only one
                %   the funtion returns zero vectors

                catch
                    V1C_control_errors(row_LTAS) = k2_run;
                    continue
                end
                
            end

            M2D_history_corps_yearly(k2_run, :) = ...
                             VecRow_curve_complete(10 : 10 : end);

     
            %   amending the spreads for those maturities 
            %   longer than the last maturity of corporate indices
            %   For those maturities the spread is kept constant 
            %   and equal to the last integer observed spread
     
            if max(VecRow_corp_terms) < 1   % value 0 is prevented
               max_duration_corps = 1;
            else            
                max_duration_corps = fix(max(VecRow_corp_terms));
            end

            if sum(non_zero_rates) > 1 
                M2D_history_corps_yearly(k2_run, max_duration_corps + 1 : end) =...
                M2D_history_basic_RFR   (k2_run, max_duration_corps + 1 : end) +...
                       (M2D_history_corps_yearly(k2_run, max_duration_corps) - ...
                           M2D_history_basic_RFR   (k2_run, max_duration_corps));
            end
 
        end     %   end of the  'for'   k2_run to align the dates of
                %   the historic basic risk-free rates and 
                %   the historic of corporate bond rates
        
        
        M2D_history_corps_yearly (isnan(M2D_history_corps_yearly)) = 0;
        
 
        
        
        %%   3.1.E. Calculation of the raw long term average spreads
        %    ---------------------------------------------------------------

        M2D_non_zero_data =(M2D_history_corps_yearly ~= 0)  .* ...
                           (M2D_history_basic_RFR ~= 0);

        %   Matrix with same rows as the dates with market data
        %   for the calculation of the long term average spreads,
        %   and same columns(60 for maturitie 1 to 60)
        %   Values are 1 only for those dates and maturities where
        %   there are non zero rates for both the basic risk-free curve
        %   and the government bond curve.
        %   Otherwise(one of the rates being null or both of them)
        %   the value is zero.

        
        
        if date_calc > date_change_method_LTAS

            %   Reconstruction of data from 01-01-2016, onwards
            
            [ Str_LTAS ] = RFR_08B_LTAS_Corps_01_from_2016 ...
                       (row_LTAS, rows_to_use, k_factor, ...
                          Str_LTAS, Str_LTAS_YE2015, Str_History_basic_RFR,...
                          M2D_history_corps_yearly, M2D_history_basic_RFR); 

        else
            
            %   Before 01-01-2016, no reconstruction of LTAS

            [ Str_LTAS ] = RFR_08B_LTAS_Corps_02_before_2016 ...
                       (row_LTAS, rows_to_use, k_factor, ...
                          Str_LTAS, Str_History_basic_RFR,...
                          M2D_history_corps_yearly, M2D_history_basic_RFR); 

         
        end
    
        
        
    end     %   end for the first external loop  row_LTAS
    
    close(mssge_wait_bar)

%   -----------------------------------------------------------------------
%%  4. CALCULATIONS THAT DO NOT CHANGE FROM 2015 TO 2016 ONWARDS
%   Section 12.B.1 of EIOPA Technical Documentation October 27, 2015
%   -------------------------------------------------------------------


    %%  4.1. LTAS for CQS6 are those of CQS5
    %   Section 12.B.1 of EIOPA Technical Documentation October 27, 2015
    %   -------------------------------------------------------------------
    
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw((7 : 7 : 42), :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw((6 : 7 : 41), :);
    
    Str_LTAS.Corps.M2D_corps_LTAS_counter((7 : 7 : 42), :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_counter((6 : 7 : 41), :);

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec((7 : 7 : 42), :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec((6 : 7 : 41), :);

    Str_LTAS.Corps.M2D_corps_LTAS_first_dates((7 : 7 : 42), :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates((6 : 7 : 41), :);
    
 
       
    %%  4.2.  The 1-year LTAS is the same as 2-years LTAS
    %   Technical Documentation subsection 10.C.3
    %   ---------------------------------------------------------------

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(:, 1) = ...
           Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(:, 2);

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(:, 1) = ...
           Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(:, 2);


           

        
           
%%  5. LTAS Danish financial covered bond index DKK_Nykredit_index
%   Section 10.C.4 of EIOPA Technical Documentation October 27, 2015   
%   -------------------------------------------------------------------

    if date_calc > date_change_method_LTAS
        
    %   5.1.  From 1-1-2016 onwards, reconstruction of LTAS
    %   Section 10.B.1 of EIOPA Technical Documentation October 27, 2015
    %   ---------------------------------------------------------------       

        

        rows_new_dates =(Str_History_basic_RFR.DKK_RFR_basic_spot(:,1) > ...
            date_change_method_LTAS) & ...
            (Str_History_basic_RFR.DKK_RFR_basic_spot(:,1) <= date_calc);
        
        %  'rows_new_dates' is a logical vector with 1
        %  for those rows where the date is > 31-12-2015
        if any(rows_new_dates)
           dkkDurations = round(DKK_Nykredit.Duration_DKK_Nykredit(rows_new_dates,2)); 

           V1C_basic_RFR_DKK = Str_History_basic_RFR.DKK_RFR_basic_spot(rows_new_dates,2:end);
           
           zeroDurations = dkkDurations == 0;
           dkkDurations(zeroDurations) = 1;
           linIdx = sub2ind(size(V1C_basic_RFR_DKK),...
                (1:(size(V1C_basic_RFR_DKK, 1)))', dkkDurations);
            
           V1C_basic_RFR_DKK = V1C_basic_RFR_DKK(linIdx);
           V1C_basic_RFR_DKK(zeroDurations) = 0;
           
           V1C_DKK_Nykredit = DKK_Nykredit.M2D_DKK_Nykredit(rows_new_dates,2);        
           
           V1C_non_zero_data = (V1C_basic_RFR_DKK ~= 0) .* ...
                               (V1C_DKK_Nykredit ~= 0);

           M2D_numerator = V1C_DKK_Nykredit .*  V1C_non_zero_data - ...
                           V1C_basic_RFR_DKK .* V1C_non_zero_data;
           
           DKK_sum_new_spreads = sum(M2D_numerator, 1);
            
           num_new_dates_with_data = sum(V1C_non_zero_data);

            
            %   Str_LTAS_YE2015.Corps.DKK_Nykredit_LTAS_spread_YE2015
            %   is a scalar containing LTAS for this Danoish index 
            %   till 31-12-2015
            
           Str_LTAS.Corps.DKK_Nykredit_LTAS_spread =  ...
               (Str_LTAS_YE2015.Corps.DKK_Nykredit_LTAS_spread_YE2015 *(7800 - num_new_dates_with_data) + ...
                  DKK_sum_new_spreads) / 7800;
                  
        end

        
    else
        
        %   Calculation before 2016
        %   Section 10.C.4 EIOPA Technical Documentation October 27, 2015    
        %   ---------------------------------------------------------------

        dur_DKK = round(DKK_Nykredit.Duration_DKK_Nykredit) + 1;

        V1C_non_zero_data =(Str_History_basic_RFR.EUR_RFR_basic_spot(rows_to_use, dur_DKK) ~= 0) .* ...
                           (DKK_Nykredit.M2D_DKK_Nykredit(rows_to_use, 2) ~= 0);

        %   Matrix with same rows as the dates with market data
        %   for the calculation of the long term average spreads,
        %   and same columns(60 for maturities 1 to 60)
        %   Values are 1 only for those dates and maturities where
        %   there are non zero rates for both the basic risk-free curve
        %   and the government bond curve.
        %   Otherwise(one of the rates being null or both of them)
        %   the value is zero.

        V1C_numerator = DKK_Nykredit.M2D_DKK_Nykredit(rows_to_use, 2) .*  ...
                                                V1C_non_zero_data   -   ...
                        Str_History_basic_RFR.DKK_RFR_basic_spot(rows_to_use, dur_DKK) .*  ...
                                                V1C_non_zero_data ;

        Str_LTAS.Corps.DKK_Nykredit_LTAS_spread = ...
                sum(V1C_numerator, 1) ./  sum(V1C_non_zero_data, 1);

    end
    
    

 
           
%%  6. Updating the sructure with the information referred to 31/12/2015
%   Section 10.C.4 of EIOPA Technical Documentation October 27, 2015   
%   -------------------------------------------------------------------

    if date_calc  <=  date_change_method_LTAS

        Str_LTAS_YE2015.Corps.M2D_corps_LTAS_spreads_YE2015 = ...
                        Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec; 
        
        Str_LTAS_YE2015.Corps.V1R_GBP_EUR_k_factor_YE2015 = ...
                        Str_LTAS.Corps.V1R_GBP_EUR_k_factor;

        Str_LTAS_YE2015.Corps.V1R_USD_EUR_k_factor_YE2015 = ...
                        Str_LTAS.Corps.V1R_USD_EUR_k_factor;
    
        Str_LTAS_YE2015.Corps.DKK_Nykredit_LTAS_spread_YE2015 = ...
                        Str_LTAS.Corps.DKK_Nykredit_LTAS_spread;
  
        save(fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                    'Str_LTAS_YE2015'), 'Str_LTAS_YE2015');
 
    end
    