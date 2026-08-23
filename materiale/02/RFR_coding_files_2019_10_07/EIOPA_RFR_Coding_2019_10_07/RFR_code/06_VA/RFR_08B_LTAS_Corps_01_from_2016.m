function   [Str_LTAS] = RFR_08B_LTAS_Corps_01_from_2016 ...
                       (row_LTAS, rows_to_use, k_factor, ...
                          Str_LTAS, Str_LTAS_YE2015, Str_History_basic_RFR,...
                          M2D_history_corps_yearly, M2D_history_basic_RFR) 

 
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   Executes LTAS Corps calculations specific dates from 2016 onwards
    
    %   Workspace is saved in hard disk at the end of this function
 
%%   1. Calculation of the raw long term average spreads
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

        M2D_numerator = M2D_history_corps_yearly .*  M2D_non_zero_data -...
                        M2D_history_basic_RFR    .*  M2D_non_zero_data ;

        %   vector row with 60 columns containing the sum of spreads 
        %   for maturities 1 to 60 years only for those dates
        %   from 1-1-2016 onwards

        %    The 1-year LTAS is the same as 2-years LTAS
        %   Technical Documentation subsection 10.C.3

        V1R_new_spreads = sum(M2D_numerator, 1);
        
        V1R_new_spreads(1) = V1R_new_spreads(2);  

        V1R_num_new_dates_with_data = sum(M2D_non_zero_data , 1);

        %   vector row with 60 columns containing the number of 
        %   new dates with spreads for each maturity 


        %   Str_LTAS_YE2015.Corps.M2D_corps_LTAS_spreads_YE2015
        %   is a 2-dimensional matrix with 60 columns containing
        %   in each row the LTAS as of 31-12-2015 for each country

       Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS, :) =  ...
           (Str_LTAS_YE2015.Corps.M2D_corps_LTAS_spreads_YE2015(row_LTAS, :) .*(7800 - V1R_num_new_dates_with_data) + ...
              V1R_new_spreads) / 7800;



%%  2. LTAS for GBP CQS4, CQS5 are those of the Euro with k-factor
%       Tables at the end of section 12.B.1 
%       EIOPA Technical Documentation October 27, 2015
%   -------------------------------------------------------------------

    %   The first step is calculating the 'k' factor to apply
    %   which is 50 per cent of the spread among the basic risk free curves

    
       GBP_RFR_basic_spot_to_use = Str_History_basic_RFR.GBP_RFR_basic_spot(rows_to_use, 2:end);
       EUR_RFR_basic_spot_to_use = Str_History_basic_RFR.EUR_RFR_basic_spot(rows_to_use, 2:end);
       
       M2D_non_zero_data =(GBP_RFR_basic_spot_to_use ~= 0)  .* ...
                          (EUR_RFR_basic_spot_to_use ~= 0);

        %   Matrix with same rows as the dates with market data
        %   for the calculation of the long term average spreads,
        %   and same columns(60 for maturitie 1 to 60)
        %   Values are 1 only for those dates and maturities where
        %   there are non zero rates for both the basic risk-free curve
        %   and the government bond curve.
        %   Otherwise(one of the rates being null or both of them)
        %   the value is zero.

        M2D_numerator = GBP_RFR_basic_spot_to_use .* M2D_non_zero_data -...
                        EUR_RFR_basic_spot_to_use .* M2D_non_zero_data ;
    

        V1R_new_spreads = k_factor  *  sum(M2D_numerator, 1);
        
        V1R_new_spreads(1) = V1R_new_spreads(2);  

        V1R_num_new_dates_with_data = sum(M2D_non_zero_data , 1);

        %   vector row with 60 columns containing the number of 
        %   new dates with spreads for each maturity 


        %   Str_LTAS_YE2015.Corps.M2D_corps_LTAS_spreads_YE2015
        %   is a 2-dimensional matrix with 60 columns containing
        %   in each row the LTAS as of 31-12-2015 for each country

        Str_LTAS.Corps.V1R_GBP_EUR_k_factor =  ...
           (Str_LTAS_YE2015.Corps.V1R_GBP_EUR_k_factor_YE2015 .*(7800 - V1R_num_new_dates_with_data) + ...
              V1R_new_spreads) / 7800;
    

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([  5:6  12:13 ], :) + ...
                        repmat(Str_LTAS.Corps.V1R_GBP_EUR_k_factor, 4, 1);

                    
    Str_LTAS.Corps.M2D_corps_LTAS_counter([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_counter([  5:6  12:13 ], :);


    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([  5:6  12:13 ], :) + ...
                    repmat(Str_LTAS.Corps.V1R_GBP_EUR_k_factor, 4, 1);

                    
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([  5:6  12:13 ], :);




%%  3. LTAS for USD CQS4, CQS5 are those of the Euro with k-factor
%       Tables at the end of section 12.B.1 
%       EIOPA Technical Documentation October 27, 2015
%   -------------------------------------------------------------------


    %   The first step is calculating the 'k' factor to apply
    %   which is 50 per cent of the spread among the basic risk free curves

    
   USD_RFR_basic_spot_to_use = Str_History_basic_RFR.USD_RFR_basic_spot(rows_to_use, 2:end);
   EUR_RFR_basic_spot_to_use = Str_History_basic_RFR.EUR_RFR_basic_spot(rows_to_use, 2:end);

   M2D_non_zero_data =(USD_RFR_basic_spot_to_use ~= 0)  .* ...
                      (EUR_RFR_basic_spot_to_use ~= 0);

    %   Matrix with same rows as the dates with market data
    %   for the calculation of the long term average spreads,
    %   and same columns(60 for maturitie 1 to 60)
    %   Values are 1 only for those dates and maturities where
    %   there are non zero rates for both the basic risk-free curve
    %   and the government bond curve.
    %   Otherwise(one of the rates being null or both of them)
    %   the value is zero.

    M2D_numerator = USD_RFR_basic_spot_to_use .* M2D_non_zero_data -...
                    EUR_RFR_basic_spot_to_use .* M2D_non_zero_data ;


    V1R_new_spreads = k_factor  *  sum(M2D_numerator, 1);

    V1R_new_spreads(1) = V1R_new_spreads(2);  

    V1R_num_new_dates_with_data = sum(M2D_non_zero_data , 1);

    %   vector row with 60 columns containing the number of 
    %   new dates with spreads for each maturity 


    %   Str_LTAS_YE2015.Corps.M2D_corps_LTAS_spreads_YE2015
    %   is a 2-dimensional matrix with 60 columns containing
    %   in each row the LTAS as of 31-12-2015 for each country

    Str_LTAS.Corps.USD_EUR_k_factor =  ...
       (Str_LTAS_YE2015.Corps.V1R_USD_EUR_k_factor_YE2015 .*(7800 - V1R_num_new_dates_with_data) + ...
          V1R_new_spreads) / 7800;


    
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([  5:6  12:13 ], :) + ...
                        repmat(Str_LTAS.Corps.USD_EUR_k_factor, 4, 1);
    
    Str_LTAS.Corps.M2D_corps_LTAS_counter([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_counter([  5:6  12:13 ], :);

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([  5:6  12:13 ], :) + ...
                        repmat(Str_LTAS.Corps.USD_EUR_k_factor, 4, 1);

    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([  5:6  12:13 ], :);
