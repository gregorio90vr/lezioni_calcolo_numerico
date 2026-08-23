function [ER] = RFR_06A_extrapol_main_loop ...
                  (date_calc, Str_assumptions, config, ...
                    M2D_raw_curves, M2D_CRA, M2D_DLT, withVA, VecCol_VA)

         

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%   This function contains a loop for each currency in order to apply
%
%       firstly the ADLT test (removing observations an data corresponding
%                               to non ADLT terms/maturities)

%       secondly applies CRA to the rates observed in financal markets
%           This adjustment is applied directly to observed rates.
%           Where these rates do not correspond to zero-coupon instruments,
%           adjusting here CRA means a non-parallel(decreasing) adjustment
%           to the final zero-coupon curve
%           If a parallel adjustment is considered appropriate, then
%           CRA adjustment should be calculated in the following function
%           as a correction of the 'volatilty adjustment'

%       thirdly, the following function is executed in order to extrapolate

%   The results of all this process are stored in structure 'ER'



%   INPUTS  ---------------------------------------------------------------

        %   'date_calc' : date of calculation of curves as MatLab number
        %                 if the selected date does not match exactly
        %                 any of the dates with historical data
        %                 the first previous existing date is considered
        %   (see section 2 function 'RFR_03_basic_Preparing_calculations')
        
        

%   OUTPUTS  --------------------------------------------------------------

    %   Structure named 'ER (results) with the following elements
 
        %   ER.VecRow_maturities     
        %      Vector row 1:1:150 (maturities) of curves
       
        %   ER.M2D_raw_rates_net_CRA        
        %      Matrix with observed rates in markets once deducted CRA
        %      and before SW extrapolation
        %      Two-dimensional matrix (n rows * 150 maturities).
        %      where each row refers to a currency / country

        %   ER.M2D_SW_spot_rates        
        %      Matrix with zero-coupon annual spot rates resulting from 
        %      SW extrapolation (basic RFR curve, legally speaking)
        %      Two-dimensional matrix (n rows * 150 maturities).        
        %      where each row refers to a currency / country
        
        %   ER.M2D_SW_forward_rates        
        %      Matrix with annual forward rates resulting from 
        %      SW extrapolation
        %      Two-dimensional matrix (n rows * 150 maturities).        
        %      where each row refers to a currency / country
             
        %   ER.M2D_SW_prices        
        %      Matrix with prices resulting from SW extrapolation 
        %      Two-dimensional matrix (n rows * 150 maturities).        
        %      where each row refers to a currency / country  
        
        %   ER.C1C_parameters_SW  = cell (num_curves, 1);       
        %      Cell array whose elements are vectors with Qb parameters
        %      resulting from SW extrapolation for each currency/country
        %      Two-dimensional matrix (n rows * 150 maturities).
        %      where each row refers to a currency / country
                
        %   ER.VecCol_alpha_fit  = zeros (num_curves, 1);        
        %      Vector column with alpha values for each currency/country
        %      at the convergence point
        
        %   ER.M2D_SW_swap_rates = zeros(num_curves, 1); 
        %       Matrix containing the swap rates corresponding to the
        %       interpolated SW spot rates.
%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------


       
    %   the value of this variable only can be changed by the user
    %   when the extrapolation is not possible for some country/currency
    %   (see 'else' in subsection 2.4 below)
        
        % VecCol_VA wasn't supplied as an argument 
        if nargin < 8
            VecCol_VA = zeros(size(M2D_raw_curves, 1), 1);
        end
    
