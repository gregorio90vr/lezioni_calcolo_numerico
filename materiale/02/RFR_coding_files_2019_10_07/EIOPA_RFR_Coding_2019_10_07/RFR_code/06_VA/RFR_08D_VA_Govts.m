function Str_VA = RFR_08D_VA_Govts(config, date_calc,...
                             ER_no_VA, Str_VA, type_VA, Str_LTAS) 
         
   
%   =======================================================================
%%  Explanation of this function 
%   =======================================================================

    %   This funtion calculates the three internal effective rates
    %   referred to the portfolio of government bonds
    %   necessary to calculate the VA
    
    %   -------------------------------------------------------------------
    
    %   INPUTS
    
    %   For risk-free rates: Structure  'ER_no_VA', 
    %                        element    'M2D_SW_spot_rates'
    %                       (function  'RFR_06A_extrapol_main_loop.m')
    
        %   'ER_no_VA.M2D_SW_spot_rates' is a 2-dimensional matrix 
        %   with the basic risk-free curves as of date calculation
        %   for all currencies(rows) and for maturities 1 to 150
        %  (150 columns)The output is a MatLab structure Str_VA with the same name

    %   For LTAS:   Structure 'Str_LTAS'
    %               element   'Govts.M2D_govts_LTAS_spreads_rec'
    %              (function 'RFR_08A_LTAS_Govts'
    
    %   For insurance market data: Structure 'Str_VA'
    %   IMPORTANT:  This structure is also the output of this function
    %               The output retains the information input
    %               adding the calculations as desribed below
    
    %   -------------------------------------------------------------------
    
    %   OUTPUT
    
    %   Structure 'Str_VA'. It contains all the insurance market data used
    %                       in the calculations + FIVE new elements
    %                       calculated in this funtion
    
    %   Str_VA.Govts.M2D_govts_yield_b 
    %       2-dimensional matrix with countries in rows and
    %       as many columns as governments issuers, which are defined
    %       by the second dimension of ' Str_VA.Govts.M2D_govts_portfolio'
    %       This element contains the market yield as of date calculation
    %       for the exposure of each country(row) to each issuer(column)
    %       The market yield is NOT risk-corrected
    
    %   Str_VA.Govts.M2D_govts_fs
    %       2-dimensional matriz with the same design as the previous one
    %       This element contains the fundamental spread date calculation
    %       for the exposure of each country(row) to each issuer(column)

    %   Str_VA.Govts.M2D_govts_yield_a
    %       2-dimensional matriz with the same design as the previous one
    %       This element contains the market yield as of date calculation
    %       for the exposure of each country(row) to each issuer(column)
    %       AFTER risk-correction
    
    %   Str_VA.Govts.M2D_govts_rfr
    %       2-dimensional matriz with the same design as the previous one
    %       This element contains the risk-free rate as of date calculation
    %       for the exposure of each country(row) to each issuer(column)
    
    %   Str_VA.Govts.M2D_govts_IER 
    %       2-dimensional matrix with countries in rows and 3 columns
    %       It contains the internal effective rate of the central
    %       government bond portfolio,
    %           First column .- Based on market yield NOT corrected
    %           Second column.- Based on risk-free rates
    %           Third column .- Based on market yeld AFTER risk correction
    
%   =======================================================================    
    
    
  
       
%   =======================================================================
%%  1. Loading configuration, insurance market data and government curves  
%   =======================================================================

    
    %   Loading to workspace the configuration data
    %   -------------------------------------------    
    
    col_ISO3166   = config.RFR_Str_lists.Str_numcol_curncy.ISO3166  ;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_EEA = config.RFR_Str_lists.Str_numcol_curncy.EEA;

        %   number of the column in cell array
        %   config.RFR_Str_lists.C2D_list_curncy containing ISO3166 and 
        %   whether it is Member State of the UE(Y) or not(N)
        %   for each of the currencies / countries considered
            
    
    %   Loading to workspace government curves
    %   --------------------------------------
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'RFR_basic_curves';           
        %   Name of the MatLab numeric 2-D matrix with the historical
        %   serie of interest rates for the currency of each run

    load(fullfile(folder_download, file_download), 'RFR_download_BBL_Mid');

    
    
   %   Loading to workspace legal-technical pre-defined parameters
   %   -----------------------------------------------------------
    
    FS_percent_LTAS_Govts_EEA     = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_EEA;
    FS_percent_LTAS_Govts_non_EEA = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_non_EEA;
            
       %    These parameters are set out in sheet  'Parameters'
       %    of excel file   'RFR_excel_confing.xlsx'
       %    and moved to  'config.RFR_Str_lists.Parameters'  in section 2.6
       %    at the end of fucntion   'RFR_01_basic_setting_config.m'
        
        
        
%   =======================================================================
%%  2. Creation of matrices and vector to recieve the outputs  
%   =======================================================================

    %   Creation of the matrices and vectors of outputs for 
    %   the government bond portfolio
    
    Str_VA.Govts.M2D_govts_yield_b = ...
        zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1) , ...
                 size(Str_VA.Govts.M2D_govts_portfolio , 2) );
    Str_VA.Govts.M2D_govts_fs      = Str_VA.Govts.M2D_govts_yield_b;
    Str_VA.Govts.M2D_govts_yield_a = Str_VA.Govts.M2D_govts_yield_b;    
    Str_VA.Govts.M2D_govts_rfr     = Str_VA.Govts.M2D_govts_yield_b;
    
    Str_VA.Govts.M2D_govts_IER = zeros(length(Str_VA.C1C_countries), 3);
    

    
