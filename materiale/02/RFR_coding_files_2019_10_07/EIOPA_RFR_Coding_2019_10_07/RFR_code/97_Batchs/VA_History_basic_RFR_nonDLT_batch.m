

function VA_History_basic_RFR_nonDLT_batch


        
%%  0. Explanation of this function

%   This function creates the historical serie of basic risk free rates
%   for those currencies whose CRA is based on the CRA of another currency
%   previously calculated

%   The common case is the calculation based on the Euro,
%   but it also may apply to the calculation of the NOK(based on SEK CRA)
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

        
        
        date_calc = 735964; 
    
        % really this date_calc is not used for the real calculations
        % It is just a shortcut to use the function   RFR_02_basic... 
        % used in the calculation of the basic risk free rates
    
    [ Str_assumptions, ~ , M2D_DLT, ~ ] = ...
             RFR_03_basic_Preparing_calculations(RFR_config_mat_file , date_calc);
  

           
    %   Names of the folder and the file where
    %   historical series of interest rates are stored  
    %   ------------------------------------------------------------------- 

    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads; 
    file_download = 'RFR_basic_curves';
       
    load(fullfile(folder_download, file_download))
        
    list_curves_stored = fieldnames(RFR_download_BBL_Mid);
        
    
    %   Loading the historical series of basic RFR
    %   This series are stored in the structure   'Str_History_basic_RFR'
    %   which is stoerd in the folder  05_LTAS
    %   ------------------------------------------------------------------- 
    
    folder_download = RFR_Str_config.folders.path_RFR_05_LTAS; 
    file_download = 'Str_History_basic_RFR';
       
   load(fullfile(folder_download, file_download))
       
    
   VecRow_terms = RFR_Str_lists.C2D_years_formats(:,4);
   VecRow_terms = cell2mat(VecRow_terms);

        
    
%   =======================================================================
%%  2. Loop for each currency in order to prepare currency specific inputs
%   =======================================================================


% IMPORTANT  
%   --> A.  The runs of this loop to change to execute
%           calculations only for one currency

             
    %   Option B.- Other currencies without DLT OIS
        %   The loop may have the following runs
        %   [  7  27  28  35  36  38  39  40  42  45  46  47  48  49  50  51  52 ]

        
    for count_curncy = 7

        code_curncy = RFR_Str_lists.C2D_list_curncy{count_curncy,col_ISO3166};
        
        name_basic_RFR_history = strcat(code_curncy, '_RFR_basic_spot');
                            
        if ~any(strcmp(fieldnames(Str_History_basic_RFR), name_basic_RFR_history))
            continue           
            % For the country of the run there is no historical serie 
            % of basic RFR(e.g. for the countries of the Euro area,
            % the only serie applicable is the basic RFR for the Euro)
            % This serie is always the first one
            % Non EEA countries may be in this case as well
        else
            M2D_RFR_basic_spot = Str_History_basic_RFR.(name_basic_RFR_history);
        end

        %   2.A. Assumptions to use for the extrapolation of each currency             
        %   --------------------------------------------------------------

        coupon_freq = Str_assumptions.VecCol_coupon_freq(count_curncy); 
        convergence = Str_assumptions.VecCol_convergence(count_curncy); 
        UFR         = Str_assumptions.VecCol_UFR(count_curncy);
        LLP         = Str_assumptions.VecCol_LLP(count_curncy);
        % alpha       = Str_assumptions.VecCol_alpha(count_curncy);
        min_diff    = Str_assumptions.VecCol_min_diff(count_curncy);
        
        %   ---------------------------------------------------------------
                
            
        
        %   2.B. Extracting the 2-dimensional matrix with the
        %        historical series of market data to use             
        %   --------------------------------------------------------------
        
        if strcmp(RFR_Str_lists.C2D_list_curncy(count_curncy, col_SWP_GVT), 'SWP')
            
            if sum(strcmp(list_curves_stored, strcat(code_curncy, '_RAW_SWP_BBL'))) == 1               
                instrCode = strcat(code_curncy, '_RAW_SWP_BBL');
                M2D_RFR_curves_raw = RFR_download_BBL_Mid.(instrCode);             
            else
                continue
            end        
            
            if strcmp(RFR_Str_lists.C2D_list_curncy(count_curncy, col_ISO3166), 'BGN') ||  ...
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
        

        M2D_extrapolated_RFR = zeros(size(M2D_RFR_curves_raw,1), 61);
         
        M2D_extrapolated_RFR(:,1) = M2D_RFR_curves_raw(:,1);

        