%  ------------------------------------------------------------------------
%%   1. Preparing the variables to store the final curves calculated
%           Each row refers to each currenncy / country
%           Each column refers to each term or maturity observed in
%           financial markets (both ADLT and non-ADLT)
%  ------------------------------------------------------------------------
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_VA_calculation = config.RFR_Str_lists.Str_numcol_curncy.VA_calculation;
    
    vaSelector =  config.RFR_Str_lists.C2D_list_curncy(:,col_VA_calculation);
    vaSelector = logical(cell2mat(vaSelector));
    
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO3166
        %   for each of the currencies / countries considered


    %   Loading to workspace the configuration data
    %   ------------------------------------------------    
    
 
    col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country;
    
        %   number of the column in cell array
        %   RFR_Str_lists.C2D_list_curncy containing the name 
        %   of each of the currencies / countries considered

    VecRow_terms = config.RFR_Str_lists.C2D_years_formats(:,4);
    VecRow_terms = cell2mat(VecRow_terms);

    num_curves = size(M2D_raw_curves, 1);

    num_maturities  = 150;

    ER.VecRow_maturities = 1:1:150;

    ER.M2D_raw_rates_net_CRA  = zeros(num_curves, num_maturities);
    ER.M2D_SW_spot_rates      = zeros(num_curves, num_maturities);
    ER.M2D_SW_forward_rates   = zeros(num_curves, num_maturities);
    ER.M2D_SW_prices          = zeros(num_curves, num_maturities);
    ER.C1C_parameters_SW      = cell(num_curves, 1);
    ER.V1C_time_parameters_SW = cell(num_curves, 1);
    ER.M2D_SW_swap_rates      = zeros(num_curves, num_maturities);
    
    ER.VecRow_VA_total   = VecCol_VA';
    ER.VecCol_alpha_fit  = zeros(num_curves, 1);


    message= { ['Extrapolating curves. Totally ', num2str(num_curves), ' curves. '] ; ...
               ['Date=',  datestr(date_calc, 24)] };   

    mssge_wait_bar = waitbar(1/num_curves, message);
    
    
