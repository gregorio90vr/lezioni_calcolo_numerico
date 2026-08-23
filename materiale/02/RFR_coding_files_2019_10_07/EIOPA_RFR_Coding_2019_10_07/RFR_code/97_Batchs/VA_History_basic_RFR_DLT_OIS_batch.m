

function VA_History_basic_RFR_DLT_OIS_batch


        
%%  0. Explanation of this function

%   This function creates the historical serie of basic risk free rates
%   for those currencies whose CRA is based on the CRA of another currency
%   previously calculated

%   The common case is the calculation based on the Euro,
%   but it also may apply to the calculation of the NOK (based on SEK CRA)
%   -----------------------------------------------------------------------



%   =======================================================================
%%  1. Loading configuration, insurance market data and government curves  
%   =======================================================================  


    %   Loading to workspace the configuration data
    %   ------------------------------------------------------------------- 

    RFR_config_mat_file = RFR_01_basic_setting_config;   
    
    load(RFR_config_mat_file)
          
    col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_SWP_GVT = RFR_Str_lists.Str_numcol_curncy.SWP_GVT;
    %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered its ISO3166
        %   and whether the basic RFR curve is based on swaps or govts.

    
        
    
    date_calc = 735964 ; 
    
        % really this date_calc is not used for the real calculations
        % It is just a shortcut to use the function   RFR_02_basic... 
        % used in the calculation of the basic risk free rates
    
    [Str_assumptions, ~, M2D_DLT, ~] = ...
             RFR_03_basic_Preparing_calculations(RFR_config_mat_file, date_calc);
  

           
    %   Names of the folder and the file where
    %   historical series of interest rates are stored  
    %   ------------------------------------------------------------------- 

    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads; 
    file_download = 'RFR_basic_curves';
       
    load(fullfile(folder_download, file_download));
        
    list_curves_stored = fieldnames(RFR_download_BBL_Mid);
        
    
           
    %   Names of the folder and the file where
    %   historical series of interest rates for CRA are stored  
    %   ------------------------------------------------------------------- 

    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads ; 
    file_download = 'RFR_CRA' ;
       
    load(fullfile(folder_download, file_download));
    
    M3D_CRA_complete = M3D_CRA_BBL ;
    M3D_CRA_complete(isnan(M3D_CRA_complete)) = 0;
    
    
    %   Loading the historical series of basic RFR
    %   This series are stored in the structure   'Str_History_basic_RFR'
    %   which is stored in the folder  05_LTAS
    %   ------------------------------------------------------------------- 
    
    folder_download = RFR_Str_config.folders.path_RFR_05_LTAS ; 
    file_download = 'Str_History_basic_RFR' ;
       
    load(fullfile(folder_download , file_download));
       
    
   VecRow_terms = RFR_Str_lists.C2D_years_formats(:,4);
   VecRow_terms = cell2mat(VecRow_terms);

        
    
%   =======================================================================
%%  2. Loop for each currency in order to prepare currency specific inputs
%   =======================================================================


