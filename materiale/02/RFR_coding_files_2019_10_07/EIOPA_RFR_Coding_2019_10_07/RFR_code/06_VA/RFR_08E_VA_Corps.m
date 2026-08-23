function [Str_VA,Str_PD_CoD_outputs] = ...
                RFR_08E_VA_Corps(config, date_calc, ...
                                   ER_no_VA, Str_VA, type_VA, ...
                                   Str_LTAS, Str_PD_CoD_calc, k_factor) 
    
   
%   =======================================================================
%%  Explanation of this function 
%   =======================================================================

    %   This funtion calculates the three internal effective rates
    %   referred to the portfolio of corporates bonds
    %   necessary to calculate the VA.
    %   Its conceptual framework proceeds from sections 9.C  and 10. of
    %   EIOPA Technical Documentation(published October 27th, 2015)
    
    %   -------------------------------------------------------------------
    
    %   INPUTS
    
    %   For risk-free rates: Structure  'ER_no_VA', 
    %                        element    'M2D_SW_spot_rates'
    %                       (function  'RFR_06A_extrapol_main_loop.m')
    
        %   'ER_no_VA.M2D_SW_spot_rates' is a 2-dimensional matrix 
        %   with the basic risk-free curves as of date calculation
        %   for all currencies(rows) and for maturities 1 to 150
        %  (150 columns)The output is a MatLab structure Str_VA with the same name

    %   For LTAS of corporate bonds:   
    %               Structure 'Str_LTAS'
    %               element   'Corps.M2D_corps_LTAS_spreads_rec'
    %              (function 'RFR_08A_LTAS_Corps')
    %   For LTAS of non-central government bonds
    %               Structure 'Str_LTAS'
    %               element   'Govts.M2D_govts_LTAS_spreads_rec'
    %              (function 'RFR_08A_LTAS_Govts')
    %               
    
    %   For default statistics to consider in the calculation of PD and CoD
    %               Structure 'Str_PD_CoD_calc'
    
    %   For insurance market data: Structure 'Str_VA'
    %   IMPORTANT:  This structure is also the output of this function
    %               The output retains the information input
    %               adding the calculations as desribed below
    
    %   -------------------------------------------------------------------
    
    %   OUTPUT
    
    %   Structure 'Str_VA'. It contains all the insurance market data used
    %                       in the calculations + FIVE new elements
    %                       calculated in this funtion
    
    %   Str_VA.Govts.M2D_corps_yield_b 
    %       2-dimensional matrix with countries in rows and
    %       as many columns as governments issuers, which are defined
    %       by the second dimension of ' Str_VA.Corps.M2D_corps_portfolio'
    %       This element contains the market yield as of date calculation
    %       for the exposure of each country(row) to each issuer(column)
    %       The market yield is NOT risk-corrected
    
    %   Str_VA.Corps.M2D_corps_fs
    %       2-dimensional matriz with the same design as the previous one
    %       This element contains the fundamental spread date calculation
    %       for the exposure of each country(row) to each issuer(column)

    %   Str_VA.Corps.M2D_corps_yield_a
    %       2-dimensional matriz with the same design as the previous one
    %       This element contains the market yield as of date calculation
    %       for the exposure of each country(row) to each issuer(column)
    %       AFTER risk-correction
    
    %   Str_VA.Corps.M2D_corps_rfr
    %       2-dimensional matriz with the same design as the previous one
    %       This element contains the risk-free rate as of date calculation
    %       for the exposure of each country(row) to each issuer(column)
    
    %   Str_VA.Corps.M2D_corps_IER 
    %       2-dimensional matrix with countries in rows and 3 columns
    %       It contains the internal effective rate of corporate bonds
    %       portfolio,
    %           First column .- Based on market yield NOT corrected
    %           Second column.- Based on risk-free rates
    %           Third column .- Based on market yeld AFTER risk correction
    
