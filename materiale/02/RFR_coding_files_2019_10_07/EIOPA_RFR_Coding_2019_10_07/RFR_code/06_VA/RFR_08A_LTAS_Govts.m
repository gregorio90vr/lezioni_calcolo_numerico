function [Str_LTAS] = RFR_08A_LTAS_Govts ... 
                         (config, date_calc, Str_VA) 
         

%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   This function calculates the long term average spreads 
    %   for government bonds as of the date of calculation of the VA.
    
    %   The calculation is made accordingly to sections 8.E, 9.B.1 and 9.C.
    %   of the Technical Documentation
    
    %   The output is MatLab structure  'Str_LTAS'  element  'Govts'   
    %   which contains four 2-dimensional matrices

    %       M2D_Govts_LTAS_spreads_raw, 
    %           with the pure long term average
    
    %       M2D_Govts_LTAS_counter, 
    %           with the number of dates considered with non zero rates in 
    %           both the government curve and the basic-risk free curve
                   
    %       M2D_Govts_LTAS_first_dates, 
    %           with the first date in MatLab format of each historical
    %           serie(for each currency and each maturity)
                  
    %       M2D_Govts_LTAS_spreads_rec, 
    %           with the average spreads after reconstruction of the
    %           historical series
    %           Only from 1-1-2016 onwards this matrix will be different
    %           from matrix  'M2D_govts_LTAS_spreads_raw'
    
    %   Each matrix has 60 columns with the output for maturities 1 to 60
    %   Rows refer to each country/currency as in the structure
    %      'RFR_Str_lists.C2D_list_curncy'(column 3)

    
    %   IMPORTANT CAUTION   -----------------------------------------------  
    %           This function needs that the dates of the curves 
    %           for the history of basic risk-free curves to be the same
    %           as the dates of the curves for government bond curves
    %   -------------------------------------------------------------------

    
       
%   ============================================================================
%%  1. Loading configuration data and history of government and basic RFR curves   
%   ============================================================================

   
    %   Loading to workspace the configuration
    %   --------------------------------------    

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO3166 and ISO4217
        %   for each of the currencies / countries considered
    
        
        
    %   Loading to workspace the history of government bond curves
    %   ----------------------------------------------------------   
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'RFR_basic_curves'; 
    
        %   Name of the MatLab structure with all historical series
        %   of interest rates, government bonds included 
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));
    
    
    
    %   Loading to workspace the history of basic risk-free curves
    %   ----------------------------------------------------------  
    
    folder_download = config.RFR_Str_config.folders.path_RFR_05_LTAS;    
    file_download = 'Str_History_basic_RFR';   
    
        %   Name of the MatLab structure with the historical
        %   series of basic risk-free interest rates
        % (all extrapolated for each date and currency with S-W method)
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60

	%   This structure is generated with a batch process
	%   with the functions  'VA_History_basic_RFR_.... .m'
        
    load(fullfile(folder_download, file_download));  
    
    
    
    %   Loading to workspace LTAS as of 31-12-2015
    %   ----------------------------------------------------------  
    
    folder_download = config.RFR_Str_config.folders.path_RFR_06_VA;    
    file_download = 'Str_LTAS_YE2015';   
    
        %   Name of MatLab structure with the long term average spreads
        %   as of 31-12-2015.
        %   This information is used in the reconstruction of the LTAS
        %   developed at the end of this function from 1-1-2016 onwards
	    
    load(fullfile(folder_download, file_download));  
    
    

    date_change_method_LTAS = datenum('31/12/2015', 'dd/mm/yyyy');
    
        %   the coding will run differently depending on whether 
        %   the date of calculation is previous or posterior to 31/12/2015

    % Order the LTAS DLT table valid-dates
    dltValidDates = [config.RFR_basic_DLT_LTAS_GVT.validFrom];
    [~,dateOrder] = sort(dltValidDates, 'descend');
    
    
    