%  ------------------------------------------------------------------------
%%  2. Loop of calculation of ADLT control, CRA and extrapolation for each currency
%  ------------------------------------------------------------------------

    for counter =  1:num_curves 
        
        waitbar(counter / num_curves)

        coupon_freq  = Str_assumptions.VecCol_coupon_freq (counter); 
        convergence  = Str_assumptions.VecCol_convergence (counter);
        UFR          = Str_assumptions.VecCol_UFR (counter);        
        
        min_diff     = Str_assumptions.VecCol_min_diff  (counter);        
        min_alpha    = config.RFR_Str_lists.Parameters.SW_lower_bound_alpha;


        %  2.1. DLT control within the liquid part of the curve
        %       and also control of maturities a priori DLT
        %       but with no marlet rate for the date of calculation
        %  ----------------------------------------------------------------
 
        LLP = Str_assumptions.VecCol_LLP (counter);
        
        posic_DLT = (M2D_DLT(counter,1:LLP) == 1) &  ...
                    (M2D_raw_curves(counter,1:LLP) ~= 0);

        num_DLT_nonzero_rates = sum(posic_DLT);
        
                %   posic_DLT   is a logical vector with 
                %           0   for those maturities to ignore market info
                %               because either is a non-DLT maturity 
                %               or market rate is zero
                %           1   otherwise 
                
                
        %   case where there is no DLT market rates for the date of 
        %   calculation and the currency of the run    --------------------       
        if num_DLT_nonzero_rates == 0  

            %   Not possible the extrapolation of the country of this run
            
            SW_time = zeros(num_maturities, 1);
            SW_yields_spot = zeros(num_maturities, 1);
            SW_prices = zeros(num_maturities, 1);
            SW_yields_forward = zeros(num_maturities, 1);
            alpha_fit = 0;
            Qb = 0;

            %   Message to alert the user   -------------------------------
            info = ['No market rates available on ' datestr(date_calc) ' for ', ...
                            config.RFR_Str_lists.C2D_list_curncy{counter,col_name_country},...
                            '. Skipping calculation!'];
            warning(info);
            RFR_log_register ('00_Basic', 'RFR_06_extrapol', 'WARNING',...
                info, config);     

            continue   % process skips to the following run of the loop       
        end

        
        VecCol_t = VecRow_terms(posic_DLT)'; 
        LLP = max(VecCol_t);
        
        VecCol_rates = M2D_raw_curves(counter, posic_DLT)';
        
        
        VecCol_CRA = M2D_CRA(counter, posic_DLT)';
        
         
        %  2.2. Credit and basis risk adjustment (CRA)
        %  ----------------------------------------------------------------

            %  In the following instruction CRA is applied directly to 
            %  observed rates 
            %  (sub-section 5.B EIOPA Technical Documentation, 
            %   October 27th, 2015).
            
            %  If these rates do not correspond to zero-coupon instruments,
            %  adjusting here CRA means a decreasing adjustment
            %  to the final zero-coupon curve
            %  If a parallel adjustment were considered appropriate, then
            %  CRA adjustment should be applied in the following function
            %  as a correction of the 'volatilty adjustment'        


        VecCol_rates = (VecCol_rates - VecCol_CRA);        

        ER.M2D_raw_rates_net_CRA(counter, posic_DLT) = VecCol_rates;
                
        
        %  2.4. Extrapolation        
        %  ----------------------------------------------------------------

        %   Second message to alert the user when market data are scarce
        
        %   The two parameters used in the 'if' below  are set out in 
        %   in sheet  'Parameters'  of excel file  'RFR_excel_confing.xlsx'
        %   and moved to  'RFR_Str_lists.Parameters'  in section 2.6
        %   at the end of fucntion   'RFR_01_basic_setting_config.m'
        %   Criteria explained in section 7.A of technical documentation

        if (num_DLT_nonzero_rates < config.RFR_Str_lists.Parameters.SW_minimum_number_rates * ...
            sum(M2D_DLT(counter,1:LLP)) || LLP < Str_assumptions.VecCol_LLP(counter))

            availableRates = round(100 * num_DLT_nonzero_rates / sum(M2D_DLT(counter,1:LLP)));
            
            info = ['Insufficient market information on ' datestr(date_calc) ' for ', ...
                     config.RFR_Str_lists.C2D_list_curncy{counter,col_name_country}, ...
                     '. Rates missing: ', num2str(100-availableRates),...
                     '%; Last Mat./LLP: [', num2str(LLP), '/', ...
                     num2str(Str_assumptions.VecCol_LLP(counter)),']'];    
            
            warning(info);
            
            RFR_log_register('00_Basic', 'RFR_06_extrapol', 'Warning', info, config);     

            continue  % No calculation is performed for that currency

        end
        

        
        %   First extrapolation without volatility adjustment
        %   -----------------------------------------------------------

        % IMPORTANT 
        % Any change in  'RFR_06B_extrapol_scanning.m'   impacts on
        %       'RFR_02_DVA_calculations.m'
        %       'VA_History_basic_RFR_batch_all_curves.m'

        [SW_time,SW_yields_spot,SW_prices, ...
          SW_yields_forward,SW_yields_swap,alpha_fit,Qb,VecRow_terms_Qb] = ...
                    RFR_06B_extrapol_scanning ...
                        (coupon_freq, convergence, LLP,...
                          UFR, min_diff, min_alpha, ...
                          VecCol_t, VecCol_rates);



        %   second extrapolation introducing 'Volatility Adjustment' 
        %   as a parallel shift of liquid part
        %   -----------------------------------------------------------

        %   The starting point are the spot rates for the whole curve
        %   The non liquid part is disregarded and the VA added.
        %   This is the input of the second extrapolation.
        %   Now the input is a zero coupon curve, 

        % Trigger the calculation of the RFR with VA curve based on the 'VA'
        % column in the Excel config file.
        
        if withVA && vaSelector(counter)
           %  VA is expressed in basis points

           VA_rounded = round(100 * VecCol_VA(counter)) / 100;

           VecCol_t     = 1:1:LLP;

           VecCol_rates = 100 * SW_yields_spot(1 : LLP) + ...
                          VA_rounded;
                          % VA should be divided by 100

           coupon_freq = 0;

            [SW_time,SW_yields_spot,SW_prices, ...
              SW_yields_forward,SW_yields_swap,alpha_fit,Qb,VecRow_terms_Qb] = ...
                    RFR_06B_extrapol_scanning ...                  
                        (coupon_freq, convergence, LLP,...
                          UFR, min_diff, min_alpha, ...
                          VecCol_t, VecCol_rates);

        end



        
        %  2.5. Storing final curves in structure 'ER'        
        %  ----------------------------------------------------------------

        ER.M2D_SW_spot_rates    (counter, :) = SW_yields_spot';
        ER.M2D_SW_forward_rates (counter, :) = SW_yields_forward';
        ER.M2D_SW_prices        (counter, :) = SW_prices';

        ER.VecCol_alpha_fit  (counter)  = alpha_fit;
        ER.VecRow_CRA        (counter) = M2D_CRA (counter);
        ER.C1C_parameters_SW (counter) = { Qb };
        ER.V1C_time_parameters_SW  (counter) = { VecRow_terms_Qb };
        ER.M2D_SW_swap_rates (counter, :) =  SW_yields_swap';


    end

    close(mssge_wait_bar)