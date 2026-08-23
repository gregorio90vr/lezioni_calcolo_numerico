function   [Str_LTAS] = RFR_08B_LTAS_Corps_02_before_2016 ...
                       (row_LTAS, rows_to_use, k_factor, ...
                          Str_LTAS, Str_History_basic_RFR,...
                          M2D_history_corps_yearly, M2D_history_basic_RFR) 

 
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   Executes LTAS Corps calculations specific of dates before 2016
    
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


    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :) = ...
           sum(M2D_numerator, 1) ./  sum(M2D_non_zero_data, 1);         

    Str_LTAS.Corps.M2D_corps_LTAS_counter(row_LTAS, :) = ...
                                   sum(M2D_non_zero_data, 1);

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS, :) = ...
              Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :);         


       
         
%%  2 Recalculation for GBP non financial CQS1 
%   with linear interpolation from 4 to 9 years
%   Section 12.B.1 EIOPA Technical Documentation October 27, 2015    
%   ---------------------------------------------------------------

    if row_LTAS ==  23 || row_LTAS ==  22
        %   this means the run refers to CQS1 of GBP non financial 
        %   also has to be applied to CQS0 as it is determined with 85% of
        %   CQS1

        V1C_LTAS_partial = Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, [ 1:3 10:60 ]);

        V1C_LTAS_interpolated = interp1([ 1:3 10:60 ], V1C_LTAS_partial,(1:60));


        Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :) = ...
                                        V1C_LTAS_interpolated ;

        Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS, :) = ...
             Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :);

    end



%% 3.  Adjustment to GBP LTAS as we have more data
% Cf. section 10.B.1 of the technical documentation
%-----------------------------------------------------------------------

    if row_LTAS == 16 || row_LTAS == 23
        % this means the run refers to CQS1 of GBP financial and non financial
        % we need to apply this adjustment to CQS0 as well
        Ratio = ones(1,60);
        Ratio(1:4) = 0.82;
        Ratio(5:8) = 0.80;
        Ratio(9:60) = 0.95;

        % For CQS1
        Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS, :) = ...
             Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :) .* Ratio;

        % For CQS0
         Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS - 1, :) = ...
             Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS - 1, :) .* Ratio;
    end

    if row_LTAS == 17 || row_LTAS == 24
        % this means the run refers to CQS2 of GBP financial and non financial
        Ratio = ones(1,60);
        Ratio(1:4) = 0.88;
        Ratio(5:8) = 0.84;
        Ratio(9:60) = 0.93;

        Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS, :) = ...
             Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :) .* Ratio;
    end

    if row_LTAS == 18 || row_LTAS == 25
        % this means the run refers to CQS3 of GBP financial and non financial
        Ratio = ones(1,60);
        Ratio(1:4) = 0.97;
        Ratio(5:60) = 0.93;

        Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(row_LTAS, :) = ...
             Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw(row_LTAS, :) .* Ratio;			
    end




%%  4. LTAS for GBP CQS4, CQS5 are those of the Euro
%       Tables at the end of section 12.B.1 
%       EIOPA Technical Documentation October 27, 2015
%   -------------------------------------------------------------------

    %   The first step is calculating the 'k' factor to apply
    %   which is 50 per cent of the spread among the basic risk free curves
    
    M2D_history_spread_GBP_EUR = ...
                Str_History_basic_RFR.GBP_RFR_basic_spot(rows_to_use, 2:end) -...
                Str_History_basic_RFR.EUR_RFR_basic_spot(rows_to_use, 2:end);
             
    V1R_GBP_EUR_k_factor = k_factor * mean(M2D_history_spread_GBP_EUR, 1);
    

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([  5:6  12:13 ], :) + ...
                        repmat(V1R_GBP_EUR_k_factor, 4, 1);

                    
    Str_LTAS.Corps.M2D_corps_LTAS_counter([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_counter([  5:6  12:13 ], :);


    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([  5:6  12:13 ], :) + ...
                        repmat(V1R_GBP_EUR_k_factor, 4, 1);

                    
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([ 19:20 26:27 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([  5:6  12:13 ], :);


    Str_LTAS.Corps.V1R_GBP_EUR_k_factor =  V1R_GBP_EUR_k_factor;



%%  5. LTAS for USD CQS4, CQS5 are those of the Euro    
%       Tables at the end of section 12.B.1 
%       EIOPA Technical Documentation October 27, 2015
%   -------------------------------------------------------------------

    %   The first step is calculating the 'k' factor to apply
    %   which is 50 per cent of the spread among the basic risk free curves
    
    M2D_history_spread_USD_EUR = ...
                Str_History_basic_RFR.USD_RFR_basic_spot(rows_to_use, 2:end) -...
                Str_History_basic_RFR.EUR_RFR_basic_spot(rows_to_use, 2:end);
             
    V1R_USD_EUR_k_factor = k_factor * mean(M2D_history_spread_USD_EUR, 1);
    
    
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_raw([  5:6  12:13 ], :) + ...
                        repmat(V1R_USD_EUR_k_factor, 4, 1);
    
    Str_LTAS.Corps.M2D_corps_LTAS_counter([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_counter([  5:6  12:13 ], :);

    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec([  5:6  12:13 ], :) + ...
                        repmat(V1R_USD_EUR_k_factor, 4, 1);

    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([ 33:34 40:41 ], :) = ...
    Str_LTAS.Corps.M2D_corps_LTAS_first_dates([  5:6  12:13 ], :);


    Str_LTAS.Corps.V1R_USD_EUR_k_factor =  V1R_USD_EUR_k_factor;