%   =======================================================================
%%  2. Preparation of empty variables to receive results   
%   =======================================================================

    Str_LTAS.Govts.M2D_govts_LTAS_spreads_raw = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 60);
    Str_LTAS.Govts.M2D_govts_LTAS_counter     = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 60);
    Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 60);
    Str_LTAS.Govts.M2D_govts_LTAS_first_dates = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 60);

    
    %       M2D_Govts_LTAS_spreads_raw, 
    %           with the pure long term average
    
    %       M2D_Govts_LTAS_counter, 
    %           with the number of dates considered with non zero rates in 
    %           both the government curve and the basic-risk free curve
                  
    %       M2D_Govts_LTAS_first_dates, 
    %           with the first date in MatLab format of each historical
    %           serie(for each currency and each maturity)
                   
    %       M2D_Govts_LTAS_spreads_rec, 
    %           with the average spreads after reconstruction of the
    %           historical series
    %           Only from 1-1-2016 onwards this matrix will be different
    %           from matrix M2D_govts_LTAS_spreads_raw
    
    %   Each matrix has 60 columns with the output for maturities 1 to 60
    %   Rows refer to each country/currency as in the structure
    %       RFR_Str_lists.C2D_list_curncy(column 3)
       
    

%   =======================================================================
%%  3. Main loop for each currency or country 
%     (it finishes at the end of the function)   
%   =======================================================================    

    %        IMPORTANT: 
    %        This loops has as many runs and ORDER as currencies/countries
    %        in  'RFR_Str_lists.C2D_list_curncy'
    %        regardles the VA is calculated for the currency/country

    %        In the item 3. of function 'RFR_08_VA_MA_main_function.m'
    %	     the insurance market data to use in the calculation of the VA
    %        has been ordered in the same manner.
    % 	   (i.e. 'Str_VA.C1C_countries' has the same elements and order
    %        as in  'RFR_Str_lists.C2D_list_curncy')
    %
    %        Otherwise the software may produce wrong outputs
    %        
    %   -------------------------------------------------------------------
    

    %%  3.0. Identification of the rows to use in the calculation
    %        based on the History of basic RFR curves
    %   -------------------------------------------------------------------
    
    if date_calc <= date_change_method_LTAS
        
       rows_to_use  = (Str_History_basic_RFR.EUR_RFR_basic_spot(:,1) <= date_calc);             
            %  'rows_to_use' is a logical vector with 1 for those rows
            %  where the date is <= than the date of calculation
 
    else

       rows_to_use  = (Str_History_basic_RFR.EUR_RFR_basic_spot(:,1) <= date_calc)  &  ...
                    (Str_History_basic_RFR.EUR_RFR_basic_spot(:,1) > date_change_method_LTAS);             
            %  'rows_to_use' is a logical vector with 1 for those rows
            %  where the date is <= than the date of calculation  
    end
    
    
    
    
    for run_country = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1)

 
        %   'RFR_Str_lists.C2D_list_curncy' is a two dimensional cell array
        %   It contains the configuration data
        %   of all possible countries considered in the data base
        % (regardless whether the VA is calculted or not for the country)
        
        id_country = config.RFR_Str_lists.C2D_list_curncy{run_country, col_ISO3166}; 
        origCountry = id_country;
        
            %   ISO3166 of the country
                        
            
            
        %%  3.1. Name matrix with historical serie basic RFR for each run
        %   ---------------------------------------------------------------
        
        if ~strcmp('EUR', config.RFR_Str_lists.C2D_list_curncy{run_country, col_ISO4217})
           name_history_basic_RFR = strcat(id_country, '_RFR_basic_spot');
        else    
           name_history_basic_RFR = 'EUR_RFR_basic_spot';  
                % in case of countries of the Eurozone, 
                % the basic risk-free curve is the Euro curve
        end
        
        
        %%  3.2. Checking whether there is historical series of basic RFR 
        %        for the currency of each run
        %        Historical series are in structure 'Str_History_basic_RFR'
        %   ---------------------------------------------------------------
        
        if ~any(strcmp(name_history_basic_RFR, fieldnames(Str_History_basic_RFR))) 
            
            info = ['During the LTAS calculation, the following database not found: ', name_history_basic_RFR, ...
                           '. No LTAS for this currency'];
                          
            RFR_log_register('06_VA', 'RFR_08B_VA_Govts', 'WARNING',...
                info, config);     

            continue
            %   there is no historical series of basic risk-free rates for the currency of the run
            %   and hence it is not possible to calculate LTAS     
            
        else           
            
            M2D_history_basic_RFR = Str_History_basic_RFR.(name_history_basic_RFR);
                %   from now on the 2-dimensional matrix 
                %   'M2D_history_basic_RFR'  contains the history of the
                %   basic risk-free rates curves for the country of the run
                %   At this stage the first column contains the date of 
                %   each curve in MatLab format, and columns 2 to 61 
                %   the zero coupon rates observed for maturities 1 to 60
                
            VecCol_dates = M2D_history_basic_RFR(rows_to_use,1);
                %   Vector column with the date of each government curve
                %   of the historical serie, in MatLab format,
                %   and only the dates relevant for the calculation
            
            M2D_history_basic_RFR  = M2D_history_basic_RFR(rows_to_use,2:end);    
                %  Before this instruction, first column contained dates, 
                %  that are now in vector column  ' VecCol_dates'
                %  After the instruction this matrix only contains rates  
                %  for maturities 1 to 60 and for dates 
                %  relevant for the calculation, depending
                %  on whether it refers to Y2016 or a previous date
                %(i.e. rows is the logical vector 'rows_to_use' has 0
                %  are not considered)
                
        end   

        
        %%  3.3. Name matrix with historical serie government bonds curves
        %   ---------------------------------------------------------------
        
        %   Technical Documentation. Subsection 8.E Table 9 ---------------
        
        %   In case of a country without government curve,
        %   the government curve of a peer country is assigned
        %   These countries without government curve are in 
        %   the first column of   'Str_VA.Govts.C2D_peer_countries'
        %   while the peer country with government curve is in
        %   the second column of that cell array

       row_peer_country = strcmp(id_country, Str_VA.Govts.C2D_peer_countries(:,1));

       if any(row_peer_country)
          id_country = Str_VA.Govts.C2D_peer_countries{row_peer_country,2};
       end
 
       name_history_govts_curve = strcat(id_country, '_RAW_GVT_BBL');       
        

       
       
       
        %%  3.4. Checking whether there is historical serie of governments 
        %        for the country of the run.
        %        Historical series are in structure  'RFR_download_BBL_Mid'
        %   ---------------------------------------------------------------
  
       if ~any(strcmp(name_history_govts_curve, fieldnames(RFR_download_BBL_Mid)))
           
           info = ['During the LTAS calculation, the following database was not found: ', name_history_govts_curve, ...
                          '. No LTAS for this currency'];
                          
           RFR_log_register('06_VA', 'RFR_08B_VA_Govts', 'WARNING', info, config);                
           
           continue
           %   there is no historical series of government bonds
           %   and hence it is not possible to calculate LTAS
           
       else
           
           M2D_history_govts_curves = RFR_download_BBL_Mid.(name_history_govts_curve);
                %   from now on the 2-dimensional matrix 
                %   'M2D_history_govts_curves' contains the history of the
                %   government bonds for the country of the run
                %   At this stage the first column contains the date of 
                %   each curve in MatLab format, and columns 2 to 61 
                %   the zero coupon rates observed for maturities 1 to 60
           
           % Peer country changes for LATVIA
           if strcmp(origCountry, 'LVL')
                changeDate = datenum(2017,1,31); 
                availableDates = M2D_history_govts_curves(rows_to_use,1);

                esRows = availableDates < changeDate;
                ieRows = ~esRows;
               
                esRates = RFR_download_BBL_Mid.ES_RAW_GVT_BBL(rows_to_use,2:end);
                esRates = esRates(esRows,:);

                ieRates = RFR_download_BBL_Mid.IE_RAW_GVT_BBL(rows_to_use,2:end);
                ieRates = ieRates(ieRows,:);
               
                M2D_history_govts_curves = [esRates;ieRates];
           % Peer country changes for Luxembourg       
           elseif strcmp(origCountry, 'LU')
                changeDate = datenum(2017, 6, 1); 
                availableDates = M2D_history_govts_curves(rows_to_use,1);

                frRows = availableDates < changeDate;
                nlRows = ~frRows;
               
                frRates = RFR_download_BBL_Mid.FR_RAW_GVT_BBL(rows_to_use,2:end);
                frRates = frRates(frRows,:);

                nlRates = RFR_download_BBL_Mid.NL_RAW_GVT_BBL(rows_to_use,2:end);
                nlRates = nlRates(nlRows,:);
               
                M2D_history_govts_curves = [frRates;nlRates];
           else
           
               M2D_history_govts_curves = M2D_history_govts_curves(rows_to_use,2:end);
                    %  Before this instruction, first column contained dates, 
                    %  that are now in vector column  ' VecCol_dates'
                    %  After the instruction this matrix only contains rates  
                    %  for maturities 1 to 60 and for dates previous or equal
                    %  to the date of calculation of the VA
           end
           
            
       end   

       %%   3.5. Calculation of the raw long term average spreads
       %    ---------------------------------------------------------------
      
       M2D_non_zero_data =(M2D_history_govts_curves ~= 0)  .* ...
                         (M2D_history_basic_RFR    ~= 0);

        %   Matrix with same rows as the dates with market data
        %   for the calculation of the long term average spreads,
        %   and same columns(60 for maturities 1 to 60)
        %   Values are 1 only for those dates and maturities where
        %   there are non zero rates for both the basic risk-free curve
        %   and the government bond curve.
        %   Otherwise(one of the rates being null or both of them)
        %   the value is zero.
                      
       M2D_numerator = M2D_history_govts_curves .*  M2D_non_zero_data -...
                       M2D_history_basic_RFR    .*  M2D_non_zero_data;

                   
         %%  3.5b.  Interpolation and maturities longer than the LLP
        %   ---------------------------------------------------------------

        %   Technical Documentation. Subsection 10.B.1   ----------

        %   For some currencies and maturities real LTAS are replaced
        %   with interpolation due to the odd value of the real LTAS

        %   LTAS beyond 10 years receive the same value as LTAS for 10-y
        %   Technical Documentation. Subsection 10.B.1   ----------


        % V1R_LTAS_run   = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(run_country,:);

        lastInterpRow = size(M2D_numerator, 1);
        
        for i=dateOrder
            dltTable = config.RFR_basic_DLT_LTAS_GVT(i).dltTable;
            last_DLT_LTAS_GVT = find(cell2mat(dltTable(run_country,11:20)) == 1, 1, 'last');

            %   10 years is the last maturity considered the calculation
            %   of the long term average spreads of government bonds
            %   Sub-section 10.B.1 of EIOPA Technical Documentation
            % (October, 27th, 2015)

            %   'config.RFR_basic_DLT_LTAS_GVT' is a cell array with as many rows
            %   as currencies / countries.
            %   Ten first columns contain qualitative data of each currency
            % (some of them are empty for the time being)
            %   Columns 11 to 70 contains either '0' or '1' pending on the
            %   historic available of market rates maturities 1-60 years
            %   of government bond rates


            %  rates below the last maturity that should be interpolated  -----

            nonzeros_DLT_LTAS_GVT =(cell2mat(dltTable(run_country, 11:10+last_DLT_LTAS_GVT)) == 1);

           %   Row vector with 1 for those maturities were LTAS is relevant
           %   and zero otherwise
           %   Ten first columns of  'config.RFR_basic_DLT_LTAS_GVT'
           %   contain not relevant information for this purpose
           %   Only columns 11 onwards contain information on DLT
            
            validRows = VecCol_dates >= config.RFR_basic_DLT_LTAS_GVT(i).validFrom;
            
            if any(validRows)
                if lastInterpRow < length(validRows)
                   validRows(lastInterpRow:end) = 0; 
                end

                V1R_LTAS_run = M2D_numerator(validRows,:);
                V1R_LTAS_run = V1R_LTAS_run(:,nonzeros_DLT_LTAS_GVT);

                %  rates for maturities that are usable for LTAS
                Vector_terms = 1:60;
                Vector_terms = Vector_terms(nonzeros_DLT_LTAS_GVT);
                
                
                %   terms of the maturities usable for LTAS
                M2D_LTAS_with_decimals = interp1 ...
                                          (Vector_terms, V1R_LTAS_run', 1:60,...
                                          'linear');
                M2D_LTAS_with_decimals = transpose(M2D_LTAS_with_decimals);      
                
                % Extrapolate any terms below the lowest maturity (if mat >
                % 1) and higher than the highest maturity.
                lowerEnd = (1:60) < Vector_terms(1);
                higherEnd = (1:60) > Vector_terms(end);
                
                if any(lowerEnd)
                    M2D_LTAS_with_decimals(:,lowerEnd) = ...
                        repmat(M2D_LTAS_with_decimals(:,Vector_terms(1)),1,...
                        sum(lowerEnd));
                end
                
                if any(higherEnd)
                    M2D_LTAS_with_decimals(:,higherEnd) = ...
                        repmat(M2D_LTAS_with_decimals(:,Vector_terms(end)),1,...
                        sum(higherEnd));
                end
                
                M2D_numerator(validRows,:) = M2D_LTAS_with_decimals;

                lastInterpRow = find(validRows, 1);
            end
        end
        
        % Reset M2D_non_zero_data to include the interpolated maturities
        M2D_non_zero_data = M2D_numerator ~= 0;
        
        if date_calc > date_change_method_LTAS  %  from 1/1/2016 onwards

            %   Reconstruction of LTAS. Technical Documentation. Subsect 9.B.1 

               V1R_new_spreads = sum(M2D_numerator, 1);

                %   vector row with 60 columns containing the sum of spreads 
                %   for maturities 1 to 60 years only for those dates
                %   from 1-1-2016 onwards            

                V1R_num_new_dates_with_data = sum(M2D_non_zero_data, 1);

                %   vector row with 60 columns containing the number of 
                %   new dates with spreads for each maturity            

                %   Str_LTAS_YE2015.Govts.M2D_govts_LTAS_spreads_YE2015
                %   is a 2-dimensional matrix with 60 columns containing
                %   in each row the LTAS as of 31-12-2015 for each country

               Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(run_country, :) =  ...
                  (Str_LTAS_YE2015.Govts.M2D_govts_LTAS_spreads_YE2015(run_country, :) .*(7800 - V1R_num_new_dates_with_data) + ...
                      V1R_new_spreads) / 7800;

               Str_LTAS.Govts.M2D_govts_LTAS_counter(run_country, :) = ...
                                              sum(M2D_non_zero_data, 1);
 
        else
            
            %   Before 01-01-2016, no reconstruction of LTAS


            Str_LTAS.Govts.M2D_govts_LTAS_spreads_raw(run_country, :) =...
                sum(M2D_numerator, 1) ./  sum(M2D_non_zero_data, 1);

            Str_LTAS.Govts.M2D_govts_LTAS_counter(run_country, :) = ...
                                              sum(M2D_non_zero_data, 1);

                                                 
           % Special case for GBP due to the consideration of data 
           % before 1/1/1999  ------------------------------------  
           
            if strcmp('GBP', id_country)
                
                Ratio = ones(1,60);
                Ratio(1)  = 1.03;
                Ratio(2)  = 0.95;
                Ratio(3)  = 0.94;
                Ratio(4)  = 0.94;
                Ratio(5)  = 0.95;
                Ratio(6)  = 1.03;
                Ratio(7)  = 0.99;
                Ratio(8)  = 1.04;
                Ratio(9)  = 1.05;
                Ratio(10) = 1.05;

                Str_LTAS.Govts.M2D_govts_LTAS_spreads_raw(run_country, :) =...
                     Str_LTAS.Govts.M2D_govts_LTAS_spreads_raw(run_country, :) .* Ratio;
            end

                   
            Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(run_country,:) = ...
                Str_LTAS.Govts.M2D_govts_LTAS_spreads_raw(run_country, :);
                   

        end   %  of the if date_calc > date_change_method_LTAS  

        % Set the LTAS of all maturities > 10Y to the 10Y LTAS
        % Cf. paragraph 255 of the TD
        Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(run_country,11:end) = ...
            repmat(Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(run_country,10),...
                1,50);
            
    %%  3.6.Internal loop for each maturity within each currency or country 
    %   -------------------------------------------------------------------

        %   This second loop, internal to the first one, for each maturity
        %   performs the calculation of the first date considered in
        %   the calculation of the LTAS for each maturity
        %   ---------------------------------------------------------------
        
       for run_mat = 1:60
                  
           row_first_nonzero  = find(M2D_non_zero_data(:,run_mat) > 0, 1, 'first');
            
           if ~isempty(row_first_nonzero)             
               date_first_non_zero = VecCol_dates(row_first_nonzero,1);
               Str_LTAS.Govts.M2D_govts_LTAS_first_dates(run_country,run_mat) = date_first_non_zero;            
           end
         
       end     %   end of the for  regarding maturities
 
    end     %   end of the for  regarding countries/currencies


    
            
%   =======================================================================                  
%%  4. Updating the structure with the information referred to 31/12/2015
%   Section 10.C.4 of EIOPA Technical Documentation October 27, 2015   
%   =======================================================================

    if date_calc  <=  date_change_method_LTAS

       Str_LTAS_YE2015.Govts.M2D_govts_LTAS_spreads_YE2015 = ...
                        Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec;
 
       save(fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                    'Str_LTAS_YE2015'), 'Str_LTAS_YE2015');
                    
    end