%   =======================================================================
%%  3. Calculation of the output for each country/currency   
%   =======================================================================
    
    %%   3. Main loop for each currency or country
    %        IMPORTANT: 
    %        This loops has a many runs and ORDER as currencies/countries
    %        in  'config.RFR_Str_lists.C2D_list_curncy'
    %        regardles the VA is calculated for the currency/country

    %        In the item 3. of function 'RFR_08_VA_MA_main_function.m'
    %	     the insurance market data to use in the calculation of the VA
    %        has been ordered in the same manner.
    % 	    (i.e. 'Str_VA.C1C_countries' has the same elements and order
    %        as in  'config.RFR_Str_lists.C2D_list_curncy'
    %
    %        Otherwise the function may produce wrong outputs
    %        
    %   -------------------------------------------------------------------    

    for run_country = 1:size(config.RFR_Str_lists.C2D_list_curncy , 1)

        %   'run_country' identifies the row in MatLab structure
        %   'Str_VA.Govts' which corresponds with the country/currency
        %   in the run_country
        
          
        %%  3.A. Second loop, internal to the first one, for each issuer
        %   ---------------------------------------------------------------
        
        for run_issuer = 1:length(Str_VA.Govts.C1R_govts_issuers)
                       
            
            %%  3.A.1. Preliminary steps in the inside loop
            %   -----------------------------------------------------------

            %   if there is no exposure in the country of 'run_country'
            %   to the government bonds of  'run_issuer'  
            %   the run skips to the following issuer.
            %   The composition of the government bond portfolio is
            %   in the element  'Str_VA.Govts.M2D_govts_portfolio'
            %   where issuers are in columns and insurance markets in rows            
            
            if Str_VA.Govts.M2D_govts_portfolio(run_country , run_issuer) == 0
               
                continue
            end

            
            id_issuer = Str_VA.Govts.C1R_govts_issuers{run_issuer}; 
                %   'Str_VA.Govts.C1R_govts_issuer'  is a cell array row
                %   with ISO3166 for the governments issuing bonds          
            
            %   In case of a country without government curve,
            %   the government curve of a peer country is assigned
            %   These countries without government curve are in 
            %   the first column of   'Str_VA.Govts.C2D_peer_countries'
            %   while the peer country with government curve is in
            %   the second column

            row_peer_country = strcmp(id_issuer , Str_VA.Govts.C2D_peer_countries(:,1));

            if sum(row_peer_country) > 0
                id_issuer = Str_VA.Govts.C2D_peer_countries {row_peer_country,2};
            end                
                
            % run_issuer goes through the list of issuers stored in Str_VA.Govts.C1R_govts_issuers
            % which is different from the list of countries/currencies in 
            % config.RFR_Str_lists.C2D_list_curncy
            % The following variable map those 2 lists for the issuer
             
            row_issuer_in_config = strcmp(config.RFR_Str_lists.C2D_list_curncy(: , col_ISO3166) , ...
                                    id_issuer) == 1;                                         
            
            % if Currency EUR VA and the issuer has the EUR as a 
            % currency, then the id_issuer is the EUR and the
            % ECB curve should be taken for the yields and 
            % risk correction
            if strcmp('Currency', type_VA) && run_country == 1 && ...
               strcmp(config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config, col_ISO4217}, 'EUR')
                      
               id_issuer = 'EUR';
               
            end
        
            
            %   Identifying the duration of the exposure of the country
            %   considered in the run 'run_country'(main loop)
            %   to the issuer considered in the run 'run_issuer'

            %   The durations of the government bond portfolio is
            %   in the element  'Str_VA.Govts.M2D_govts_durations'
            %   where issuers are in columns and insurance markets rows

            duration = Str_VA.Govts.M2D_govts_durations(run_country , run_issuer);

            %   Applying the ECB curve all government bonds for the 
            %   Euro currency VA
            
            if strcmp('Currency', type_VA) && run_country == 1 && ...
               strcmp(config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config, col_ISO4217}, 'EUR')
               
               duration = Str_VA.ECB;
            end

            if duration < 1
                duration = 1;  % in order to avoid failures below
            end
        
            
           
            %%  3.A.2. Yields from government bonds curves
            %   -----------------------------------------------------------
            
            %   Selecting the government curve of the issuer
            %   From now on, the complete curve for all dates will be in
            %   M2D_curve, whose first column are dates
            %   being columns 2 to 61 the rates for maturities 1 to 60

            if ~strcmp(id_issuer, 'ISK')   
                M2D_curve = RFR_download_BBL_Mid.(strcat(id_issuer, '_RAW_GVT_BBL'));   
            else
                %   special case of Iceland without historical serie 
                %   of government bond rates but with the current
                %   inserted manually inserted in function
                %   RFR_04_basic_manual_amendments.m
                
                CRA_current = ER_no_VA.VecRow_CRA(1) / 100;
                M2D_curve   = [date_calc,ER_no_VA.M2D_SW_spot_rates(run_country, 1:60) + CRA_current];
                
            end
                  
                
                
            % Find the first non-empty row with market rates available in
            % the government bond array. If the reference date is a
            % business day, date_calc is equal to it. Otherwise, date_calc
            % is the first business day before the reference date.
            % Bloomberg and ECB data are based on business days. Therefore,
            % we start with the date_calc date and go backwards until we
            % find a non-empty row.
            for dt = 1:size(M2D_curve, 1)
                row_date_calc = find(M2D_curve(:,1) <= (date_calc - dt + 1), 1, 'last');
                act_date_calc = M2D_curve(row_date_calc,1);
                
                V1R_govt_curve = M2D_curve(row_date_calc,2:end);

                V1R_govt_terms = (1:length(V1R_govt_curve));

                nonzeros = (V1R_govt_curve ~= 0); 
                
                if any(nonzeros)
                    break
                end
            end
            
            
            if ~any(nonzeros)
            
               info = ['During VA calculation for ', ...
                              config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}, ...
                              ' no government curve found for bonds issued by ' , ...
                              config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config,col_ISO3166}];
                          
               RFR_log_register('06_VA', 'RFR_08D_VA_Govts', 'WARNING', ...
                   info, config);     
               continue
               
            end
            
            if act_date_calc ~= date_calc
                info = ['Govt VA calculation for ', ...
                              config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}, ...
                              ' / Issuer ' config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config,col_ISO3166},...
                              ': No data available for ', datestr(date_calc, 'dd/mm/yyyy'), ...
                              '. Using data on ', datestr(act_date_calc, 'dd/mm/yyyy'), ' instead.'];
                          
               RFR_log_register('06_VA', 'RFR_08D_VA_Govts', 'WARNING', ...
                   info, config);     
            end

            
            V1R_govt_curve = V1R_govt_curve(nonzeros);
            V1R_govt_terms = V1R_govt_terms(nonzeros);

           
            
            if duration < min(V1R_govt_terms)
              info = ['During VA calculation for ', ...
                              config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}, ...
                              ' the process found a duration lower than the',...
                              ' available maturities for government bonds issued by ', ...
                              config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config,col_ISO3166},...
                              '. Using ',num2str(min(V1R_govt_terms)),'Y as a proxy.'];
                          
               RFR_log_register('06_VA', 'RFR_08D_VA_Govts', 'Warning', ...
                   info, config);     
               
               duration = min(V1R_govt_terms);
            elseif duration > max(V1R_govt_terms)
                    info = ['During VA calculation for ', ...
                              config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}, ...
                              ' the process found a duration higher than the',...
                              ' available maturities for government bonds issued by ', ...
                              config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config,col_ISO3166},...
                              '. Using ',num2str(max(V1R_govt_terms)),'Y as a proxy.'];
                          
               RFR_log_register('06_VA', 'RFR_08D_VA_Govts', 'Warning', ...
                   info, config);     
               
               duration = max(V1R_govt_terms);
            end

            [VecRow_govt_curve_with_decimals,~] = ...
                            interpolator_curves ...
                               (V1R_govt_curve, V1R_govt_terms);

            %   Function  'interpolator_curves'  returns the curve with
            %   interest rates inter/extrapolated for all maturities 
            %   with 1 decimal position until 60 years(600 values)
            %   'VecRow_govt_curve' is a row vector with 600 columns
            %  (rates for durations 0.1, 0.2, 0.3,... 1, 1.1,...600)
            %   The second output is row vector(1 : 1; 600)

            %   This functions removes in the inputs the terms without 
            %   interest rates equal to zero.
            %   In case of having one or none non-zero interest rates
            %   the funtion returns zero vectors
                
            duration_with_decimal = round(10 * duration);
            
            Str_VA.Govts.M2D_govts_yield_b(run_country , run_issuer) =...
                VecRow_govt_curve_with_decimals(duration_with_decimal);

            
              
            %%   3.A.3. Yields from basic risk-free rates curves
            %   -----------------------------------------------------------
             
            %   Selecting the risk free rates curve of the issuer
            %   From now on the complete curve for all dates will be in
            %   M2D_govt_curve, whose first column are dates
            %   being columns 2 to 61 the rates for maturities 1 to 60
            
            row_rfr = strcmp(id_issuer, config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));
                
            VecRow_rfr_curve = 100 * ER_no_VA.M2D_SW_spot_rates(row_rfr,:);

                %   'ER_no_VA.M2D_SW_spot_rates' is a 2-dimensional matrix 
                %   with the basic risk-free curves as of date calculation
                %   for all currencies(rows) and for maturities 1 to 150
                %  (150 columns)
            
            %   The relevant duration to consider has already been
            %   assigned to the variable 'duration' above(3.A.1)
            
            lower_rate = VecRow_rfr_curve(fix(duration));
            upper_rate = VecRow_rfr_curve(fix(duration) + 1);
            
            Str_VA.Govts.M2D_govts_rfr(run_country, run_issuer) = ...
                  lower_rate +(upper_rate - lower_rate) * rem(duration,1);
                % this instruction requires 'VecRow_govts_curve' to have
                % non-zero rates for all maturities from 1 to 60

            
              
            %%   3.A.4. Fundamental spreads
            %   -----------------------------------------------------------
            
            if strcmp('Currency', type_VA) && run_country == 1 && ...
               strcmp(config.RFR_Str_lists.C2D_list_curncy{row_issuer_in_config, col_ISO4217}, 'EUR')      
               
                row_LTAS_govts = 1;
            else      
                
                row_LTAS_govts = find(strcmp(id_issuer, Str_VA.C1C_countries));
                
            end


            VecRow_fs_curve = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(row_LTAS_govts,:);
            
                %   'Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec' 
                %   is a 2-dimensional matrix with the LTAS 
                %   for all governments(rows) and maturities 1 to 60
                %  (60 columns)
                %   This matrix is calculated by function
                %   'RFR_08A_LTAS_Govts.m'
                
            lower_rate = VecRow_fs_curve(fix(duration));
            upper_rate = VecRow_fs_curve(fix(duration) + 1);
            
            LTAS_interpolated = lower_rate +(upper_rate - lower_rate) * rem(duration,1);
                % this instruction requires 'VecRow_fs_curve' to have
                % non-zero LTAS for all maturities from 1 to 60

                
           
           % Section 10.B of technical documentation: 
           % EEA countries have a RC of 30% - for the rest, RC of 35%
           
           row_Country = strcmp(id_issuer, config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));
           
           if strcmp(config.RFR_Str_lists.C2D_list_curncy(row_Country,col_EEA), 'EEA')
               factor_fs = FS_percent_LTAS_Govts_EEA;
           else
               factor_fs = FS_percent_LTAS_Govts_non_EEA;
           end
           
           Str_VA.Govts.M2D_govts_fs(run_country, run_issuer) =...
                                factor_fs * max(0, LTAS_interpolated);


                            
              
            %%   3.1.A.4. Yields after risk correction
            %   -----------------------------------------------------------
            
            Str_VA.Govts.M2D_govts_yield_a(run_country,run_issuer) = ...
                  Str_VA.Govts.M2D_govts_yield_b(run_country,run_issuer) - ...
                  Str_VA.Govts.M2D_govts_fs(run_country,run_issuer);             
               
              
        end     % end of the internal loop, running per issuer
        
        
    end     %  end of the external loop, running per currency/market

    
    
        
