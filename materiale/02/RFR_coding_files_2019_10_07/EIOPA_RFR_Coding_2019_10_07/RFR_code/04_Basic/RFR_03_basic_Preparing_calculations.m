function  [Str_assumptions, M2D_raw_curves, M2D_DLT] = ...
                        RFR_03_basic_Preparing_calculations ...
                                (config, date_calc)

                            
%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------

    %   This funtion starts launching a dialog box where the user selects
    %   the date of reference of the curves  ( 'date_calc' )

    %   Once selected such date, this function organizes the information 
    %   in order to run the next steps of the calculation
    %   in the following functions

    %   The function begins (part 1) loading those inputs whose value
    %   is the same for all currencies

    %   Afterwards, there is a loop (part 2) to load the currency/country 
    %   specific inputs

%   OUTPUTS OF THIS FUNTION  ----------------------------------------------

%   This funtion launches a dialog box where the user selects
%   the date of reference of the curves  ( 'date_calc' )

%   Once selected such date, the relevant market data for each currency
%   ( either swap rates or government bond rates ) are extracted
%   and gather in the 2-dimensional matrix  'M2D_raw_curves'

%   NOTE 1: In the case of the euro, each country is consider separately
%           in all the steps of the calculation.
%           Then, the respective risk free interest rates term structures
%           are calculated for each country 
%           (because of the 'national volatility adjustment')

%   NOTE 2: The information is prepared in cell arrays,matrices and vectors
%           according to the following rule

%               Each row refers to each currency / country
%                   In case of a country without market data
%                   its raw is retained with zeros

%               Each column refers to each term or maturity observed in
%                   financial markets (both ADLT and non-ADLT)

%   The list of DLT maturities for each currency is also expressed
%   in the 2-dimensional matrix  'M2D_DLT'

%   MatLab structure  'Str_assumptions'  store for each currency
%   each of the assumptions relevant for the extrapolation process
%   ( extrapolation is carried out at a later stage below
%     in a different function )




%  ------------------------------------------------------------------------
%%  1. Loading variables common to the following steps within this function

        %  Part 1.A. Loading to workspace the configuration data 
        
        %  Part 1.B. Matrices DLT
        
        %  Part 1.C. MatLab structure with the assumptions for extrapolation 
        
        %  Part 1.D. Matrices market raw rates for the financial instrument
        %            and DLT information for each possible maturities
 
        

%%  2. Loop for each currency in order to prepare currency specific inputs

        % 2.A.  Skipping where the country belongs to the Euro Area
        
        % 2.B.  Filling in variables whose content is currency specific
        
        % 2.C.  Cell array column with the name of each curve (including their respective parameters)
        
        % 2.D   Historical interest rates for the selected date and for the currency in each run of the loop
        
        % 2.E. Assumptions to use for the exrapolation of each currency 
        
% --------------------------------------------------------------------- 
 



