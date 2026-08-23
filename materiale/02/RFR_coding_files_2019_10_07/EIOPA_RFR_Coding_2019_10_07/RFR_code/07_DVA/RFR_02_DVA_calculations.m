

function    [ Str_vola ] = RFR_02_DVA_calculations ...  
                       (RFR_config_mat_file, counter_country, ...
                          num_dates_vola, date_calc, Str_assumptions,...
                          VecRow_terms, M2D_curves_history, Str_vola)



                                   
%% Setting up the matrix of coupon cashflows

    
    load(RFR_config_mat_file)
                     
    col_SWP_GVT = RFR_Str_lists.Str_numcol_curncy.SWP_GVT;
    col_LLP_GVT = RFR_Str_lists.Str_numcol_curncy.LLP_GVT;
    col_LLP_SWP = RFR_Str_lists.Str_numcol_curncy.LLP_SWP;

    %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered its ISO3166
        %   whether the basic RFR curve is based on swaps or govts
        %   and the last liquid point in each case.
 
                                    
    if strcmp(RFR_Str_lists.C2D_list_curncy(counter_country, col_SWP_GVT), 'GVT')
            LLP = cell2mat(RFR_Str_lists.C2D_list_curncy(counter_country, col_LLP_GVT ));
    else
            LLP = cell2mat(RFR_Str_lists.C2D_list_curncy(counter_country, col_LLP_SWP ));
    end

    
                         
    M2D_exponent = - repmat((1:60), 21, 1);
        % this matrix will be used in the calculation of Roll measurement
    
        
    for counter_dates = 1:size(Str_vola.M3D_par_mkt_rates, 1);
                        
        %   Calculations of volatilities  ---------------------------------
        %   ---------------------------------------------------------------
                        
        if counter_dates > 21

            %   Vola calculation for par market rates ---------------------
            %   -----------------------------------------------------------
            
            Var_int_1 = Str_vola.M3D_par_mkt_rates(counter_dates - 20 : counter_dates,     2:end, counter_country) ./ ...
                        Str_vola.M3D_par_mkt_rates(counter_dates - 21 : counter_dates - 1, 2:end, counter_country);
            
            Var_int_1 = std(log(Var_int_1));
            Var_int_1(isnan(Var_int_1)) = 0;
            Var_int_1(isinf(Var_int_1)) = 0;
            
            Str_vola.M3D_par_mkt_vola(counter_dates, 2:end, counter_country) = Var_int_1;
            
            
            %   Vola calculation for zero coupon rates --------------------
            %   -----------------------------------------------------------
            
            Var_int_1 = Str_vola.M3D_zero_spot_rates(counter_dates - 20 : counter_dates,     2:end, counter_country) ./ ...
                        Str_vola.M3D_zero_spot_rates(counter_dates - 21 : counter_dates - 1, 2:end, counter_country);
            
            Var_int_1 = std(log(Var_int_1));
            Var_int_1(isnan(Var_int_1)) = 0;
            Var_int_1(isinf(Var_int_1)) = 0;
            
            Str_vola.M3D_zero_spot_vola(counter_dates, 2:end, counter_country) = Var_int_1;

            
            %   Vola calculation for 1-year forward rates -----------------
            %   -----------------------------------------------------------
             
            Var_int_1 = Str_vola.M3D_fwd_rates(counter_dates - 20 : counter_dates,     2:end, counter_country) ./ ...
                        Str_vola.M3D_fwd_rates(counter_dates - 21 : counter_dates - 1, 2:end, counter_country);
            
            Var_int_1 = std(log(Var_int_1));
            Var_int_1(isnan(Var_int_1)) = 0;
            Var_int_1(isinf(Var_int_1)) = 0;
            
            Str_vola.M3D_fwd_vola(counter_dates, 2:end, counter_country) = Var_int_1;

        end
        
        
        %   Calculations specific last LLP   --------------------------
        %   -----------------------------------------------------------
        
        if counter_dates > 21
 
            coefic = polyfit((1:1:21)', ...
                               Str_vola.M3D_fwd_rates(counter_dates-20:counter_dates, LLP+1, counter_country), ...
                               4);
            Str_vola.M3D_fwd_fit_diff(counter_dates, 2:end, counter_country) = polyval(coefic,(1:1:21));
 
            if counter_dates == size(Str_vola.M3D_par_mkt_rates, 1)
                
              Str_vola.M3D_fwd_fit_last_date(:, 2, counter_country) = ...
                       Str_vola.M3D_fwd_rates(counter_dates-20:counter_dates, LLP+1, counter_country);
              
              Str_vola.M3D_fwd_fit_last_date(:, 3, counter_country)=...
                                polyval(coefic,(1:1:21)'); 
            end
        end
        
        

        %   Calculations Roll measure based on spot rates   -----------
        %   -----------------------------------------------------------
       
        if counter_dates > 21

            M2D_zero_rates = Str_vola.M3D_zero_spot_rates(counter_dates - 20 : counter_dates, 2:end, counter_country);

            M2D_variation_prices = 10000 * diff((1 + M2D_zero_rates) .^ M2D_exponent);
            
            for maturity = 1 : 1 : size(M2D_zero_rates, 2)
                
                M2D_cov = 2 * sqrt(- cov([ M2D_variation_prices(1:end-1, maturity)  ...
                                             M2D_variation_prices(2:end  , maturity) ]));
                                      
                Str_vola.M3D_Roll(counter_dates, maturity+1, counter_country) = M2D_cov(1, 2);
                                          
            end
        end        
     
        
    end
    
    
    
    
%=========================================================================        
%=========================================================================
