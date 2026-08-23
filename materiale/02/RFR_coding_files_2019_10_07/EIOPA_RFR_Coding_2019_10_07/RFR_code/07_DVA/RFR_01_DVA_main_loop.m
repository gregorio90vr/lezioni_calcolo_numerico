function  [Str_vola,date_calc] = RFR_01_DVA_main_loop(RFR_config_mat_file) 


%%  EXPLANATION OF THIS FUNCTION
%   -----------------------------------------------------------------------

%   This function simply contains the loop of currencies
%   and launches the following function in order to carry out
%   the calculations aimed to control volatility 


        
%  ------------------------------------------------------------------------
%%  1. Previos load of necessary variables in workspace
%  ------------------------------------------------------------------------ 
 
    load(RFR_config_mat_file)
                 
    col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_SWP_GVT = RFR_Str_lists.Str_numcol_curncy.SWP_GVT;
    %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered its ISO3166
        %   and whether the basic RFR curve is based on swaps or govts.


    load(fullfile(RFR_Str_config.folders.path_RFR_99_Workspace, ...
                        'RFR_02_preparing_calculations_workspace'));
    
    
    %   The previous 'load' brings to the workspace 
    %   the last date of calculation of the basic risk free curves
    %
    %   It is relevant to provide the user with the possibility 
    %   of running DVA with a different date of calculation 
    % ---------------------------------------------------------------------

    input_msg = {'Enter reference date of DVA calculations. Format dd/mm/yyyy. If no exact match, nearest previous date will be calculated'};
                  
    dlg_title = 'Date of calculation of DVA analysis';
    num_lines = 1;
    def = {'31/12/2014'};
    
    date_calc = inputdlg(input_msg, dlg_title, num_lines, def);
    date_calc = datenum(date_calc, 'dd/mm/yyyy');

    drawnow

    %   -------------------------------------------------------------------
        
    VecRow_terms = cell2mat(RFR_Str_lists.C2D_years_formats(:, 4)');

        %   Row vector with the maturities observed in financial markets
        %  (including those intermediate without values)
        %   Currently(year 2014) from 1 to 60 years

        
%  ------------------------------------------------------------------------
%%  2.Creating 3-D matrices to store results for each currency and maturity
%  ------------------------------------------------------------------------ 
        
    num_countries  = size(RFR_Str_lists.C2D_list_curncy, 1);

    num_dates_vola = 105;
    
    num_terms = length(VecRow_terms);
   
    Str_vola.M3D_par_mkt_rates = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);

    Str_vola.M3D_zero_spot_rates = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);
     
    Str_vola.M3D_fwd_rates  = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);
                
    Str_vola.M3D_par_mkt_vola  = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);                
                
    Str_vola.M3D_zero_spot_vola  = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);
                
    Str_vola.M3D_fwd_vola   = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);
                
    Str_vola.M3D_Roll = ...
                    zeros(num_dates_vola, num_terms + 1, num_countries);
        

    Str_vola.M3D_fwd_fit_diff      = ...
                    zeros(num_dates_vola, 21 + 1, num_countries);
                
    Str_vola.M3D_fwd_fit_last_date = ...
                    zeros(21, 3, num_countries);

                
                
    var_aux =(RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(:,1) <= date_calc);
    posic_date_calc  = find(var_aux == 1, 1, 'last');
    
    VecCol_dates_vola = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(posic_date_calc - num_dates_vola + 1 : posic_date_calc, 1);

    M2D_dates_vola = repmat(VecCol_dates_vola, [ 1, 1, num_countries ]);

    
    Str_vola.M3D_par_mkt_rates(:, 1, :)   = M2D_dates_vola;

    Str_vola.M3D_zero_spot_rates(:, 1, :) = M2D_dates_vola;    
    Str_vola.M3D_fwd_rates(:, 1, :)       = M2D_dates_vola;
        
    Str_vola.M3D_par_mkt_vola(:, 1, :)    = M2D_dates_vola; 
    Str_vola.M3D_zero_spot_vola(:, 1, :)  = M2D_dates_vola;    
    Str_vola.M3D_fwd_vola (:, 1, :)       = M2D_dates_vola;
    
    Str_vola.M3D_fwd_fit_diff(:, 1, :)    = M2D_dates_vola;
    
    Str_vola.M3D_fwd_fit_last_date(:, 1, :) = ...
      repmat(VecCol_dates_vola(end-20 : end), [ 1, 1, num_countries ]);

            
        
