

function  RFR_03A_DVA_statistics(RFR_config_mat_file) 


%%  EXPLANATION OF THIS FUNCTION
%   -----------------------------------------------------------------------

%   This function calculates DLT statistics
%   and save the file in the workspace folder 


        
%  ------------------------------------------------------------------------
%%  1. Previous load of necessary variables in workspace
%  ------------------------------------------------------------------------ 

    
    load(RFR_config_mat_file)

    
    load(fullfile(RFR_Str_config.folders.path_RFR_99_Workspace, ...
                        'RFR_DVA_workspace'))
        
    VecRow_terms = cell2mat(RFR_Str_lists.C2D_years_formats(:, 4)');

        %   Row vector with the maturities observed in financial markets
        %  (including those intermediate without values)
        %   Currently(year 2014) from 1 to 60 years

    num_dates = size(Str_vola.M3D_zero_spot_rates, 1);
        
    
    
%  ------------------------------------------------------------------------
%%  2.Creating 3-D matrix to store results for each currency and maturity
%  ------------------------------------------------------------------------ 
        
    num_countries  = size(RFR_Str_lists.C2D_list_curncy, 1);

    num_statistics = 11;
    
    num_terms = length(VecRow_terms);
   
    M3D_statistics = zeros(num_statistics, num_terms+1, num_countries);

        
    
%  ------------------------------------------------------------------------
%%  3. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 
            

    %   First statistic  = number of observations with zeros
    %   -------------------------------------------------------------------

    M3D_statistics(1, :, :) = ...
                            sum(Str_vola.M3D_zero_spot_rates == 0, 1);


    %   Second statistic = Median of spot rates
    %   -------------------------------------------------------------------

    M3D_statistics(2, :, :) = 100 * ...
                            median(Str_vola.M3D_zero_spot_rates);
            
                        
    %   Fourth statistic = interquartile range / median of spot rates
    %   -------------------------------------------------------------------

    M3D_statistics(4, :, :) = 100 * ...
             (prctile(Str_vola.M3D_zero_spot_rates, 75) - ...
                prctile(Str_vola.M3D_zero_spot_rates, 25))  ./  ...
                median(Str_vola.M3D_zero_spot_rates);

            
    %   Sixth statistic = Last volatility(calculated 21-days window)
    %   -------------------------------------------------------------------

    M3D_statistics(6, :, :) = 100 * ...
                          Str_vola.M3D_zero_spot_vola(end, :, :);
                      
                        
    %   Seventh statistic = interquartile range / median of diff spot rates
    %   -------------------------------------------------------------------

    M3D_statistics(7, :, :) = ...
             (prctile(diff(Str_vola.M3D_zero_spot_rates, 1), 75) - ...
                prctile(diff(Str_vola.M3D_zero_spot_rates, 1), 25))  ./  ...
                median(diff(Str_vola.M3D_zero_spot_rates, 1));

                        
    %   Nineth statistic = Last Roll measure
    %   -------------------------------------------------------------------

    M3D_statistics(9, :, :) = Str_vola.M3D_Roll(end, :, :);

                        
    %   Tenth statistic = Percentile 90 Roll measure
    %   -------------------------------------------------------------------

    M3D_statistics(10, :, :) = prctile(Str_vola.M3D_Roll(22:end, :, :), 90);
 
        %   First 21 days do not have any Roll measure
                      
                      
    %   for statistics 3, 5, 8 and 11 it is necessary a double loop
    %   -------------------------------------------------------------------
            
    for counter_country = 1 : 1 : num_countries
        
        
        for maturity_run = VecRow_terms
                         
                                 
            %   Third statistic = Growth with linear fitting
            %   -----------------------------------------------------------
            
            VecCol_rates = Str_vola.M3D_zero_spot_rates(:, maturity_run + 1, counter_country);
            
            coefficients = polyfit((1:1:num_dates)', VecCol_rates, 1);
                         
            M3D_statistics(3, maturity_run + 1, counter_country) = ...
                                       10000 * coefficients(1);

                         
                         
            %   Fifth statistic = number of rates out of range
            %           average +- 1.5 standard deviation,
            %   calculated only with range 12.5 - 87.5 percentiles
            %   -----------------------------------------------------------
            
            VecCol_int = Str_vola.M3D_zero_spot_rates(:, maturity_run + 1, counter_country);
            
            if sum(VecCol_int == 0) > 0.1 * length(VecCol_int)
                continue
            else
               VecCol_int = VecCol_int(VecCol_int ~= 0);
            end
            
            Perct_12_5 = prctile(VecCol_int, 12.5);
            Perct_87_5 = prctile(VecCol_int, 87.5);
            
            VecCol_use = VecCol_int(VecCol_int >= Perct_12_5 );
            VecCol_use = VecCol_int(VecCol_int <= Perct_87_5 );
                                  
            lower_limit = mean(VecCol_use) - 1.5 * std(VecCol_use);
            upper_limit = mean(VecCol_use) + 1.5 * std(VecCol_use);
            
            statistic_3 = VecCol_int(VecCol_int < lower_limit);
            statistic_3 = VecCol_int(VecCol_int > upper_limit);
                         
            M3D_statistics(5, maturity_run + 1, counter_country) = ...
                                    length(statistic_3);
            
        
            
            %   Eight statistic = number of rates out of range
            %           average +- 1.5 standard deviation,
            %   calculated only with range 12.5 - 87.5 percentiles
            %   -----------------------------------------------------------
            
            VecCol_int = Str_vola.M3D_zero_spot_rates(:, maturity_run + 1, counter_country);
            VecCol_int = diff(VecCol_int);
            
            if sum(VecCol_int == 0) > 0.1 * length(VecCol_int)
                continue
            else
               VecCol_int = VecCol_int(VecCol_int ~= 0);
            end
            
            Perct_12_5 = prctile(VecCol_int, 12.5);
            Perct_87_5 = prctile(VecCol_int, 87.5);
            
            VecCol_use = VecCol_int(VecCol_int >= Perct_12_5 );
            VecCol_use = VecCol_int(VecCol_int <= Perct_87_5 );
                                  
            lower_limit = mean(VecCol_use) - 1.5 * std(VecCol_use);
            upper_limit = mean(VecCol_use) + 1.5 * std(VecCol_use);
            
            statistic_3 = VecCol_int(VecCol_int < lower_limit);
            statistic_3 = VecCol_int(VecCol_int > upper_limit);
                         
            M3D_statistics(8, maturity_run + 1, counter_country) = ...
                                    length(statistic_3);
                                
        
            
            %   Eleventh statistic = Percentil 90 of absolute change
            %   of prices
            %   -----------------------------------------------------------
            
            VecCol_rates   = Str_vola.M3D_zero_spot_rates(:, maturity_run + 1, counter_country);
            
            VecCol_prices  =(1 + VecCol_rates/100) .^  - maturity_run;
            
            VecCol_returns = VecCol_prices(2:end) ./ ...
                             VecCol_prices(1:end-1);
                         
            M3D_statistics(11, maturity_run + 1, counter_country) =...
                           10000 * prctile(log(VecCol_returns), 90);
            
                                
        end % this refers to the loop for each currency
                        
        
    end     % this refers to the loop for each currency
 
    
   RFR_03B_DVA_statistics_writing_excel_results...  
                       (RFR_Str_config, RFR_Str_lists, date_calc, ...
                          VecRow_terms  , M3D_statistics)



    save(fullfile(RFR_Str_config.folders.path_RFR_99_Workspace,...
        'RFR_DVA_workspace'), 'M3D_statistics', '-append')
    

end