%   =======================================================================    
   
       
%   =======================================================================
%%  1. Loading configuration data, insurance market data, government and corporate curves   
%   =======================================================================

    
    %   Loading to workspace the configuration data
    %   -------------------------------------------    
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    
        %   number of the column in cell array
        %   config.RFR_Str_lists.C2D_list_curncy containing ISO3166
        %   for each of the currencies / countries considered

        
    %   Loading to workspace VA data
    %   --------------------------------------     
    %   Not necessary because the information is in the input  'Str_VA'
        
    
    %   Loading to workspace historical series of basic risk-free curves
    %   -------------------------------------------------------------------
        
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'RFR_basic_curves';           
        %   Name of the MatLab numeric 2-D matrix with the historical
        %   serie of interest rates for the currency of each run
        
    load(fullfile(folder_download, file_download));

       
    
    %   Loading to workspace historical series of corporate bonds curves
    %   -------------------------------------------------------------------
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'Str_Corporates'; 
    
    load(fullfile(folder_download, file_download));
    %   Name of the MatLab numeric 2-D matrix with the historical
    %   serie of interest rates for the currency of each run

    
    
    %   Loading to workspace legal-technical pre-defined parameters
    %   -----------------------------------------------------------
    
    recov_rate = config.RFR_Str_lists.Parameters.FS_recovery_rate;
    
    V1C_inception_factor = config.RFR_Str_lists.Parameters.Veccol_CoD_spreads_CQS;
    initial_factor       = config.RFR_Str_lists.Parameters.CoD_average_duration;
    
    FS_percent_LTAS_Corps = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Corps;
            
       %    These parameters are set out in sheet  'Parameters'
       %    of excel file   'RFR_excel_confing.xlsx'
       %    and moved to  'config.RFR_Str_lists.Parameters'  in section 2.6
       %    at the end of fucntion   'RFR_01_basic_setting_config.m'
    
       
    
    Str_PD_CoD_outputs = Str_PD_CoD_calc;
    

    
    
%   =======================================================================
%%  2. Creation of matrices for storing corporate bonds outputs 
%   =======================================================================
    
    Str_VA.Corps.M2D_corps_yield_b = zeros(size(Str_VA.Corps.M2D_corps_portfolio));
    Str_VA.Corps.M2D_corps_fs      = zeros(size(Str_VA.Corps.M2D_corps_portfolio));
    Str_VA.Corps.M2D_corps_yield_a = zeros(size(Str_VA.Corps.M2D_corps_portfolio));
    Str_VA.Corps.M2D_corps_rfr     = zeros(size(Str_VA.Corps.M2D_corps_portfolio));
    
    Str_VA.Corps.M2D_corps_IER = zeros(length(Str_VA.C1C_countries), 5);
    
    

%   =======================================================================
%%  3. Corporate yield curves as of the date of calculation 
%   =======================================================================

    [ M2D_EUR_corps_yields_decimals, ...
      M2D_GBP_corps_yields_decimals, ...
      M2D_USD_corps_yields_decimals ] = ...
                  RFR_08E_VA_Corps_curves_collection ...
                     (config, date_calc, ER_no_VA, k_factor);
    