%  ------------------------------------------------------------------------
%%  3. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 

        
    for counter_dates = 1:size(Str_vola.M3D_par_mkt_rates, 1);
                 
        
        %   3.2. Running the process as in   'RFR_00_basic_main_function'
        %   see the explanations in such function
        %   ---------------------------------------------------------------

        date_calc_run = Str_vola.M3D_par_mkt_rates(counter_dates, 1, 1);

        [ Str_assumptions, M2D_raw_curves, M2D_DLT ] = ...
             RFR_03_basic_Preparing_calculations(RFR_config_mat_file, date_calc_run);

        [ Str_assumptions, M2D_raw_curves,  M2D_DLT ] =...
             RFR_04_basic_currency_specificities ...
               ( RFR_config_mat_file, date_calc_run, Str_assumptions, ...
                   M2D_raw_curves , M2D_DLT);
         
        
        [ V1C_CRA_date_calc ] = RFR_05_basic_CRA_calculation ...
                         (RFR_config_mat_file, date_calc_run, ...
                            M2D_raw_curves, M2D_DLT);

        M2D_CRA_date_calc = repmat(V1C_CRA_date_calc, ...
                                1 ,  size(M2D_raw_curves, 2));
                                 
       

        VecCol_VA = V1C_CRA_date_calc * 0;  

        ER_no_VA = RFR_06A_extrapol_main_loop ...
                 (date_calc_run, Str_assumptions, RFR_config_mat_file, ...
                    M2D_raw_curves, M2D_CRA_date_calc, M2D_DLT, VecCol_VA * 0);


        Str_vola.M3D_zero_spot_rates(counter_dates,2:61,:) = ...
                            ER_no_VA.M2D_SW_spot_rates(:,1:60)';     

        Str_vola.M3D_fwd_rates(counter_dates,2:61,:) = ...
                            ER_no_VA.M2D_SW_forward_rates(:,1:60)';
        
    end
    

        
%  ------------------------------------------------------------------------
%%  3. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 


    for counter_country = 1:num_countries
        
        if sum(M2D_raw_curves(counter_country, :)) == 0  || ...
           sum(M2D_raw_curves(counter_country, :) ~= 0) < 5
                % curves with less than 5 observable maturities are not
                % processed
            continue
        end
   
        if strcmp(RFR_Str_lists.C2D_list_curncy{counter_country, col_ISO3166}, 'ISK')
            continue
            %   Icelandic governement bond curve, manually introduced
            %   see function   RFR_05A_basic_manual_amendments.m
        end
        
        
        % 3.A.  Filling in variables whose content is currency specific
        %       but it does not depends on whether the curve to use 
        %       is either 'swap' or 'govt'
        % ----------------------------------------------------------------- 
        
        finan_asset = RFR_Str_lists.C2D_list_curncy(counter_country, col_SWP_GVT);
        finan_asset = finan_asset{1};    %  from cell array to character
        
        code_curncy = RFR_Str_lists.C2D_list_curncy{counter_country, col_ISO3166}      
            %   Not ended with semicoma to allow control on the screen
            %   on the execution of this function
        
                    
        %   3.B  Historical interest rates for the currency in each run
        %        and launching the funtion calculating volatility controls
        %   ---------------------------------------------------------------
           
        %   Name of the MatLab numeric 2-D matrix with the historical
        %   serie of interest rates for the currency of each run

        load(fullfile(folder_download, file_download), 'RFR_download_BBL_Mid')


        %   Control of whether the curve does not exist
        %  (i.e. it is not observable in financial markets)

        list_curves_stored = fieldnames(RFR_download_BBL_Mid);
        
        
        if strcmp(RFR_Str_lists.C2D_list_curncy(counter_country, col_SWP_GVT), 'SWP')
            
            if sum(strcmp(list_curves_stored, strcat(code_curncy, '_RAW_SWP_BBL'))) == 1
                
                instrCode = strcat(code_curncy, '_RAW_SWP_BBL');
                M2D_curves_history = RFR_download_BBL_Mid.(instrCode);
            else
                continue
                %   theoretically this control is not necessary becasue
                %   it has been already applied in the previous function
            end

            
        end
        
        
        if strcmp(RFR_Str_lists.C2D_list_curncy(counter_country,col_SWP_GVT), 'GVT')
            
            if sum(strcmp(list_curves_stored, strcat(code_curncy, '_RAW_GVT_BBL'))) == 1
                
                instrCode = strcat(code_curncy, '_RAW_GVT_BBL');
                M2D_curves_history =  RFR_download_BBL_Mid.(instrCode);
                
            else
                continue
                %   theoretically this control is not necessary becasue
                %   it has been already applied in the previous function
            end

            
        end             
        

        Str_vola.M3D_par_mkt_rates(:,:,counter_country) = ...
            M2D_curves_history(posic_date_calc - num_dates_vola + 1 : posic_date_calc,:);        

        %   ===============================================================
        
        %   ===============================================================
        
        [ Str_vola ] = RFR_02_DVA_calculations ...  
                 (RFR_config_mat_file, counter_country, ...
                    num_dates_vola, date_calc, Str_assumptions,...
                    VecRow_terms, M2D_curves_history, Str_vola) ;      
                
                
                
    end     % this refers to the loop for each currency
 
    
        
%   =======================================================================
%%  Writing DLT data in excel  % This function is deactivated   
%   =======================================================================

    %    RFR_05_DVA_writing_excel_results...
    %                      (RFR_config_mat_file, VecCol_with_curves, ...
    %                         VecRow_terms, Str_vola);



    save(fullfile(RFR_Str_config.folders.path_RFR_99_Workspace, ...
                                        'RFR_DVA_workspace'))
    
end

