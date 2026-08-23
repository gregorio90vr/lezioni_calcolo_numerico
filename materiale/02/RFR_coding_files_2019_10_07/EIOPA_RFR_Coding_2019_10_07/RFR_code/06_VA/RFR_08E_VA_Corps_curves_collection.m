function [M2D_EUR_corps_yields, M2D_GBP_corps_yields, M2D_USD_corps_yields] = ...
                RFR_08E_VA_Corps_curves_collection ...
                  (config, date_calc, ER_no_VA, k_factor) 

               
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   This funtion delivers three matrices with corporate yield curves
    %   as of date of calculation for the Euro, GBP and USD

    %   Each matrix has 
    
    %       14 rows, 7 for financial and 7 for non-financial curves     
    %           Credit Quality Steps are organized in rows(7)
    
    %       600 columns with the market yield rate for durations 1 to 60
    %       Durations are considered with decimal positions(0.1 to 60)

      
       
%   =======================================================================
%%  1. Loading configuration data and corporate curves   
%   =======================================================================
    
    %   Loading to workspace the configuration data
    %   -------------------------------------------    

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
        %   number of the column in cell array
        %   config.RFR_Str_lists.C2D_list_curncy containing ISO3166
        %   for each of the currencies / cou       
    
        
    %   Loading to workspace historical series of corporate bonds curves
    %   -------------------------------------------------------------------
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'Str_Corporates'; 
    
    load(fullfile(folder_download, file_download));
    %   Name of the MatLab numeric 2-D matrix with the historical
    %   serie of interest rates for the currency of each run

   
    
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
        %  (14 rows per Euro , GBP and USD)
        
    M2D_EUR_corps_yields = zeros(14, 600);
    M2D_GBP_corps_yields = zeros(14, 600);
    M2D_USD_corps_yields = zeros(14, 600);


    
%   =======================================================================
%%  3. Extracting market yields as of date of calculation   
%   =======================================================================
        
    % for the time being USD corporate curves = GBP corps curves
    % this will be fixed as soon as access to iBoxx index is available
    % This does not influence the coding, but the content of
    % structure  'Str_Corporates'

    % GBP and USD corporate curves for CQS4 and CQS5 are those of the Euro
    % The k factor should be applied after the main loop
    % See sub-sections 4.1. and 4.2 below in this function
    
    
    %%   3.1. Main loop for each corporate bond curve
    %   ---------------------------------------------          

    
    for run_corps = 1:num_corps 

        run_CQS = rem(run_corps - 1 , 7);
       
        
        if run_CQS == 0  ||  run_CQS == 6    
           continue
            % At the end of the loop CQS0 will be calculated as 0.85 * CQS1
            % After the main loop, CQS6 will be equal to CQS5
        end
        

        if run_corps <= 7 
           name_corp_curve = strcat('EUR_Finan_' , num2str(run_CQS) , '_iBoxx_yields');
           name_corp_terms = strcat('EUR_Finan_' , num2str(run_CQS) , '_iBoxx_durations');
%            name_output_matrix = 'M2D_EUR_corps_yields';
           currency = 'EUR';
           row_write = 0;
        end
        
        if run_corps >  7  &&  run_corps <= 14
           name_corp_curve = strcat('EUR_Nonfinan_' , num2str(run_CQS) , '_iBoxx_yields');
           name_corp_terms = strcat('EUR_Nonfinan_' , num2str(run_CQS) , '_iBoxx_durations');
%            name_output_matrix = 'M2D_EUR_corps_yields';
           currency = 'EUR';
           row_write = 1;
        end
        
        if run_corps > 14  &&  run_corps <= 21
           name_corp_curve = strcat('GBP_Finan_' , num2str(run_CQS) , '_iBoxx_yields');
           name_corp_terms = strcat('GBP_Finan_' , num2str(run_CQS) , '_iBoxx_durations');
%            name_output_matrix = 'M2D_GBP_corps_yields';
           row_write = 0;
           currency = 'GBP';
        end

        if run_corps > 21  &&  run_corps <= 28
           name_corp_curve = strcat('GBP_Nonfinan_' , num2str(run_CQS) , '_iBoxx_yields');
           name_corp_terms = strcat('GBP_Nonfinan_' , num2str(run_CQS) , '_iBoxx_durations');
%            name_output_matrix = 'M2D_GBP_corps_yields';
           row_write = 1;
           currency = 'GBP';
        end

        if run_corps > 28  &&  run_corps <= 35
           name_corp_curve = strcat('USD_Finan_' , num2str(run_CQS) , '_iBoxx_yields');
           name_corp_terms = strcat('USD_Finan_' , num2str(run_CQS) , '_iBoxx_durations');
%            name_output_matrix = 'M2D_USD_corps_yields';
           currency = 'USD';
           row_write = 0;
        end

        if run_corps > 35  &&  run_corps <= 42
           name_corp_curve = strcat('USD_Nonfinan_' , num2str(run_CQS) , '_iBoxx_yields');
           name_corp_terms = strcat('USD_Nonfinan_' , num2str(run_CQS) , '_iBoxx_durations');