%  ------------------------------------------------------------------------
%%  1. Loading variables common to the following steps within this function
%  ------------------------------------------------------------------------

        %  Part 1.A. Loading to workspace the configuration data 
        
        %  Part 1.B. Matrices DLT
        
        %  Part 1.C. MatLab structure with the assumptions for extrapolation 
        
        %  Part 1.D. Matrices market raw rates for the financial instrument
        %            and DLT information for each possible maturities
         
 %  ------------------------------------------------------------------------    
    
   
    
    % 1.A.  Loading to workspace the configuration data
    % -------------------------------------------------    

  % col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country ;
    col_ISO3166      = config.RFR_Str_lists.Str_numcol_curncy.ISO3166      ;
    col_currency     = config.RFR_Str_lists.Str_numcol_curncy.Currency     ;    
  % col_ISO4217      = config.RFR_Str_lists.Str_numcol_curncy.ISO4217      ;
  % col_EEA          = config.RFR_Str_lists.Str_numcol_curncy.EEA          ;
    col_gvt_coupon   = config.RFR_Str_lists.Str_numcol_curncy.gvt_coupon   ;    
    col_swp_coupon   = config.RFR_Str_lists.Str_numcol_curncy.swp_coupon   ;
    col_SWP_GVT      = config.RFR_Str_lists.Str_numcol_curncy.SWP_GVT      ;
    col_LLP_GVT      = config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT      ;
    col_LLP_SWP      = config.RFR_Str_lists.Str_numcol_curncy.LLP_SWP      ;
  % col_convergence  = config.RFR_Str_lists.Str_numcol_curncy.convergence  ;
    col_UFR          = config.RFR_Str_lists.Str_numcol_curncy.UFR          ;

        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered 
        %   the information identified in the name of each variable
        

    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    file_download = 'RFR_basic_curves';       
    
    %   Name of the MatLab numeric 2-D matrix with the historical
    %   serie of interest rates for the currency of each run

    load(fullfile(folder_download, file_download), 'RFR_download_BBL_Mid');
    list_curves_stored = fieldnames(RFR_download_BBL_Mid);


    
    num_terms = size(config.RFR_Str_lists.C2D_years_formats , 1);

        %   number of points of the curve of the historical serie
        %   (i.e. number of maturities, in increasing order, potentially
        %    observable in financial markets, both ADLT and non-ADLT )  
        
    num_currencies = size(config.RFR_Str_lists.C2D_list_curncy, 1);
   
        %   'RFR_Str_lists.C2D_list_curncy' is a 2-D cell array 
        %   with the list of countries/currencies in rows
        %   and Bloomberg tickers of the three basic interest rates curves
        %   ( governments, swaps and OIS)
        
      
        
        
    % 1.B.  Matrices DLT 
    % ---------------------------------------------------------------------

    %   Information on DLT maturities for each currency/country 
    %   was initially an input within excel file  'RFR_excel_config.xlsx' , 
    %   sheets  'ADLT_SWP  and  'ADLT_GVT'.
    %   Such information reflects the tables in Section 4 of 
    %   the Technical Documentation EIOPA publishes 
    
    %   Section 2.3. of function  'RFR_01_basic_setting_config.m'
    %   moved that information to two MatLab cell arrays
    %   'RFR_basic_ADLT_SWP'  and  'RFR_basic_ADLT_GVT' 
    %   in the following manner:
        
        %   Rows  = countries / currencies
        %   First 10 columns  = codes of currencies and other data
        %   Columns 11 to end = either '0' or '1' for each maturity
        %           ( 1 = DLT , 0 = non-ADLT )    

        
    %   Now, in this part of this function the DLT maturities for each
    %   currency/country will be stored in 2-dimensional matrices 
    %   DLT_SWP (for swaps) and DLT_GVT (for government bonds) 

  
    
    folder_ADLT = config.RFR_Str_config.folders.path_RFR_01_Config ; 
    file_ADLT = 'EIOPA_RFR_config' ;

    load(fullfile(folder_ADLT, file_ADLT), 'RFR_basic_ADLT_GVT', 'RFR_basic_ADLT_SWP');

   %    The following instructions create two 2-dimensional matrices 
   %    with zeros and ones 
   %    (identifying non-DLT and DLT maturities respectively)
   %    Therefore the aforementioned 10 first columns 
   %    with rather qualitative information are disregarded 
    
    DLT_GVT = config.RFR_basic_ADLT_GVT(:,11:end);
    DLT_GVT = cell2mat(DLT_GVT);
        
    DLT_SWP = config.RFR_basic_ADLT_SWP(:, 11:end);
    DLT_SWP = cell2mat(DLT_SWP);
    
        %  After these instructions only columns for each maturity remain
        
        %  Rows    = country / currency
        %  Columns = All possible maturities in sequencial order
        %  Value   =   0   for maturity and country DLT requirements not met
        %              1   for maturity and country DLT requirements are met

        

    % 1.C.  MatLab structure with the assumptions for extrapolation 
    % --------------------------------------------------------------------- 

    %   Each element of the structure contains a column vector
    %   with so many rows as countries / currencies

    Str_assumptions.VecCol_coupon_freq = zeros(num_currencies, 1); 
    Str_assumptions.VecCol_LLP         = zeros(num_currencies, 1); 
    Str_assumptions.VecCol_convergence = zeros(num_currencies, 1);
    Str_assumptions.VecCol_UFR         = zeros(num_currencies, 1);
 

    %   Minimum difference to consider convergence to UFR is reached
    
    min_diff = config.RFR_Str_lists.Parameters.SW_tolerance_convergence / 100;

       %    According to section 7.D of EIOPA Technical Documentation
       %    (as published October, 27th, 2015)
       %       RFR_Str_lists.Parameters.SW_tolerance_convergence = 1 bp

       %    This parameter is set out in sheet  'Parameters'
       %    of excel file   'RFR_excel_confing.xlsx'
       %    and moved to  'RFR_Str_lists.Parameters'  in section 2.6
       %    at the end of fucntion   'RFR_01_basic_setting_config.m'
       
    Str_assumptions.VecCol_min_diff = min_diff * ones(num_currencies, 1);
    
    
    

    % 1.D.  Matrices to store market raw rates for the financial instrument
    %       and DLT information for each possible maturities
    % --------------------------------------------------------------------- 
    
    %   The following two matrices have  
    %      in rows currencies / countries
    %       each column = terms of the curve in sequence from 1 to 60 years
    %       ( e.g. 1 , 2 , 3 , ... 60 years )    
    
    M2D_raw_curves = zeros(num_currencies, num_terms);
    M2D_DLT = zeros(num_currencies, num_terms);
    