%   =======================================================================
%%  3. Internal loop for DLT control, CRA and extrapolation each currency
%   =======================================================================

        
        for row_date =  1:size(M2D_RFR_curves_raw,1) 
            
            row_date
                 
        %  3.A. Selecting the market data for the concrete date of the run 
        %   ---------------------------------------------------------------
        
            V1C_RFR_curves_raw = M2D_RFR_curves_raw(row_date,2:end);
                        
            if sum(V1C_RFR_curves_raw) == 0
                continue
            end
                                                        
            
        %  3.D. Preparing inputs for extrapolation 
        %   ---------------------------------------------------------------
            
            
            posic_DLT =(M2D_DLT(count_curncy , 1:LLP) == 1) &  ...
                      (V1C_RFR_curves_raw(1: LLP) ~= 0);

            if sum(posic_DLT) < 6
               %    this is necessary for currencies such as CZK or HUF
               %    because for some dates only a few rates are available
               %    and the extrapolation does not deliver reliable outputs
               continue
            end

            VecCol_t     = VecRow_terms(posic_DLT)'; 
            LLP = max(VecCol_t);

            VecCol_rates = V1C_RFR_curves_raw(posic_DLT )';

            
            
            %   IMPORTANT: To choose one the two following options
            
            
            %   Option A.1.- For government bonds EEA
                       
            CRA = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(row_date, 2) - ...
                 Str_History_basic_RFR.EUR_RFR_basic_spot(row_date, 2);

            %   Currencies pegged to the euro
            %   Use function  'VA_History_basic_RFR_DLT_OIS_batch.m'
  
            %   Option B.- Other currencies without DLT OIS

            CRA_EUR = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(row_date, 2) - ...
                 Str_History_basic_RFR.EUR_RFR_basic_spot(row_date, 2);

            VecCol_rates_EUR = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(row_date, 2:end);
            
            ratio = sum(VecCol_rates) ./ ...
                    sum(VecCol_rates_EUR(posic_DLT));
             
            CRA = max(0.10 , min(0.35 , CRA_EUR * ratio));
            
             
             
            %   for the Norwegian currency the following instructions apply
            %   CRA = RFR_download_BBL_Mid.SEK_RAW_SWP_BBL(row_date, 2) - ...
            %        Str_History_basic_RFR.SEK_RFR_basic_spot(row_date, 2);

            VecCol_rates = VecCol_rates - CRA;

            
           if ~isempty(VecCol_t) && max(VecCol_t) >= 7                  

                 [ ~ , SW_yields_spot , ~ ,  ~ , ~, alpha_fit , ~ ] = ...
                        RFR_06B_extrapol_scanning ...
                          (coupon_freq , convergence , LLP ,...
                              UFR , min_diff , min_alpha , ...
                              VecCol_t , VecCol_rates);

                 V1C_alpha_fit(row_date) = alpha_fit;

                M2D_extrapolated_RFR(row_date , 2:end) = ...
                                            100 * SW_yields_spot(1:60);

            end


        end     %   end of the while for dates
        

        M2D_extrapolated_RFR = sortrows(M2D_extrapolated_RFR , 1);
 
        
        
    %   Saving results to the hard disk
    %   -------------------------------
    
        Str_History_basic_RFR.(strcat(code_curncy, '_RFR_basic_spot')) = real(M2D_extrapolated_RFR);

%        save('Str_History_basic_RFR' , 'Str_History_basic_RFR')
        
        save(fullfile(RFR_Str_config.folders.path_RFR_05_LTAS,...
            'Str_History_basic_RFR'), 'Str_History_basic_RFR'))
 
        save(fullfile(RFR_Str_config.folders.path_RFR_05_LTAS,...
            'V1C_alpha_fit'), 'V1C_alpha_fit')
        
%        close(mssge_wait_bar)
%        drawnow
        
        
    end        % end of the for , regarding countries
    

end