%            name_output_matrix = 'M2D_USD_corps_yields';
           currency = 'USD';
           row_write = 1;
        end
        
        M2D_curve = Str_Corporates_iBoxx_Bid.(name_corp_curve);
        M2D_terms = Str_Corporates_iBoxx_Bid.(name_corp_terms);

        %   From now on, the corporate bonds curves for all dates 
        %   will be in  'M2D_curve', whose first column are dates
        %   being rest of columns either maturities(if we use curves)
        %   or buckets(if we use indices in buckets)
        %   'M2D_terms' contains the maturities of each bucket and
        %   at each date.

        % Find the first non-empty row equal to or before the calculation
        % date.
        
        for dt = 1:size(M2D_curve, 1)
            row_date_calc = find(M2D_curve(:,1) <= (date_calc - dt + 1), 1, 'last');
            act_date_calc = M2D_curve(row_date_calc,1);
            
            V1R_corps_curve = M2D_curve(row_date_calc , 2:end);
            V1R_corps_terms = M2D_terms(row_date_calc , 2:end); 
            
            nonzeros = (V1R_corps_curve ~= 0);
            
            if any(nonzeros)
                break
            end
            
        end
        
        if act_date_calc ~= config.refDate
            info = [name_corp_curve, ': Using ', datestr(act_date_calc, 'dd/mm/yyyy'), ...
                ' instead of ', datestr(config.refDate, 'dd/mm/yyyy'), '.'];
            RFR_log_register('06_VA', 'RFR_08E_VA_Corps_curves_collection', 'WARNING', info, config);
        end

        if run_CQS < 4

            [V1R_corps_curve_complete , ~] = ...
                        interpolator_curves(V1R_corps_curve , ...
                                              V1R_corps_terms);

            %   Function  'interpolator_curves'  returns the curve with
            %   market rates inter/extrapolated for all maturities 
            %   with 1 decimal position until 60 years(600 values)
            %   'V1R_govt_curve' is a row vector with 600 columns
            %  (rates for durations 0.1, 0.2, 0.3,... 1, 1.1,...600)
            %   The second output is row vector(1 : 1; 600)

            %   This functions removes terms without market rates
            %   In case of having no market rates or only one
            %   the funtion returns zero vectors

        end

        if run_CQS == 4  ||  run_CQS == 5
            V1R_corps_curve_complete = V1R_corps_curve(1) * ...
                                            ones(1 , 600);
        end

    
        %   writing the curve in the relevant row of the 2-dimensional
        %   matrix recieving the outputs
        if strcmp(currency, 'EUR')
            M2D_EUR_corps_yields((run_CQS + 1 + row_write*7),:) = V1R_corps_curve_complete;
        elseif strcmp(currency, 'GBP')
            M2D_GBP_corps_yields((run_CQS + 1 + row_write*7),:) = V1R_corps_curve_complete;
        elseif strcmp(currency, 'USD')
            M2D_USD_corps_yields((run_CQS + 1 + row_write*7),:) = V1R_corps_curve_complete;
        end
    end

    
        
%   =======================================================================
%%  4. Special cases
%   =======================================================================


%%  4.1. Application of k-factor to GBP rates for CQS4 and CQS5
%   -----------------------------------------------------------------------

    row_EUR = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166), 'EUR');
    row_GBP = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166), 'GBP');

    V1R_spread_GBP_EUR = 100 * ...
                       (ER_no_VA.M2D_SW_spot_rates(row_GBP, 1:60) -...
                          ER_no_VA.M2D_SW_spot_rates(row_EUR, 1:60));

    [V1R_spread_GBP_EUR_with_decimals,~] =  interpolator_curves ...
                          (V1R_spread_GBP_EUR, 1:60);

    M2D_GBP_corps_yields([ 5:6  12:13] , :) = ...
                M2D_EUR_corps_yields([ 5:6  12:13] , :) +...
               (1 + k_factor) * repmat(V1R_spread_GBP_EUR_with_decimals, 4, 1);


%%  4.2. Application of k-factor to USD rates for CQS4 and CQS5
%   -----------------------------------------------------------------------

    row_EUR = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166), 'EUR');
    row_USD = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166), 'USD');

    V1R_spread_USD_EUR = 100 * ...
                       (ER_no_VA.M2D_SW_spot_rates(row_USD, 1:60) -...
                          ER_no_VA.M2D_SW_spot_rates(row_EUR, 1:60));

    [V1R_spread_USD_EUR_with_decimals,~] =  interpolator_curves ...
                          (V1R_spread_USD_EUR, 1:60);

    M2D_USD_corps_yields([5:6 12:13],:) = ...
                M2D_EUR_corps_yields([5:6 12:13],:) +...
               (1 + k_factor) * repmat(V1R_spread_USD_EUR_with_decimals, 4, 1);
            
            
%%  4.3. CQS0 calculated as 85%(115% in case of neg. yields) of CQS1
%   -----------------------------------------------------------------------

    M2D_EUR_corps_yields([1 8],:) = M2D_EUR_corps_yields([2 9],:) - ...
        0.15*abs(M2D_EUR_corps_yields([2 9],:)); 
    M2D_GBP_corps_yields([1 8],:) = M2D_GBP_corps_yields([2 9],:) - ...
        0.15*abs(M2D_GBP_corps_yields([2 9],:)); 
    M2D_USD_corps_yields([1 8],:) = M2D_USD_corps_yields([2 9],:) - ...
        0.15*abs(M2D_USD_corps_yields([2 9],:)); 
    

%%  4.4. CQS6 equal to CQS5
%   -----------------------------------------------------------------------

    M2D_EUR_corps_yields([7 14],:) = M2D_EUR_corps_yields([6 13],:); 
    M2D_GBP_corps_yields([7 14],:) = M2D_GBP_corps_yields([6 13],:); 
    M2D_USD_corps_yields([7 14],:) = M2D_USD_corps_yields([6 13],:); 
    
                        
    