%   =======================================================================
%%  4. Loop for each currency / market(regardless they have or not VA) 
%   =======================================================================


    num_countries = length(Str_VA.C1C_countries);
    
    message = {'Calculating corporate portfolios. Total of ',num2str(num_countries),' countries. ',...
               'Date = ',datestr(date_calc, 24) };   

    mssge_wait_bar = waitbar(1/num_countries, message);
           


    for run_country =  1:length(Str_VA.C1C_countries)

        %   'Str_VA.C1C_countries'  is a cell array column with ISO3166
        %   for all possible countries/ currencies,
        %   regardless they have or not VA
              
        waitbar(run_country / num_countries)
        
        id_country = config.RFR_Str_lists.C2D_list_curncy{run_country, col_ISO3166};
        id_curncy  = config.RFR_Str_lists.C2D_list_curncy{run_country, col_ISO4217}; 
                
        
        %%  4.1. Identifying basic risk-free curves and market yield corporate bonds curves for each country
        %   ------------------------------------------------------------------------------------------------
        
        row_country = strcmp(id_country, config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));

        V1R_RFR_curncy_yearly = 100 * ER_no_VA.M2D_SW_spot_rates(row_country, 1:60);
        
        [V1R_RFR_curncy_with_decimals,~] = interpolator_curves ...
                               (V1R_RFR_curncy_yearly, 1:60);
        
                            
        if strcmp('EUR', id_curncy)  
           M2D_corps_yields_decimals = M2D_EUR_corps_yields_decimals;            
           M2D_corps_LTAS_yearly     = Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec( 1:14, :);               
        elseif strcmp('GBP', id_curncy)  
           M2D_corps_yields_decimals = M2D_GBP_corps_yields_decimals;            
           M2D_corps_LTAS_yearly     = Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(15:28, :);               
        elseif strcmp('USD', id_curncy)  
           M2D_corps_yields_decimals = M2D_USD_corps_yields_decimals;            
           M2D_corps_LTAS_yearly     = Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(29:42, :);               
        end
        
        
        %   Addition kappa *(RFR_curncy - RFR_euro) for those currencies
        %   without yield corporate curves(subsection 10.C.4. of
        %   EIOPA Technical Documentation (published October 27th, 2015)
        %   -----------------------------------------------------------
    
        if ~strcmp('EUR', id_curncy) && ...
           ~strcmp('GBP', id_curncy) && ...
           ~strcmp('USD', id_curncy) 

       
           V1R_RFR_EUR_yearly = 100 * ER_no_VA.M2D_SW_spot_rates(1, 1:60);
        
           [ V1R_RFR_EUR_decimals, ~ ] = interpolator_curves ...
                               (V1R_RFR_EUR_yearly, 1:60);
                            
            V1R_RFR_spread_curncy_EUR_decimals = ....
                       V1R_RFR_curncy_with_decimals - V1R_RFR_EUR_decimals;
                          
            M2D_corps_yields_decimals  = M2D_EUR_corps_yields_decimals + ...
                   (1 + k_factor) * repmat(V1R_RFR_spread_curncy_EUR_decimals, ...
                    size(M2D_EUR_corps_yields_decimals, 1), 1);                
           
           M2D_corps_LTAS_yearly = ...
               Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(1:14, :) + ...
               k_factor  *  repmat(Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(row_country, :), 14, 1);
           
            %   Element 'Basic' of the MatLab structure  'Str_LTAS'
            %   is calculated in function  'RFR_08C_LTAS_Basic_RFR.m' 
                
        end
         
        
        %%   4.2. Calculation of PD and CoD
        %   -----------------------------------------------------------

           
        %   Transition matrices to use in the calculation of PD and CoD
        %   Section 10.C.2 of EIOPA Technical Documentation(Dec.21, 2017)
        %   -------------------------------------------------------------------
       
        Trans_Matrix_Finan    = Str_PD_CoD_calc.TM_Finan;
        Trans_Matrix_Nonfinan = Str_PD_CoD_calc.TM_Nonfinan;
        
                        
        %   Yield and spreads should input to this function in unit(not %)
        %   Transition matrix should have probabilities per unit(not %)
        %   Recovery rate should be expressed in unit(not %)

        %   Outputs are expressed in basis points                                  

                              
     [CoD_Finan_bp, PD_Finan_bp,PD_Finan_prob] = PD_CoD ...
                   (V1R_RFR_curncy_yearly  / 100, recov_rate, ...
                      Trans_Matrix_Finan, V1C_inception_factor, initial_factor);
      
        
        PD_Finan_bp = round(100 * PD_Finan_bp) / 100;
        
        CoD_Finan_bp = round(100 * CoD_Finan_bp) / 100;
        
        M2D_PD_CoD_Finan =(CoD_Finan_bp + PD_Finan_bp);
                
        M2D_fund_spread_Finan = max(FS_percent_LTAS_Corps *  M2D_corps_LTAS_yearly(1:7,:), M2D_PD_CoD_Finan(1:7,:));
        
        M2D_fund_spread_Finan = round(100 * M2D_fund_spread_Finan) / 100;

 
        
        %   With the current coding, the CoD resulting from the matricial
        %   calculation will be pictured in the excel files
        %   Undertakings will need to calculate the final CoD as
        %   the maximum of(FS-PD, CoD_matricial_calculation)
        
        %   If one would like to picture in excel the final coD
        %   the following instruction should apply

        %   CoD_Finan_bp = M2D_fund_spread_Finan - PD_Finan_bp(1:7, :);

        
        Str_PD_CoD_outputs.(id_country).Finan.PD_prob = PD_Finan_prob;
        Str_PD_CoD_outputs.(id_country).Finan.FS_bp = M2D_fund_spread_Finan;
        Str_PD_CoD_outputs.(id_country).Finan.PD_bp = PD_Finan_bp;
        Str_PD_CoD_outputs.(id_country).Finan.CoD_bp = CoD_Finan_bp;
         
                         
        %   Yield and spreads should input to this function in unit(not %)
        %   Transition matrix should have probabilities per unit(not %)
        %   Recovery rate should be expressed in unit(not %)

        %   Outputs are expressed in basis points
        
                                                         
     [CoD_Nonfinan_bp,PD_Nonfinan_bp,PD_Nonfinan_prob] = PD_CoD ...
                   (V1R_RFR_curncy_yearly / 100, recov_rate, ...
                      Trans_Matrix_Nonfinan, V1C_inception_factor, initial_factor);      
        
        PD_Nonfinan_bp = round(100 * PD_Nonfinan_bp) / 100;
       
        CoD_Nonfinan_bp = round(100 * CoD_Nonfinan_bp) / 100;
        
        M2D_PD_CoD_Nonfinan =(CoD_Nonfinan_bp + PD_Nonfinan_bp);
                
        M2D_fund_spread_Nonfinan = max(FS_percent_LTAS_Corps *  M2D_corps_LTAS_yearly(8:14,:), M2D_PD_CoD_Nonfinan(1:7,:));
        
        M2D_fund_spread_Nonfinan = round(100 * M2D_fund_spread_Nonfinan) / 100;
      
        %   With the current coding, the CoD rresulting from the matricial
        %   calculation will be pictured in the excel files
        %   Undertakings will need to calculate the final CoD as
        %   the maximum of(FS-PD, CoD_matricial_calculation)
        
        %   If one would like to picture in excel the final coD
        %   the following instruction should apply

        %   CoD_Nonfinan_bp = M2D_fund_spread_Nonfinan - PD_Nonfinan_bp(1:7, :);

        
        Str_PD_CoD_outputs.(id_country).Nonfinan.PD_prob = PD_Nonfinan_prob;
        Str_PD_CoD_outputs.(id_country).Nonfinan.FS_bp = M2D_fund_spread_Nonfinan;
        Str_PD_CoD_outputs.(id_country).Nonfinan.PD_bp = PD_Nonfinan_bp;
        Str_PD_CoD_outputs.(id_country).Nonfinan.CoD_bp = CoD_Nonfinan_bp;
 
        

        %%   4.3. Internal loop for each issuer within each country
        %   -----------------------------------------------------------

        
        for run_issuer = 1:length(Str_VA.Corps.C1R_corps_issuers)

            
            %%  4.3.A. Preliminary steps in the inner loop
            %   -----------------------------------------------------------

            %   if there is no exposure in the country of 'run_country'
            %   to the corporate bonds of  'run_issuer'
            %   the run skips to the following issuer.
            
            %   The composition of the corporates bond portfolio is
            %   in the element  'Str_VA.corps.M2D_corps_portfolio'
            %   where issuers are in columns and insurance markets in rows
            
            if Str_VA.Corps.M2D_corps_portfolio(run_country,run_issuer)==0 || ...
               Str_VA.Corps.M2D_corps_durations(run_country,run_issuer)==0

               continue
            end

            
            id_issuer = Str_VA.Corps.C1R_corps_issuers{run_issuer};
                %   'Str_VA.corps.C1R_corps_issuer'  is a cell array row
                %   with ISO3166 for the indices corporate bonds 

            % run_issuer goes through the list of issuers stored in Str_VA.Govts.C1R_govts_issuers
            % which is different from the list of countries/currencies in 
            % config.RFR_Str_lists.C2D_list_curncy
            % The following variable map those 2 lists for the issuer
             
            row_issuer_in_config = strcmp(config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166), ...
                                    id_issuer);  
                                
            duration = Str_VA.Corps.M2D_corps_durations(run_country, run_issuer);
            
            %   The durations of the corporates bond portfolio is
            %   in the element  'Str_VA.corps.M2D_corps_durations'
            %   where issuers are in columns and insurance markets in rows
                        
            duration_with_decimal = round(10 * duration);            

            
                
            %%  4.3.B. Market yield curve corporate bond of the run
            %   -----------------------------------------------------------

            %   the run refers to corporte bonds curves  ------------------

            if run_issuer <= 14 
               V1R_corps_curve_with_decimals = ...
                             M2D_corps_yields_decimals(run_issuer,:);        
            end

            %   specific case for the Danish financial covered bonds 
            %   -----------------------------------------------------------
            
            if run_issuer == 1  &&  strcmp(id_country, 'DKK')
               
                for dt = 1:size(DKK_Nykredit.M2D_DKK_Nykredit, 1)
                    row_to_use = find(DKK_Nykredit.M2D_DKK_Nykredit(:,1) <= (date_calc - dt + 1), 1, 'last');
                    act_date_calc = DKK_Nykredit.M2D_DKK_Nykredit(row_to_use,1);
                    
                    if DKK_Nykredit.M2D_DKK_Nykredit(row_to_use,2) ~= 0
                        break
                    end
                end
                
                if act_date_calc ~= date_calc
                    info = ['DKK_Nykredit: Using ', datestr(act_date_calc, 'dd/mm/yyyy'), ...
                        ' instead of ', datestr(config.refDate, 'dd/mm/yyyy'), '.'];
                    RFR_log_register('06_VA', 'RFR_08E_VA_Corps', 'WARNING', info, config);
                end
               
               V1R_corps_curve_with_decimals = ones(1, 600) * ...
                         DKK_Nykredit.M2D_DKK_Nykredit(row_to_use,2); 
               
               DKK_dur = DKK_Nykredit.Duration_DKK_Nykredit(row_to_use,2);
               Str_VA.Corps.M2D_corps_durations(run_country,run_issuer) = round(DKK_dur,1);
               
               duration_with_decimal = round(10 * DKK_dur);
            end
            
            
            %   the run refers to Non-central government bonds  -----------

            if run_issuer > 14
               %   Non central government bonds are treated as 
               %   central government bonds of the country
               %  (regardless the issuer)
                
               %   In case of a country without government curve,
               %   the government curve of a peer country is assigned
               %   These countries without government curve are in 
               %   the first column of   'Str_VA.Govts.C2D_peer_countries'
               %   while the peer country with government curve is in
               %   the second column
 
               if strcmp('Currency', type_VA)
                   
                   row_peer_country = strcmp(id_issuer, Str_VA.Govts.C2D_peer_countries(:,1));

                   if sum(row_peer_country) > 0
                        id_issuer = Str_VA.Govts.C2D_peer_countries {row_peer_country,2};
                   end
                   
                   % If EUR VA and the issuer is a member of the euro area, the ECB
                   % curve should be selected
                   
                   if run_country == 1 && ...
                      strcmp(config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config, col_ISO4217}, ...
                                 'EUR')
                      
                       id_issuer = 'EUR';
               
                   end
                   
                   M2D_curve = RFR_download_BBL_Mid.(strcat(id_issuer, '_RAW_GVT_BBL'));

               else    % the function is calculating the country VA
                   
                   row_peer_country = strcmp(id_issuer, Str_VA.Govts.C2D_peer_countries(:,1));

                   if sum(row_peer_country) > 0
                        id_issuer = Str_VA.Govts.C2D_peer_countries {row_peer_country,2};
                   end

                  M2D_curve = RFR_download_BBL_Mid.(strcat(id_issuer, '_RAW_GVT_BBL'));
                   
               end
               
               
                % row_date_calc = find(M2D_curve(:,1) <= date_calc, 1, 'last');
                
                % Find the first non-empty row with market rates available in
                % the government bond array. If the reference date is a
                % business day, date_calc is equal to it. Otherwise, date_calc
                % is the first business day before the reference date.
                % Bloomberg and ECB data are based on business days. Therefore,
                % we start with the date_calc date and go backwards until we
                % find a non-empty row.
                for dt = 1:size(M2D_curve, 1)
                    row_date_calc = find(M2D_curve(:,1) <= (date_calc - dt + 1), 1, 'last');
                    act_date_calc = M2D_curve(row_date_calc, 1);

                     V1R_corps_curve = M2D_curve(row_date_calc,2:end);
                     V1R_corps_terms = 1:length(V1R_corps_curve);

                    nonzeros = (V1R_corps_curve ~= 0); 

                    if any(nonzeros)
                        break
                    end
                end
                
                if ~any(nonzeros)
            
                   info = ['During VA calculation for ', ...
                                  config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}, ...
                                  ' no government curve found for bonds issued by ' , ...
                                  id_issuer];

                   RFR_log_register('06_VA', 'RFR_08E_VA_Corps', 'WARNING', ...
                       info, config);     
                   continue

                end

                if act_date_calc ~= date_calc
                    info = ['Corp VA calculation for ', ...
                                  config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}, ...
                                  ' / Issuer ', id_issuer,...
                                  ': No data available for ', datestr(date_calc, 'dd/mm/yyyy'), ...
                                  '. Using data on ', datestr(act_date_calc, 'dd/mm/yyyy'), ' instead.'];

                   RFR_log_register('06_VA', 'RFR_08E_VA_Corps', 'WARNING', ...
                       info, config);     
                end

               [V1R_corps_curve_with_decimals,~] = ...
                interpolator_curves(V1R_corps_curve, V1R_corps_terms);

                %   Function  'interpolator_curves'  returns the curve with
                %   market rates inter/extrapolated for all maturities 
                %   with 1 decimal position until 60 years(600 values)
                %   'VecRow_govt_curve' is a row vector with 600 columns
                %  (rates for durations 0.1, 0.2, 0.3,... 1, 1.1,...600)
                %   The second output is row vector(1 : 1; 600)

                %   This functions removes terms without market rates
                %   In case of having no market rates or only one
                %   the funtion returns zero vectors
            end


            Str_VA.Corps.M2D_corps_yield_b(run_country, run_issuer) = ...
                  V1R_corps_curve_with_decimals(duration_with_decimal);
              
              
            
            %%  4.3.C. Basic risk-free rates curves for each country
            %   -----------------------------------------------------------            
            
            % Where the run refers to RGLA, the basic RFR may be different
            % from the basic RFR of the country for which a VA is
            % calculated, i.e. the country of the external loop
            
            if run_issuer > 14
                
                V1R_RFR_curncy_yearly = 100 * ER_no_VA.M2D_SW_spot_rates(row_issuer_in_config, 1:60);
        
                [V1R_RFR_curncy_with_decimals,~] = interpolator_curves ...
                               (V1R_RFR_curncy_yearly, 1:60);            
            end
            
            % Otherwise, the run refers to corporate bonds, which are in
            % the same currency as the one of the country for which a VA is
            % being calculated
            
            Str_VA.Corps.M2D_corps_rfr(run_country, run_issuer) = ...
                  V1R_RFR_curncy_with_decimals(duration_with_decimal);
  

              
              
            %%  4.3.D. Fundamental spreads
            %   -----------------------------------------------------------
                              
            %   The first step is the calculation the maximum of 
            %   both components for each integer maturity and then
            %   the interpolation of the maximum values.
            
            %   In this manner when the duration of the representative
            %   portfolio is precisely the year where the FS changes
            %   from being the 0.35% of LTAS to being the PD+CoD,
            %   the FS is consistent with the tables of FS published
            %   in the excel file with PD and CoD

            
            %   35% of long term average spreads    -----------------------
            
            if run_issuer <= 14

                V1R_LTAS_curve = M2D_corps_LTAS_yearly(run_issuer,:);
                
            else % the issuer is a RGLA
                
                % If it is the EUR VA, then what matters is the
                % currency of the issuer
                if strcmp('Currency', type_VA) && run_country == 1 && ...
                    strcmp(config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config, col_ISO4217},...
                                                'EUR')
                      
                    id_issuer = 'EUR';
               
                end
                    
                row_LTAS_govts = strcmp(id_issuer, config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));
                
                V1R_LTAS_curve = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(row_LTAS_govts,:);
            end
            
                        
            %   PD and CoD  -----------------------------------------------
            
            row_PD_CoD = rem(run_issuer-1, 7) + 1;                

            if run_issuer <= 7  % exposure referred to financial sector
                V1R_PD_CoD_year = M2D_PD_CoD_Finan(row_PD_CoD,:);                                 
            end
            
            if run_issuer > 7   &&  run_issuer <= 14    % non-financial                               
                V1R_PD_CoD_year = M2D_PD_CoD_Nonfinan(row_PD_CoD, :);
            end
            
            if run_issuer > 14    % exposure to non-central government bond
                V1R_PD_CoD_year = 0;
            end
            
            
            %   Fundamental spread for integer maturities   ---------------

            V1R_fs_yearly = max(FS_percent_LTAS_Corps * V1R_LTAS_curve, V1R_PD_CoD_year);

            
            
            %   Interpolation of the fundamental spread  ------------------
            
            V1R_fs_terms = 1:length(V1R_LTAS_curve);
            
            [V1R_fs_decimals,~] = ...
                   interpolator_curves(V1R_fs_yearly, V1R_fs_terms);

            %   Function  'interpolator_curves'  returns the curve with
            %   LTAS rates inter/extrapolated for all maturities 
            %   with 1 decimal position until 60 years(600 values)
            %   'VecRow_govt_curve' is a row vector with 600 columns
            %  (rates for durations 0.1, 0.2, 0.3,... 1, 1.1,...600)
            %   The second output is row vector(1 : 1; 600)

            %   This functions removes terms without LTAS
            %   In case of having no LTAS or only one
            %   the funtion returns zero vectors
            

            
            %   Final fundamental spread  ---------------------------------
            
            Str_VA.Corps.M2D_corps_fs(run_country, run_issuer) = ...
                      max(0, V1R_fs_decimals(duration_with_decimal));

            
                  
            %   specific case for the Danish covered bonds 
            %   -----------------------------------------------------------
            if run_issuer == 1  &&  strcmp(id_country, 'DKK')
               Str_VA.Corps.M2D_corps_fs(run_country, run_issuer) = ...
                      max(0,  max(FS_percent_LTAS_Corps * Str_LTAS.Corps.DKK_Nykredit_LTAS_spread,...
                                M2D_PD_CoD_Finan(row_PD_CoD, round(DKK_dur)))); 
            end
            

            
                     
            %%  4.3.E. Yields after risk correction
            %   -----------------------------------------------------------
            
            Str_VA.Corps.M2D_corps_yield_a(run_country, run_issuer) = ...
                  Str_VA.Corps.M2D_corps_yield_b(run_country, run_issuer)  - ...
                  Str_VA.Corps.M2D_corps_fs(run_country, run_issuer);             
              
              
              
        end     % end of the internal loop, running per issuer
        
        
    end     %  end of the external loop, running per currency/market

    
    close(mssge_wait_bar)
    
    
        
