

function  [  M3D_stats_bid_ask_spread ] = RFR_06A_Bid_Ask_statistics ...
                                   (RFR_config_mat_file, date_calc) 


%%  EXPLANATION OF THIS FUNCTION
%   -----------------------------------------------------------------------

%   This function calculates Bid - Ask spreads statistics
%   and save the file in the workspace folder 


        
%  ------------------------------------------------------------------------
%%  1. Previous load of necessary variables in workspace
%  ------------------------------------------------------------------------ 

    load(RFR_config_mat_file)
                        
    col_ISO4217 = RFR_Str_lists.Str_numcol_curncy.ISO4217;
        
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO4217
        %   for each of the currencies / countries considered 
    
    load(fullfile(RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'RFR_basic_curves_Bid_Ask'))
                    
    
                    
    VecRow_terms = cell2mat(RFR_Str_lists.C2D_years_formats(:,4)');

        %   Row vector with the maturities observed in financial markets
        %  (including those intermediate without values)
        %   Currently(year 2014) from 1 to 60 years
    
    
    
%  ------------------------------------------------------------------------
%%  2.Creating 3-D matrix to store results for each currency and maturity
%  ------------------------------------------------------------------------ 
        

    VecCol_countries_codes = RFR_Str_lists.C2D_list_curncy(:, col_ISO4217);

    num_countries = length(VecCol_countries_codes); 

    num_statistics = 6 * 2;
    
    num_terms = length(VecRow_terms);
   
    M3D_stats_bid_ask_spread = zeros(num_statistics, num_terms, num_countries);

        
    
%  ------------------------------------------------------------------------
%%  3. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 
            

    C1C_Bid_curves = fieldnames(RFR_download_BBL_Bid);
    C1C_Ask_curves = fieldnames(RFR_download_BBL_Ask);

    
    for run_country = 1:num_countries
                
        if run_country > 1  && strcmp('EUR', VecCol_countries_codes(run_country))
            % no calculation for the concrete countries of Euro area
            % only first run calculation for the Euro as a whole 
            continue
        end
        
        name_bid_curve = strcat(VecCol_countries_codes{ run_country }, '_SWP_Bid_BBL');
        name_ask_curve = strcat(VecCol_countries_codes{ run_country }, '_SWP_Ask_BBL');

        if ~strcmp(C1C_Bid_curves, name_bid_curve)    
            continue
        end
        
        if ~strcmp(C1C_Ask_curves, name_ask_curve)    
            continue
        end
        
        M2D_bid_rates = RFR_download_BBL_Bid.(name_bid_curve);
        M2D_ask_rates = RFR_download_BBL_Ask.(name_ask_curve);

        row_end = find(M2D_bid_rates(:,1) <= date_calc, 1, 'last');
        row_ini = row_end - 63;

        M2D_bid_rates = M2D_bid_rates(row_ini:row_end,2:end);
        M2D_ask_rates = M2D_ask_rates(row_ini:row_end,2:end);
        
        M2D_spread = 100*(M2D_ask_rates - M2D_bid_rates);
           
        for maturity_run = VecRow_terms
            

            Vector = M2D_spread(:,maturity_run);
            
        
            %   Stat 01. Last 64 days. Number days with zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(1,maturity_run,run_country) = ...
                                 sum(Vector == 0);

            Vector = Vector(Vector ~= 0);
            
            if isempty(Vector)
                continue
            end

            
            %   Stat 02. Last 64 days. Median non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(2, maturity_run, run_country) = ...
                                            median(Vector);


            %   Stat 03. Last 64 days. Percentile 80% non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(3, maturity_run, run_country) = ...
                                            prctile(Vector, 80);

                                       
            %   Stat 04. Last 64 days. Maximum bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(4, maturity_run, run_country) = ...
                                            max(Vector);
            
                                       
            %   Stat 05. Last 64 days. Average non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(5, maturity_run, run_country) = ...
                                            mean(Vector);
            
                                       
            %   Stat 06. Last 64 days. Last non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(6, maturity_run, run_country) = ...
                                            Vector(end);
            


            Vector = M2D_spread(end-20:end, maturity_run);
            
        
            %   Stat 07. Last 21 days. Number days with zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(7, maturity_run, run_country) = ...
                                 sum(Vector == 0);

            Vector = Vector(Vector ~= 0);
            
            if isempty(Vector)
                continue
            end

            
            %   Stat 08. Last 21 days. Median non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(8, maturity_run, run_country) = ...
                                            median(Vector);


            %   Stat 09. Last 21 days. Percentile 80% non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(9, maturity_run, run_country) = ...
                                            prctile(Vector, 80);

                                       
            %   Stat 10. Last 21 days. Maximum bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(10, maturity_run, run_country) = ...
                                            max(Vector);
            
                                       
            %   Stat 11. Last 21 days. Average non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(11, maturity_run, run_country) = ...
                                            mean(Vector);
            
                                       
            %   Stat 12. Last 21 days. Last non-zero bid-ask spread
            %   -----------------------------------------------------------

            M3D_stats_bid_ask_spread(12, maturity_run, run_country) = ...
                                            Vector(end);
            
                                
        end % this refers to the loop for each currency
                        
        
    end     % this refers to the loop for each currency
 
    
    RFR_06B_Bid_Ask_statistics_writing_excel_results  ...
                   (RFR_Str_config, RFR_Str_lists, date_calc, ...
                      VecRow_terms, M3D_stats_bid_ask_spread)

end