%   =======================================================================
%%  4. Calculation of the internal effective rates   
%   =======================================================================


    M2D_matur_dates = [repmat(date_calc, size(Str_VA.Govts.M2D_govts_durations, 1), 1),...
                        date_calc + Str_VA.Govts.M2D_govts_durations * 365];


    IRR_guess_rate = config.RFR_Str_lists.Parameters.IRR_guess_rate;
    IRR_number_iterations = config.RFR_Str_lists.Parameters.IRR_number_iterations;
                    
                           
       %    These parameters are set out in sheet  'Parameters'
       %    of excel file   'RFR_excel_confing.xlsx'
       %    and moved to  'config.RFR_Str_lists.Parameters'  in section 2.6
       %    at the end of fucntion   'RFR_01_basic_setting_config.m'
  
    
       
    %   4.1. Internal effective rates for yields before risk correction
    %   ---------------------------------------------------------------
    
        %   The IER will be collected in the first column of the element
        %   'Str_VA.Govts.M2D_govts_IER'
        
    M2D_redemption_values = Str_VA.Govts.M2D_govts_portfolio .* ...
                         (1 + Str_VA.Govts.M2D_govts_yield_b/100) .^ ...
                                Str_VA.Govts.M2D_govts_durations;
                                                
    % If we calculate the currency VA, then for the EUR, the duration with
    % which the projection is done should be the weighted average. We
    % replace the duration of issuers with EUR as a currency in the row   
    % of the EUR in the redemption value matrix with the weighted average.
    
    
    [~,idEurCountries] = ismember(Str_VA.Govts.C1R_govts_issuers, ...
        config.RFR_Str_lists.C2D_list_curncy(:, col_ISO3166));
    
    eurCountries = strcmp(config.RFR_Str_lists.C2D_list_curncy(idEurCountries, ...
        col_ISO4217), 'EUR')';

    
    if strcmp('Currency' , type_VA)
        duration = Str_VA.ECB; 
       
        M2D_redemption_values(1,eurCountries) =  ...
            Str_VA.Govts.M2D_govts_portfolio(1,eurCountries) .* ...
           (1 + Str_VA.Govts.M2D_govts_yield_b(1,eurCountries)/100).^ ...
            duration;
        
        % The maturity dates to be changed start after the first column.
        M2D_matur_dates(1,[false,eurCountries]) = date_calc + 365*duration; 

    end
                            
    for run_country = 1:length(Str_VA.C1C_countries)
        
        if abs(sum(M2D_redemption_values(run_country,:))) < 0.00001
            %   there is no reference portfolio for the currency of the run
            continue
        end
     
        Str_VA.Govts.M2D_govts_IER(run_country, 1) = 100 * ...
           xirr([-1, M2D_redemption_values(run_country,:)], ...
                         M2D_matur_dates(run_country,:), ...
                         IRR_guess_rate, IRR_number_iterations); 
    end
    
    
    %   4.2. Internal effective rates for risk free rates
    %   -------------------------------------------------
    
        %   The IER will be collected in the second column of the element
        %   'Str_VA.Govts.M2D_govts_IER'
            
    M2D_redemption_values =     Str_VA.Govts.M2D_govts_portfolio .* ...
                         (1 + Str_VA.Govts.M2D_govts_rfr/100) .^ ...
                                Str_VA.Govts.M2D_govts_durations;
    
    % If we calculate the currency VA, then for the EUR, the duration with
    % which the projection is done should be the weighted average. We
    % replace the duration of issuers with EUR as a currency in the row   
    % of the EUR in the redemption value matrix with the weighted average.
    if strcmp('Currency', type_VA)
        duration = Str_VA.ECB;
        M2D_redemption_values(1, eurCountries) =  ...
            Str_VA.Govts.M2D_govts_portfolio(1, eurCountries) .* ...
           (1 + Str_VA.Govts.M2D_govts_rfr(1, eurCountries)/100).^ ...
            duration;
    end
                            
    for run_country = 1:length(Str_VA.C1C_countries)
        
        if abs(sum(M2D_redemption_values(run_country,:))) < 0.00001
            %   there is no reference portfolio for the currency of the run
            continue
        end
     
        Str_VA.Govts.M2D_govts_IER(run_country, 2) = 100 * ...
           xirr([-1, M2D_redemption_values(run_country,:)], ...
                         M2D_matur_dates(run_country,:), ...
                         IRR_guess_rate, IRR_number_iterations); 

    end
        
    
    %   4.3. Internal effective rates for yields after risk correction
    %   --------------------------------------------------------------
    
        %   The IER will be collected in the third column of the element
        %   'Str_VA.Govts.M2D_govts_IER'
            
    M2D_redemption_values =     Str_VA.Govts.M2D_govts_portfolio .* ...
                         (1 + Str_VA.Govts.M2D_govts_yield_a/100) .^ ...
                                Str_VA.Govts.M2D_govts_durations;
    
    % If we calculate the currency VA, then for the EUR, the duration with
    % which the projection is done should be the weighted average. We
    % replace the duration of issuers with EUR as a currency in the row   
    % of the EUR in the redemption value matrix with the weighted average.
    if strcmp('Currency', type_VA)
        duration = Str_VA.ECB;
        M2D_redemption_values(1,eurCountries) =  ...
            Str_VA.Govts.M2D_govts_portfolio(1,eurCountries) .* ...
           (1 + Str_VA.Govts.M2D_govts_yield_a(1,eurCountries)/100).^ ...
            duration;
    end
    
    for run_country = 1:length(Str_VA.C1C_countries)
     
        if abs(sum(M2D_redemption_values(run_country,:))) < 0.00001
            %   there is no reference portfolio for the currency of the run
            continue
        end
        
        Str_VA.Govts.M2D_govts_IER(run_country, 3) = 100 * ...
           xirr([-1, M2D_redemption_values(run_country,:)] , ...
                         M2D_matur_dates(run_country,:), ...
                         IRR_guess_rate, IRR_number_iterations);

    end
end