% IMPORTANT  
%   --> A.  The runs of this loop to change to execute
%           calculations only for one currency

        %   The loop may have the following runs
        
        %   EURO  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  Not necessary
        %       FIX 03.  if row_date > 300
        %       FIX 04.  To disable
        
        %   BGN  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  Necessary to enable --> count_curncy = 1  ;
        %       FIX 03.  if row_date > 300
        %       FIX 04.  To enable.  CRA = CRA + 0.05 ;
        
        %   HRK  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 2092
        %                Rows 1 to 2091 empty or incomplete
        %       FIX 02.  Necessary to enable --> count_curncy = 1  ;
        %       FIX 03.  Not relevant
        %       FIX 04.  To disable
        
        %   CZK Use function  'VA_History_basic_RFR_nonDLT_batch.m'
        
        %   DKK  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  Necessary to enable --> count_curncy = 1  ;
        %       FIX 03.  if row_date > 300
        %       FIX 04.  To enable.  CRA = CRA + 0.01 ;
        
        %   HUF  (1 and 2 years maturity switching swaps)
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 575
        %                Rows 1 to 574 empty or incomplete
        %       FIX 02.  Necessary to enable --> count_curncy = 1  ;
        %       FIX 03.  Not relevant
        %       FIX 04.  To disable
       
        %   LIC AND CHF  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 700
        %                OIS rates produce not reliable outputs below 700
        %       FIX 04.  To disable
        
        %   NOK Use function  'VA_History_basic_RFR_nonDLT_batch.m'
        %       after having calculated SEK, because CRA(NOK) = CRA(SEK)
        
        %   PLN  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 510
        %                Rows 1 to 509 empty or incomplete
        %       FIX 02.  Necessary to enable --> count_curncy = 1  ;
        %       FIX 03.  Not relevant
        %       FIX 04.  To disable
        
        %   RON Use function  'VA_History_basic_RFR_nonDLT_batch.m'
        
        %   RUB Use function  'VA_History_basic_RFR_nonDLT_batch.m'
       
        %   SEK  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 1740
        %                OIS rates produce not reliable outputs below 700
        %       FIX 04.  To disable
       
        %   GBP  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 781
        %                OIS rates produce not reliable outputs below 700        
        %       FIX 04.  To disable        
        
        %   CAD  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 1130
        %                OIS rates produce not reliable outputs below 700        
        %       FIX 04.  To disable
               
        %   HKD  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 940
        %                OIS rates produce not reliable outputs below 700        
        %       FIX 04.  To disable        
       
        %   JPY  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 300
        %       FIX 04.  To disable
               
        %   MYR  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 300
        %       FIX 04.  To disable
              
        %   USD  
        %       FIX 01.  for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 1 
        %       FIX 02.  To disable
        %       FIX 03.  if row_date > 1043
        %                OIS rates produce not reliable outputs below 1042        
        %       FIX 04.  To disable
       
          
        
    for count_curncy = 25
        code_curncy = RFR_Str_lists.C2D_list_curncy{count_curncy,col_ISO3166};
        
        
        
        name_basic_RFR_history = strcat(code_curncy,'_RFR_basic_spot');
                            
        if ~any(strcmp(fieldnames(Str_History_basic_RFR), name_basic_RFR_history))
            continue           
            % For the country of the run there is no historical serie 
            % of basic RFR (e.g. for the countries of the Euro area,
            % the only serie applicable is the basic RFR for the Euro)
            % This serie is always the first one
            % Non EEA countries may be in this case as well
        else
            M2D_RFR_basic_spot = Str_History_basic_RFR.(name_basic_RFR_history);
        end
        

        
        %   2.A. Assumptions to use for the extrapolation of each currency             
        %   --------------------------------------------------------------

        coupon_freq = Str_assumptions.VecCol_coupon_freq(count_curncy) ; 
        convergence = Str_assumptions.VecCol_convergence(count_curncy) ; 
        UFR         = Str_assumptions.VecCol_UFR(count_curncy) ;
        LLP         = Str_assumptions.VecCol_LLP(count_curncy) ;
        % alpha       = Str_assumptions.VecCol_alpha (count_curncy) ;
        min_diff    = Str_assumptions.VecCol_min_diff(count_curncy) ;
        
        %   ---------------------------------------------------------------
                
            
        
        %   2.B. Extracting the 2-dimensional matrix with the
        %        historical series of market data to use             
        %   --------------------------------------------------------------
        
        if strcmp(RFR_Str_lists.C2D_list_curncy(count_curncy, col_SWP_GVT), 'SWP')
            
            if sum(strcmp(list_curves_stored , strcat(code_curncy , '_RAW_SWP_BBL'))) == 1               
               instrCode = strcat(code_curncy, '_RAW_SWP_BBL');
               M2D_RFR_curves_raw = RFR_download_BBL_Mid.(instrCode);               
            else
                continue
            end        
            
            if strcmp(RFR_Str_lists.C2D_list_curncy(count_curncy, col_ISO3166), 'BGN')  ||  ...
               strcmp(RFR_Str_lists.C2D_list_curncy(count_curncy, col_ISO3166), 'DKK')
           
               M2D_RFR_curves_raw = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL;
           
            end
            
        end
        
        
        if strcmp(RFR_Str_lists.C2D_list_curncy(count_curncy, col_SWP_GVT), 'GVT')
            
            if sum(strcmp(list_curves_stored, strcat(code_curncy, '_RAW_GVT_BBL'))) == 1                
                instrCode = strcat(code_curncy, '_RAW_GVT_BBL');
                M2D_RFR_curves_raw = RFR_download_BBL_Mid.(instrCode);             
            else
                continue
            end
        end
        
        %   ---------------------------------------------------------------        
        

        M2D_extrapolated_RFR = zeros ( size( M2D_RFR_curves_raw , 1 ) , 61 ) ;
         
        M2D_extrapolated_RFR ( : , 1 ) = M2D_RFR_curves_raw ( : , 1 ) ;

        
