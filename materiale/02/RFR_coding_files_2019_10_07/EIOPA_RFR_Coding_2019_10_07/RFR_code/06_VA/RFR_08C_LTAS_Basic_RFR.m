function Str_LTAS = RFR_08C_LTAS_Basic_RFR ... 
                           (config, date_calc, Str_LTAS) 
         
  
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   This function calculates the long term average spread 
    %   for government bonds as for the date of calculation of the VA
    
    %   The output is MatLab structure  'Str_LTAS' element  'Basic'   
    %   which contains four 2-dimensional matrices

    %       Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread 
    %           with the pure long term average
    
    %       Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter 
    %           with the number of dates considered with non zero rates in 
    %           both the calculation of the average spread
                       
    %   Each matrix has 60 columns with the output for maturities 1 to 60
    %   Rows refer to each country/currency as in the structure
    %      'config.RFR_Str_lists.C2D_list_curncy'  (column 3)

    
    %   IMPORTANT CAUTION  ------------------------------------------------
    %             This function needs that the dates of the curves 
    %             for the history of basic risk-free curves to be the same
    %             for all currencies

       
%   ============================================================================
%%  1. Loading configuration data and history of government and basic RFR curves   
%   ============================================================================
    
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166 ;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217 ;
    
        %   number of the column in cell array
        %   'config.RFR_Str_lists.C2D_list_curncy'  containing ISO3166 and ISO4217
        %   for each of the currencies / countries considered
        
        
    
    %   Loading to workspace the history of basic risk-free curves
    %   ----------------------------------------------------------  
    
    folder_download = config.RFR_Str_config.folders.path_RFR_05_LTAS ;    
    file_download = 'Str_History_basic_RFR' ;   
    
        %   Name of the MatLab structure with the historical
        %   series of basic risk-free interest rates
        %   (all extrapolated for each date and currency with S-W method)
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60

	%   This structure is generated with a batch process
	%   with the function  'VA_History_basic_RFR_batch.m'
        
    load(fullfile(folder_download, file_download))  
    
    
    
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
 
        

%   =======================================================================
%%  2. Preparation of empty variables to receive results   
%   =======================================================================

    %   Creation of the matrices for storing the results
        
    Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread  = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 60);
    Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 60);
     
    %       Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread 
    %           with the pure long term average spreads 
    %           of the basic RFR curve of each currency
    %           using as benchmark the basic RFR for the Euro
    
    %       Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter, 
    %           with the number of dates considered with non zero rates in 
    %           both the government curve and the basic-risk free curve
                      
    %   Each matrix has 60 columns with the output for maturities 1 to 60
    %   Rows refer to each country/currency as in the structure
    %       config.RFR_Str_lists.C2D_list_curncy  (column 3)
       
    

%   =======================================================================
%%  3. Matrix with the benchmark basic RFR (Euro)
%   =======================================================================    
    
    M2D_history_basic_RFR_EURO = Str_History_basic_RFR.EUR_RFR_basic_spot;
    
            %   from now on the 2-dimensional matrix 
            %   'M2D_history_basic_RFR' contains the history of the
            %   basic risk-free rates curves for the country of the run
            %   At this stage the first column contains the date of 
            %   each curve in MatLab format, and columns 2 to 61 
            %   the zero coupon rates observed for maturities 1 to 60
                

    %%  3.0. Identification of the rows to use in the calculation
    %        based on the History of basic RFR curves
    %   -------------------------------------------------------------------
    
    if date_calc <= date_change_method_LTAS
        
       rows_to_use  = (Str_History_basic_RFR.EUR_RFR_basic_spot ( : , 1 ) <= date_calc ) ;             
            %  'rows_to_use' is a logical vector with 1 for those rows
            %  where the date is <= than the date of calculation
 
    else

       rows_to_use  = ( Str_History_basic_RFR.EUR_RFR_basic_spot ( : , 1 ) <= date_calc )  &  ...
                      ( Str_History_basic_RFR.EUR_RFR_basic_spot ( : , 1 ) > date_change_method_LTAS ) ;             
            %  'rows_to_use' is a logical vector with 1 for those rows
            %  where: date_change_method_LTAS < selected row dates <= date of calculation
    end
    
     
            
    M2D_history_basic_RFR_EURO  = M2D_history_basic_RFR_EURO(rows_to_use,2:end);  
    
            %  Before this instruction, first column contained dates, 
            %  that are now in vector column  ' VecCol_dates'
            %  After the instruction this matrix only contains rates  
            %  for maturities 1 to 60 and for dates previous or equal
            %  to the date of calculation of the VA
            %  ( i.e. rows where the logical vector´'rows_to_use' are 0
            %  are not considered )
                

            