%  ------------------------------------------------------------------------
%%  3. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 

    message= {'Extracting configuration data and market data.'; ...
              ['Total of --> ', num2str(num_currencies), '--curves. ']};   

    mssge_wait_bar = waitbar(1/num_currencies, message);
    



    for count_curncy = 1:num_currencies
                
        waitbar(count_curncy/num_currencies)
      
        %   3.A. Assumptions to use for the extrapolation of each currency             
        %   --------------------------------------------------------------

            %   According to Article 44 of Regulation 2015/35/UE 
            %   swaps are used, while government bonds are a fallback
            %   option only were there is no DLT swap market for a certain
            %   maturity of a gvien currency.
            
        if strcmp(config.RFR_Str_lists.C2D_list_curncy(count_curncy,col_SWP_GVT), 'SWP')

            Str_assumptions.VecCol_coupon_freq(count_curncy) = ...
                     config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_swp_coupon}; 
            
            Str_assumptions.VecCol_LLP(count_curncy) = ...
                     config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_LLP_SWP};

        else
            
            Str_assumptions.VecCol_coupon_freq(count_curncy) = ...
                     config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_gvt_coupon}; 
            
            Str_assumptions.VecCol_LLP(count_curncy) = ...
                     config.RFR_Str_lists.C2D_list_curncy{count_curncy, col_LLP_GVT};

        end
        
        Str_assumptions.VecCol_UFR(count_curncy) = ...
                     config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_UFR};
                
        
                 
        %   The following instruction means to override the input data
        %   contained in   column AS   of sheet   'C2D_list_currency'
        %   of excel file   'RFR_excel_config.xlsx'
        
        %   That column have been retained just in case 
        %   there is a decision in the future to apply convergence periods
        %   specific for each currency 
        
        
        Str_assumptions.VecCol_convergence(count_curncy) =...
                max(40, 60 - Str_assumptions.VecCol_LLP(count_curncy));
                    
         
        
                
        % 3.B.  Country belonging to the Euro Area
        %       Euro curve should be calculated in the first run
        % ----------------------------------------------------------------- 

        if strcmp(config.RFR_Str_lists.C2D_list_curncy(count_curncy,col_currency), 'Euro')
           
           if ~strcmp(config.RFR_Str_lists.C2D_list_curncy(count_curncy,col_ISO3166), 'EUR')
               
               %  Reaching this point means that the row refers to
               %  a country belonging to the euro zone,
               %  but not the 'EUR' in itself (which is the first run/row)
                
                M2D_raw_curves(count_curncy,:) = ...
                                        M2D_raw_curves(1,:);
                                    
                M2D_DLT(count_curncy,:) = M2D_DLT(1,:); 
                
                % first run refers to Euro zone as a whole
                continue
           end
        end

        
           
        % 3.C.  Filling in variables whose content is currency specific
        %       but they do not depends on whether the curve to use 
        %       is either 'swap' or 'govt'
        % ----------------------------------------------------------------- 
                
        code_curncy_run = ...
             config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_ISO3166};    
 
        
            
        
        %   3.D  Historical interest rates for the selected date and
        %        for the currency in each run of the loop             
        %   ----------------------------------------------------------           

        %   Control of whether the curve does not exist
        %   (i.e. it is not observable in financial markets)
        
        
        if strcmp(config.RFR_Str_lists.C2D_list_curncy(count_curncy, col_SWP_GVT), 'SWP')
 
            name_store_swp = strcat(code_curncy_run, '_RAW_SWP_BBL');
                % this instruction should be before the follwoing 'if'
                % otherwise the log message in 'else' will not identify 
                % the right sentence
 
            if any(strcmp(list_curves_stored, name_store_swp))
                M2D_curves_serie_swp = RFR_download_BBL_Mid.(name_store_swp);
                %   Identifying the row of the matrix  'curves_serie'
                %   whose data correspond to the selected date of calculation

                var_aux = (M2D_curves_serie_swp(:,1) <= date_calc);
                posic_date_calc = find(var_aux == 1, 1, 'last');

                M2D_raw_curves(count_curncy,:) = ...
                               M2D_curves_serie_swp(posic_date_calc,2:end);           
                M2D_DLT(count_curncy,:) = DLT_SWP(count_curncy,:); 
                
                llp = config.RFR_Str_lists.C2D_list_curncy{count_curncy,...
                    config.RFR_Str_lists.Str_numcol_curncy.LLP_SWP};
                
                lastDate = date_calc;
                abort = false;
                
                
                while ~isSufficient(M2D_raw_curves(count_curncy,:), M2D_DLT(count_curncy,:), llp)
                    
                    lastDate = busdate(lastDate, 'previous', NaN);
                    
                    % Edge case that no data is available 
                    if lastDate < M2D_curves_serie_swp(1,1)
                        M2D_raw_curves(count_curncy,:) = 0;
                        
                         info = [name_store_swp ': There is no data to calculate the historical RFR'...
                                    ' for  ' datestr(date_calc) '.'];
                        RFR_log_register('00_Basic', 'RFR_03_Preparing', 'WARNING', info,...
                            config);
                        abort = true;
                        break
                    end
                    
                    var_aux = (M2D_curves_serie_swp(:,1) <= lastDate);
                    posic_date_calc = find(var_aux == 1, 1, 'last');
                    
                    M2D_raw_curves(count_curncy,:) = ...
                               M2D_curves_serie_swp(posic_date_calc,2:end);
                end
                
                % No data, continue with the next currency/country
                if abort
                    continue
                end
                
                if lastDate ~= date_calc
                    message_1 = [name_store_swp,': There are no sufficient market data for the date the user has selected: ',...
                            datestr(date_calc), 'The nearest previous date with enough information '...
                            'will be used in the calculations: ',...
                        datestr(lastDate)];
                    
                    warning(message_1);
                    info = [name_store_swp ': Instead of ' datestr(date_calc) ', the actual date of'...
                        ' calculation due to LLP and DLT criterion has been identified to be ', datestr(lastDate)];
                    RFR_log_register('00_Basic', 'RFR_03_Preparing', 'WARNING', info,...
                        config);
                end
            else
                %   Currencies pegged to the euro. DKK and BGN
                %   ------------------------------------------------------- 

                if strcmp(code_curncy_run, 'BGN') || ...
                    strcmp(code_curncy_run, 'DKK')     

                    M2D_DLT(count_curncy,:) = M2D_DLT(1,:);
                    M2D_raw_curves(count_curncy,:) = M2D_raw_curves(1,:);           
                else
                
                    %   for the currency of this run the config identifies
                    %   swaps as financial instrumente of reference, 
                    %   but there is no market database 

                    info = ['Calc_date: ' datestr(date_calc) ', Database ' , name_store_swp,...
                        ' doesn''t exist. Currency cannot be processed.'];
                    RFR_log_register('00_Basic', 'RFR_03_Preparing', ...
                        'WARNING', info, config);     
                    continue
                end
            end
        end
     
        
        
        if strcmp(config.RFR_Str_lists.C2D_list_curncy(count_curncy,col_SWP_GVT), 'GVT')
            
            name_store_gvt = strcat(code_curncy_run, '_RAW_GVT_BBL');
                % this instruction should be before the follwoing 'if'
                % otherwise the log message in 'else' will not identify 
                % the right sentence
   
            if any(strcmp(list_curves_stored, name_store_gvt))
                M2D_curves_serie_gvt = RFR_download_BBL_Mid.(name_store_gvt);
                %   Identifying the row of the matrix  'curves_serie'
                %   whose data correspond to the selected date of calculation

                var_aux = (M2D_curves_serie_gvt (:,1) <= date_calc);
                posic_date_calc = find(var_aux == 1, 1, 'last');
            
                M2D_raw_curves(count_curncy,:) = ...
                        M2D_curves_serie_gvt(posic_date_calc,2:end);
            
                M2D_DLT(count_curncy,:) = DLT_GVT(count_curncy,:); 
                
                llp = config.RFR_Str_lists.C2D_list_curncy{count_curncy,...
                    config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT};
                
                lastDate = date_calc;
                abort = false;
                
               while ~isSufficient(M2D_raw_curves(count_curncy,:), M2D_DLT(count_curncy,:), llp)
                   
                    lastDate = busdate(lastDate, 'previous', NaN);
                    
                    % Edge case that no data is available 
                    if lastDate < M2D_curves_serie_gvt(1,1)
                        M2D_raw_curves(count_curncy,:) = 0;
                        
                         info = [name_store_gvt ': There is no data to calculate the historical RFR'...
                                    ' for  ' datestr(date_calc) '.'];
                        RFR_log_register('00_Basic', 'RFR_03_Preparing', 'WARNING', info,...
                            config);
                        abort = true;
                        break
                    end
                    
                    var_aux = (M2D_curves_serie_gvt(:,1) <= lastDate);
                    posic_date_calc = find(var_aux == 1, 1, 'last');
            
                    M2D_raw_curves(count_curncy,:) = ...
                                    M2D_curves_serie_gvt(posic_date_calc,2:end);
               end
                
               % No data, continue with the next currency/country
                if abort
                    continue
                end
                
                if lastDate ~= date_calc
                    message_1 = [name_store_gvt,': There are no sufficient market data for the date the user has selected: ',...
                            datestr(date_calc), 'The nearest previous date with enough information '...
                            'will be used in the calculations: ',...
                        datestr(lastDate)];
                    
                    warning(message_1);
                    info = [name_store_gvt ': Instead of ' datestr(date_calc) ', the actual date of'...
                        ' calculation due to LLP and DLT criterion has been identified to be ', datestr(lastDate)];
                    RFR_log_register('00_Basic', 'RFR_03_Preparing', 'WARNING', info,...
                        config);
                end
            else
      
                %   for the currency of this run the config identifies
                %   government bonds as financial instrumente of reference, 
                %   but there is no market database 
                
                info = ['Calc_date: ' datestr(date_calc) ', Database ' , name_store_gvt,...
                        ' doesn''t exist. Currency cannot be processed.'];
                RFR_log_register('00_Basic', 'RFR_03_Preparing',...
                    'WARNING', info, config);     
                continue
                
            end
        end                  
    end     % this refers to the loop for each currency
 
    close(mssge_wait_bar)          
%   -----------------------------------------------------------------------
%%  4. Saving the workspace ( for the descriptive volatility analysis )
%   -----------------------------------------------------------------------

%     save(fullfile(config.RFR_Str_config.folders.path_RFR_99_Workspace, ...
%                         'RFR_02_preparing_calculations_workspace'))

end

function valid = isSufficient(marketData, dltPoints, llp)
    valid = false;
    
    testVector = (marketData ~= 0) & dltPoints;
    llpAvailable = testVector(llp);
    
    if llpAvailable && (sum(testVector) / sum(dltPoints)) >= 0.8
        valid = true;
    end
end