%   =======================================================================
%%  3. Internal loop for DLT control, CRA and extrapolation each currency
%   =======================================================================

        %%   FIX 01. Control of historical dates to calculate

        for row_date =  size( M2D_RFR_curves_raw ,1 ) : -1 : 510 
            
            display(row_date)
                 
        %  3.A. Selecting the market data for the concrete date of the run 
        %   ---------------------------------------------------------------
        
            V1C_RFR_curves_raw = M2D_RFR_curves_raw(row_date, 2:end);
                        
            if sum(V1C_RFR_curves_raw) == 0
                continue
            end
                                                        
            
        %  3.D. Preparing inputs for extrapolation 
        %   ---------------------------------------------------------------
            
            
            posic_DLT = ( M2D_DLT ( count_curncy , 1:LLP ) == 1 ) &  ...
                        ( V1C_RFR_curves_raw ( 1: LLP ) ~= 0 );

            if sum ( posic_DLT ) < 6
               %    this is necessary for currencies such as CZK or HUF
               %    because for some dates only a few rates are available
               %    and the extrapolation does not deliver reliable outputs
               continue
            end

            VecCol_t     = VecRow_terms( posic_DLT )' ; 
            LLP = max ( VecCol_t ) ;

            VecCol_rates = V1C_RFR_curves_raw ( posic_DLT  )' ;


            %   -----------------------------------------------------------
            %%   CRA CALCULATION
            %   -----------------------------------------------------------

            %   Selecting data referred only to last calendar year 
            %   -----------------------------------------------------------------------        

            date_calc = M2D_RFR_curves_raw( row_date , 1 ) ;

            %%  FIX 02. Control of currencies pegged to the Euro 

            count_curncy = 1  ;  % only for BGN and DKK

            
            %%  FIX 03. Control of oldest date to calculate CRA 
               
            if row_date > 510

                row_date_ini  = find ( M3D_CRA_complete( : , 1 , 1 ) >=  date_calc - 365  , 1 , 'first' ) ;


                %   Counting the number of dates during last year with market rates
                %   for both swap markets and overnight swap markets   ----------------

                M3D_CRA_last_year = M3D_CRA_complete( row_date_ini : row_date , : , : ) ;

                num_rates_last_year = size ( M3D_CRA_last_year , 1 ) ;

                VecRow_dates_with_data = sum ( M3D_CRA_last_year ( : , 2:end , 1 ) ~= 0 .* ...
                                               M3D_CRA_last_year ( : , 2:end , 2 ) ~= 0 , ...
                                                1 ) ;

                    %   row vector, where each column refers to each country and
                    %   reflects the number of dates with market data existing
                    %   for both the IBOR rates and the overnight rates
                    %   (before the interpolation applied in the following step)

                    %   this vector will govern different alternatives for 
                    %   the calculation of the credit risk adjustment


                %%  3. Interpolation to fill in dates without market rates
                %   -----------------------------------------------------------------------        

                if VecRow_dates_with_data ( count_curncy ) >= ...
                                           0.80 * num_rates_last_year ;       

                    for pannel = 1 : 2

                        %   Interpolation of swap rates (pannel 1) 
                        %   and overnight (pannel 2),... for the currency of each run
                        %   -----------------------------------------------------------

                        %   This interpolation is in section 4.C. Technical Documentation
                        %   Formal transformation for an easier notation

                        Vector_int = M3D_CRA_complete ( : , count_curncy+1 , pannel ) ;            
                                %   Reminder: First column of 3D matrix contains dates
                                %             Then it has as many columns as countries + 1                              

                        %   if first dates are empty... first non-empty rate copied
                        first_nonzero_row = find ( Vector_int ~= 0 , 1 , 'first' ) ;

                        if first_nonzero_row > 1
                           Vector_int ( 1 : first_nonzero_row ) = ...
                                        Vector_int ( 1 : first_nonzero_row ) ;
                        end

                        %   if last dates are empty... last non-empty rate copied
                        last_nonzero_row  = find ( Vector_int ~= 0 , 1 , 'last' ) ;

                        if last_nonzero_row < length ( Vector_int ) 
                            last_nonzero_rate = Vector_int( last_nonzero_row ) ;
                            Vector_int( last_nonzero_row+1:end) = last_nonzero_rate ;
                        end

                        %   linear interpolation properly speaking
                        nonzero_rows = ( Vector_int ~= 0 ) ;

                        M3D_CRA_complete( : , count_curncy+1, pannel ) = ...
                                  interp1 ( M3D_CRA_complete ( nonzero_rows , 1 , pannel ) ,...
                                            Vector_int( nonzero_rows ) , ...
                                            M3D_CRA_complete ( : , 1 , pannel )  , 'linear' ) ;


            %   -----------------------------------------------------------------------
            %%  4. Calculation of the CRA
            %   -----------------------------------------------------------------------        

                    CRA = 0.50 * mean ( M3D_CRA_last_year ( : , count_curncy + 1 , 1 ) - ...
                                        M3D_CRA_last_year ( : , count_curncy + 1 , 2 )  ) ;

                    end                
                end
                
                
            else
                CRA = 0.10 ;
            end
                
            %   -----------------------------------------------------------
            %%   END OF CRA CALCULATION
            %   -----------------------------------------------------------
                
            CRA = max( 0.10 , min ( 0.35 , CRA ) ) ;
            CRA = round( CRA*100 ) / 100 ;

            

            
            VecCol_rates = VecCol_rates - CRA ;

            
           if ~isempty(VecCol_t) && max(VecCol_t) >= 7                  

                 [ ~ , SW_yields_spot , ~ ,  ~ , ~, alpha_fit , ~ ] = ...
                        RFR_06B_extrapol_scanning ...
                            ( coupon_freq , convergence , LLP ,...
                              UFR , min_diff , min_alpha , ...
                              VecCol_t , VecCol_rates ) ;

                 V1C_alpha_fit ( row_date ) = alpha_fit ;

                M2D_extrapolated_RFR ( row_date , 2:end ) = ...
                                            100 * SW_yields_spot(1:60) ;

            end


        end     %   end of the while for dates

        M2D_extrapolated_RFR = sortrows(M2D_extrapolated_RFR, 1);

    %   Saving results to the hard disk
    %   -------------------------------
    
        Str_History_basic_RFR.(strcat(code_curncy, '_RFR_basic_spot')) = real(M2D_extrapolated_RFR);

        save(fullfile(RFR_Str_config.folders.path_RFR_05_LTAS,...
            'Str_History_basic_RFR'), 'Str_History_basic_RFR');
 
        save(fullfile(RFR_Str_config.folders.path_RFR_05_LTAS,...
            'V1C_alpha_fit'), 'V1C_alpha_fit');
        
        
        
    end        % end of the for , regarding countries
    

end