%   =======================================================================
%%  4. Main loop for each currency or country 
%   =======================================================================        

    %        IMPORTANT CAUTION  -------------------------------------------
    %        This loops has as many runs and ORDER as currencies/countries
    %        in  'config.RFR_Str_lists.C2D_list_curncy'
    %        regardles the VA is calculated for the currency/country

    %        In the item 3. of function 'RFR_08_VA_MA_main_function.m'
    %	     the insurance market data to use in the calculation of the VA
    %        has been ordered in the same manner.
    % 	     (i.e. 'Str_VA.C1C_countries' has the same elements and order
    %        as in  'config.RFR_Str_lists.C2D_list_curncy'
    %
    %        Otherwise the function may produce wrong outputs
    %        
    %   -------------------------------------------------------------------
    
    for run_country = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1);

 
        %   'config.RFR_Str_lists.C2D_list_curncy' is a two dimensional cell array
        %   It contains the configuration data
        %   of all possible countries considered in the data base
        %   (regardless whether the VA is calculted or not for the country)
        
        id_country = config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO3166}; 
    
            %   ISO3166 of the country
                
        
            
        %%  4.1. Name curve with historical serie of basic risk-free rates
        %   ---------------------------------------------------------------
        
        if ~strcmp('EUR', config.RFR_Str_lists.C2D_list_curncy{run_country,col_ISO4217})
           name_history_basic_RFR = strcat(id_country, '_RFR_basic_spot');
        else    
           continue  
                % in case of countries of the Eurozone, 
                % it is not necessary to calculate the LTAS
        end
        
        
        
        %%  4.2. Checking whether there is historical serie of basic RFR 
        %        for the currency of each run
        %        Historical series are in structure 'Str_History_basic_RFR'
        %   ---------------------------------------------------------------
        
        if ~any(strcmp(name_history_basic_RFR, fieldnames(Str_History_basic_RFR))) 
            
            %   there is no historical series of basic risk-free rates for the currency of the run
            %   and hence it is not possible to calculate LTAS     
            
            %   The only case for the time being is Iceland.
            %   In section 4 of the coding bvelow it receives IE LTAS
            %   but only as notional shortcut to avoid failure in the
            %   coding (there is no VA for Iceland)
            
             info = ['Database not found in the history of basic RFR curves ' , ...
                              name_history_basic_RFR , ...
                              '. No LTAS calculated for this currency.'];
                          
            RFR_log_register('06_VA', 'RFR_08C_VA_LTAS_Basic_RFR', 'WARNING', info, config);     
                         
            continue
           
        else           
            
            M2D_history_basic_RFR = Str_History_basic_RFR.(name_history_basic_RFR);
                %   from now on the 2-dimensional matrix 
                %   'M2D_history_basic_RFR' contains the history of the
                %   basic risk-free rates curves for the country of the run
                %   At this stage the first column contains the date of 
                %   each curve in MatLab format, and columns 2 to 61 
                %   the zero coupon rates observed for maturities 1 to 60
                
            M2D_history_basic_RFR = M2D_history_basic_RFR(rows_to_use,2:end);    
                %  Before this instruction, first column contained dates, 
                %  that are now in vector column  ' VecCol_dates'
                %  After the instruction this matrix only contains rates  
                %  for maturities 1 to 60 and for dates previous or equal
                %  to the date of calculation of the VA
        end   

        
       %%   4.3. Calculation of the raw long term average spreads
       %    ---------------------------------------------------------------
      
       M2D_non_zero_data = (M2D_history_basic_RFR      ~= 0)  .* ...
                           (M2D_history_basic_RFR_EURO ~= 0);

        %   Matrix with same rows as the dates with market data
        %   for the calculation of the long term average spreads,
        %   and same columns (60 for maturities 1 to 60)
        %   Values are 1 only for those dates and maturities where
        %   there are non zero rates for both the basic risk-free curve
        %   and the government bond curve.
        %   Otherwise (one of the rates being null or both of them)
        %   the value is zero.
            
       M2D_numerator = M2D_history_basic_RFR      .*  M2D_non_zero_data  -...
                       M2D_history_basic_RFR_EURO .*  M2D_non_zero_data;
 
                   

        if date_calc > date_change_method_LTAS   %  from 1/1/2016 onwards
  
            %   Reconstruction LTAS. Technical Documentation. Subsect 9.B.1 
         
           V1R_new_spreads = sum(M2D_numerator, 1);
          
            %   vector row with 60 columns containing the sum of spreads 
            %   for maturities 1 to 60 years only for those dates
            %   from 1-1-2016 onwards            
            
            
            V1R_num_new_dates_with_data = sum(M2D_non_zero_data, 1);
          
            %   vector row with 60 columns containing the number of 
            %   new dates with spreads for each maturity  
             
           
            %   Str_LTAS_YE2015.Basic.M2D_spread_basic_RFR_to_euro_YE2015
            %   is a 2-dimensional matrix with 60 columns containing
            %   in each row the LTAS as of 31-12-2015 for each country
            
            Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(run_country,:) =  ...
                ( Str_LTAS_YE2015.Basic.M2D_spread_basic_RFR_to_euro_YE2015 ( run_country , : ) .* ( 7800 - V1R_num_new_dates_with_data ) + ...
                  V1R_new_spreads ) / 7800 ;
              
            Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter(run_country,:) = ...
                                          sum(M2D_non_zero_data,1);

        else
            
            %   Before 01-01-2016, no reconstruction of LTAS

            Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(run_country,:) = ...
                sum ( M2D_numerator , 1 ) ./  sum (M2D_non_zero_data, 1);

            Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter(run_country,:) = ...
                                          sum(M2D_non_zero_data, 1);
   
        end           
 
        
                
    end     %   end of the for  regarding countries/currencies
    


%   =======================================================================
%%  4. Special case of the Icelandic currency. No history of basic RFR   
%   =======================================================================    
    
    row_ISK = strcmp('ISK', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166)); 

    row_HRK  = strcmp('HRK', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166)); 
    
        % this really does not deliver any LTAS

        % it is used just for systematic of the process and
        % to allow in the future to assign a peer country to ISK
        % since this currency is exclued from the table 11 of
        % EIOPA Technical Documentation (October 27th, 2015)

    
    Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread (row_ISK,:) = ...
            Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(row_HRK,:);

    Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter (row_ISK,:) = ...
            Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_counter(row_HRK,:);


        
        
        
%   =======================================================================                  
%%  5. Updating the structure with the information referred to 31/12/2015
%   Section 10.C.4 of EIOPA Technical Documentation October 27, 2015   
%   =======================================================================

    if date_calc  <=  date_change_method_LTAS

       Str_LTAS_YE2015.Basic.M2D_spread_basic_RFR_to_euro_YE2015 = ...
                     Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread ;

       save(fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                        'Str_LTAS_YE2015'), 'Str_LTAS_YE2015'); 
    
    end