%   =======================================================================
%%  5. Calculation of the internal effective rates   
%   =======================================================================


    M2D_matur_dates = [repmat(date_calc, size(Str_VA.Corps.M2D_corps_durations, 1), 1),...
                        date_calc + Str_VA.Corps.M2D_corps_durations * 365 ];
                    

    IRR_guess_rate        = config.RFR_Str_lists.Parameters.IRR_guess_rate;
    IRR_number_iterations = config.RFR_Str_lists.Parameters.IRR_number_iterations;
                    
                           
       %    These parameters are set out in sheet  'Parameters'
       %    of excel file   'RFR_excel_confing.xlsx'
       %    and moved to  'config.RFR_Str_lists.Parameters'  in section 2.6
       %    at the end of fucntion   'RFR_01_basic_setting_config.m'
  
                    
                    
                    
                    
    %   5.1. Internal effective rates for yields before risk correction
    %   ---------------------------------------------------------------
    
        %   The IER will be collected in the first column of the element
        %   'Str_VA.corps.M2D_corps_IER'
        
    M2D_redemption_values =     Str_VA.Corps.M2D_corps_portfolio .* ...
                         (1 + Str_VA.Corps.M2D_corps_yield_b/100).^ ...
                                Str_VA.Corps.M2D_corps_durations;
    
    for run_country = 1:length(Str_VA.C1C_countries)

        if abs(sum(M2D_redemption_values(run_country,:))) < 0.00001
            %   there is no reference portfolio for the currency of the run
            continue
        end
     
        Str_VA.Corps.M2D_corps_IER(run_country,1) = 100 * ...
           xirr([-1, M2D_redemption_values(run_country,:)], ...
                         M2D_matur_dates(run_country,:), ...
                         IRR_guess_rate, IRR_number_iterations); 
    end
    
    
    
    %   5.2. Internal effective rates for risk free rates
    %   -------------------------------------------------
    
        %   The IER will be collected in the second column of the element
        %   'Str_VA.corps.M2D_corps_IER'
            
    M2D_redemption_values =     Str_VA.Corps.M2D_corps_portfolio .* ...
                         (1 + Str_VA.Corps.M2D_corps_rfr/100).^ ...
                                Str_VA.Corps.M2D_corps_durations;
    
    for run_country = 1:length(Str_VA.C1C_countries)
     
        if abs(sum(M2D_redemption_values(run_country,:))) < 0.00001
            %   there is no reference portfolio for the currency of the run
            continue
        end
        
        Str_VA.Corps.M2D_corps_IER(run_country, 2) = 100 * ...
           xirr([-1, M2D_redemption_values(run_country,:)], ...
                         M2D_matur_dates(run_country,:), ...
                         IRR_guess_rate, IRR_number_iterations); 

    end
        
    
    
    %   5.3. Internal effective rates for yields after risk correction
    %   --------------------------------------------------------------
    
        %   The IER will be collected in the third column of the element
        %   'Str_VA.corps.M2D_corps_IER'
            
    M2D_redemption_values =     Str_VA.Corps.M2D_corps_portfolio .* ...
                         (1 + Str_VA.Corps.M2D_corps_yield_a/100).^ ...
                                Str_VA.Corps.M2D_corps_durations;
    
    for run_country = 1:length(Str_VA.C1C_countries)
     
        if abs(sum(M2D_redemption_values(run_country, :))) < 0.00001
            %   there is no reference portfolio for the currency of the run
            continue
        end
        
        Str_VA.Corps.M2D_corps_IER(run_country, 3) = 100 * ...
           xirr([-1, M2D_redemption_values(run_country,:)], ...
                         M2D_matur_dates(run_country,:), ...
                         IRR_guess_rate, IRR_number_iterations);

    end
end