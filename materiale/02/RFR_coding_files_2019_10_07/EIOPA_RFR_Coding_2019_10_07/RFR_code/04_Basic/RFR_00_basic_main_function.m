function action = RFR_00_basic_main_function(codeDirectory, config)
 
%   -----------------------------------------------------------------------                           
%%  1. Setting the folders of data, configuration and results  
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------
    action = 'OK';
    
    info = 'Starting the calculation of the RFR...';
    RFR_log_register('00_Basic', 'RFR_00_basic', 'INFO', info, config);     
    
    %   All the folders used in this process should have 
    %       -->   a common parent folder, and
    %       -->   a specific predetermined name.

    %   RFR_01_basic_setting_config.m    is a simple function where
    %   the parent or 'main folder' is identified,
    %   and also the complete paths of the children folders that
    %   will be used in this application.

    %   Set of paths are created in this function and should be stored 
    %       in a MatLab mat file named      EIOPA_RFR_config.mat
    %       in a structure named            RFR_Str_config
    %   which should be stored in folder '01_Config' just below main folder

    %   Configurations are read from an excel file and should be stored 
    %       in a MatLab mat file named      EIOPA_RFR_config.mat  
    %       in a structure named            RFR_Str_lists
    %       and cell arrays 'RFR_basic_ADLT_SWP' and 'RFR_basic_ADLT_GVT'
    %   which should be stored in folder '01_Config' just below main folder


    %   OUTPUT OF THIS FUNCTION  ------------------------------------------   
        
        %   The output of this function is a variable string named
        %   'RFR_config_mat_file'  that simply contains the complete name
        %   of the path ending in the folder  '01_Config'
        
        %   This variable will be used repeteadly in the following 
        %   because it gives access to the configuration files,
        %   which allow to access and govern all the elements of the
        %   application        
        

    % 1.B. Date of calculation in format 'dd/mm/yyyy' 
    % ---------------------------------------------------------------------

    %   First Loading the history of swap and government bond curves
        
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'RFR_basic_curves'; 
    
        %   Name of the MatLab structure with all historical series
        %   of interest rates 
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));

    date_calc = config.refDate;
    
    if ~isbusday(date_calc, NaN)
        tmpDate = busdate(date_calc, 'previous', NaN);
        
        info = [datestr(date_calc) ' is not a business day. Using ' datestr(tmpDate) ...
            ' instead.'];
        RFR_log_register('00_Basic', 'RFR_00_basic', 'WARNING', info, config); 
        
        date_calc = tmpDate;
    end
  
%   -----------------------------------------------------------------------                           
%%  2. Control of alignment of vector dates for all historical databases
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------           

    %   This funtion informs whether all historical databases have 
    %   the same history of dates. 
    %   Otherwise the calculations should not be run,
    %   because outputs will likely be wrong or the process will fail
    
    %   This function only controls the vector of dates of each database
    %   It does not control the information stored in each date
    %  (this control is developed in other stepts of the process)
    
    %   In case of identifying any lack of alignment, the user has freedom
    %   to cancel the calculation or continue it(the misalignement refers
    %   to a database that may be not used)
    
    %   The selection of the user is the output  'user_action'

      
    aligned = RFR_02_basic_control_alignment_data_bases(config,...
                {'GVT','SWP','CRA','CORP','DKK','RFR'});          
   
    if ~aligned
        info = 'Section 2. Input data not aligned. Some term structures may not get calculated correctly.';
        RFR_log_register('00_Basic', 'RFR_00_basic', 'WARNING', info, config); 
        
    end
%   -----------------------------------------------------------------------                           
%%  3. Preparing market data and assumptions for extrapolation  
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------           

    %   The relevant market data for each currency
    %  (either swap rates or government bond rates) are extracted
    %   and gather in the 2-dimensional matrix  'M2D_raw_curves'
    
    %   NOTE: In the case of the euro, each country is consider separately
    %         in all the steps of the calculation.
    %         Then, the respective risk free interest rates term structures
    %         are calculated for each country 
    %        (because of the 'national volatility adjustment')
    
    %   The list of DLT maturities for each currency is also expressed
    %   in the 2-dimensional matrix  'M2D_DLT'
    
    %   MatLab structure  'Str_assumptions'  store for each currency
    %   each of the assumptions relevant for the extrapolation process
    %  (extrapolation is carried out at a later stage below
    %     in a different function)
    
    
    [Str_assumptions,M2D_raw_curves,M2D_DLT] = ...
             RFR_03_basic_Preparing_calculations(config, date_calc);
     

%%  4. Country specificities, if any(e.g. switchings)  
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------           
     
    [Str_assumptions,M2D_raw_curves,M2D_DLT] =...
             RFR_04_basic_currency_specificities ...
               (config, date_calc, Str_assumptions, ...
                   M2D_raw_curves, M2D_DLT);

                
%   -----------------------------------------------------------------------                           
%%  5. Calculating the credit risk adjustment(CRA)  
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------           
    
    %   The output of this function is a column vector with as many rows
    %   as countries/currencies considered in the calculations
    %   containing the value IN BASIS POINTS of the credit risk adjustment
    %   to the basic risk free interest rate term structure 


    [V1C_CRA_date_calc] = RFR_05_basic_CRA_calculation ...
                         (config, date_calc, ...
                            M2D_raw_curves, M2D_DLT);
              


    M2D_CRA_date_calc = repmat(V1C_CRA_date_calc, ...
                                1,  size(M2D_raw_curves, 2));
    
        %   In most of cases CRA will have a single value for all DLT terms
        %   Nevertheless in case of switching, CRA values may be different
        %   for those terms where the switching is applied

        
        
%   -----------------------------------------------------------------------                           
                   

%   -----------------------------------------------------------------------                                   
%%  6. Calculating extrapolated curves WITHOUT VA. Writing results  
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------            

 %   Structure named 'ER(results) with the following elements
 
        %   ER.VecRow_maturities     
        %      Vector row 1:1:150(maturities) of curves
       
        %   ER.M2D_raw_rates_net_CRA        
        %      Matrix with observed rates in markets once deducted CRA
        %      and before SW extrapolation
        %      Two-dimensional matrix(n rows * 150 maturities).
        %      where each row refers to a currency / country

        %   ER.M2D_SW_spot_rates        
        %      Matrix with zero-coupon annual spot rates resulting from 
        %      SW extrapolation(basic RFR curve, legally speaking)
        %      Two-dimensional matrix(n rows * 150 maturities).        
        %      where each row refers to a currency / country
        
        %   ER.M2D_SW_forward_rates        
        %      Matrix with annual forward rates resulting from 
        %      SW extrapolation
        %      Two-dimensional matrix(n rows * 150 maturities).        
        %      where each row refers to a currency / country
             
        %   ER.M2D_SW_prices        
        %      Matrix with prices resulting from SW extrapolation 
        %      Two-dimensional matrix(n rows * 150 maturities).        
        %      where each row refers to a currency / country  
        
        %   ER.C1C_parameters_SW  = cell(num_curves, 1);       
        %      Cell array whose elements are vectors with Qb parameters
        %      resulting from SW extrapolation for each currency/country
        %      Two-dimensional matrix(n rows * 150 maturities).
        %      where each row refers to a currency / country
                
        %   ER.VecCol_alpha_fit  = zeros(num_curves, 1);        
        %      Vector column with alpha values for each currency/country
        %      at the convergence point

        
   

    ER_no_VA = RFR_06A_extrapol_main_loop ...
                 (date_calc, Str_assumptions, config, ...
                    M2D_raw_curves, M2D_CRA_date_calc, M2D_DLT, false);

        %   any change in this function or any of its children functions
        %   impacts on functions
        %       VA_History_basic_RFR_batch_all_curves.m 
        %       RFR_01_DVA_main_loop.m      
    
        
    %   The below function writes the outputs of the extrapolation
    %   in the internal excel file  'RFR_validation_file.xlsx'
    
    RFR_07_extrapol_writing_validation_in_excel ...
               (config, date_calc, Str_assumptions, ...
                  ER_no_VA, M2D_raw_curves)

               

%   -----------------------------------------------------------------------                                   
%%  7. Calculating the VA.
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------

%   7.1.  Calculating currency VA -----------------------------------------

    %   First run for the calculations based on currency portfolios
    %   The last inputs refers to the long term average spreads.
    
    %   Inside  'RFR_08_VA_MA_main_function.m'  there is a control of
    %   whether the last input, 'Str_LTAS', goes empty or not
    %   Should not be empty, the calculation of the long term average
    %   spreads is skipped
    
    %   Str_VA_Currency contains all information to calculate 
    %   the currency VA
    
    %   STR_LTAS contains all the LTAS calculated
    %   Str_PD_CoD_outputs contains the fundamental spread components

    [Str_VA_Currency,Str_LTAS,Str_PD_CoD_outputs] = ...
        RFR_08_VA_MA_main_function ...
                        (date_calc, config, ...
                            ER_no_VA, 'Currency', []);

    
    
%   7.2.  Calculating national increase VA -----------------------------------------

%   Second run for the calculations based on national portfolios
    
    %   Inside  'RFR_08_VA_MA_main_function.m'  there is a control of
    %   whether the last input, 'Str_LTAS', goes empty or not
    %   Should not be empty, the calculation of the long term average
    %   spreads is skipped

    [Str_VA_National,~,~] = ...
                        RFR_08_VA_MA_main_function ...
                               (date_calc, config, ...
                                  ER_no_VA, 'National', Str_LTAS);
  
    
%   7.3.  Calculating currency and total VA   -----------------------------

    %   Calculations based on currency and national portfolios are merged
    %   in order to derive the currency and the total VA
    %   stored in M2D_VA_final(second column)
    
    [M2D_VA_final,Str_VA_Currency,Str_VA_National] = RFR_09_VA_Overall ...
             (config, Str_VA_Currency, Str_VA_National);

    VecCol_VA = M2D_VA_final(:,2);

 
    
%  7.4. Writing summary of outputs in excel files for testing
%  --------------------------------------------------------------------

       RFR_10_writing_in_excel_VA_validation...
           (ER_no_VA, Str_VA_Currency, Str_VA_National, Str_LTAS, config)

       info = 'Section 7.4. Process has produced Excel test files of the calculation of the VA';
       RFR_log_register('00_Basic', 'RFR_10_writing_in_excel_VA', 'INFO', info, config);     

 
%   -----------------------------------------------------------------------                           
%%  8. Calculating extrapolated curves with VA. Writing results  
%   -----------------------------------------------------------------------
         
    ER_with_VA = RFR_06A_extrapol_main_loop ...
                 (date_calc, Str_assumptions, config, ...
                    M2D_raw_curves, M2D_CRA_date_calc, M2D_DLT, true, VecCol_VA);

     
%  ------------------------------------------------------------------------
%% Compare the SW inter-/extrapolation with the DLT input data
%  ------------------------------------------------------------------------
    errors = RFR_08_validation(config, ER_no_VA);
    
    if ~isempty(errors)
        msg = strcat('Input rates and extrapolated rates differ for: ',...
            join(errors, ';'));
        warning(char(msg));
        RFR_log_register('04_Basic', 'RFR_08_validation', 'WARNING', msg, config);
    else
        RFR_log_register('04_Basic', 'RFR_08_validation', 'INFO', ...
            ['Validation of the difference between calculated rates and input rates ',...
            'for DLT points finished without any findings.'], config);
    end
    
%   =======================================================================
%%  9. Saving the workspace
%   =======================================================================
    
    save(fullfile(config.RFR_Str_config.folders.path_RFR_99_Workspace,...
                        'RFR_Final_main_function'))
    
    %% Save the results to a MAT file
    folder_download = config.RFR_Str_config.folders.path_RFR_09_Publication;    
    file_download = 'RFR_publication_data.mat'; 
       
    pData = load(fullfile(folder_download, file_download));
    
    idx = 0;
    for i=1:length(pData.publicationData)
        if pData.publicationData(i).date == datetime(config.refDate, 'ConvertFrom', 'datenum')
            idx = i;
        end
    end
    
    if idx == 0
        idx = length(pData.publicationData) + 1;
    end
    
    % No VA
    colISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    countries = config.RFR_Str_lists.C2D_list_curncy(:,colISO3166);
    
    parameters = [Str_assumptions.VecCol_coupon_freq';...
        Str_assumptions.VecCol_LLP';Str_assumptions.VecCol_convergence';...
        Str_assumptions.VecCol_UFR';ER_no_VA.VecCol_alpha_fit';...
        100*ER_no_VA.VecRow_CRA;100 * ER_no_VA.VecRow_VA_total];
    parameters = array2table(parameters, 'VariableNames', countries, ...
       'RowNames', {'Coupon_freq','LLP','Convergence','UFR','alpha','CRA','VA'});
    
    pData.publicationData(idx).date = datetime(config.refDate, 'ConvertFrom', 'datenum');
    pData.publicationData(idx).RFRnoVA.parameters = parameters;
    pData.publicationData(idx).RFRnoVA.rates = array2table(...
        round(ER_no_VA.M2D_SW_spot_rates', 5), 'VariableNames', countries);
    
    % With VA
    parameters = [Str_assumptions.VecCol_coupon_freq';...
        Str_assumptions.VecCol_LLP';Str_assumptions.VecCol_convergence';...
        Str_assumptions.VecCol_UFR';ER_with_VA.VecCol_alpha_fit';...
        100*ER_with_VA.VecRow_CRA;100 * ER_with_VA.VecRow_VA_total];
    parameters = array2table(parameters, 'VariableNames', countries, ...
       'RowNames', {'Coupon_freq','LLP','Convergence','UFR','alpha','CRA','VA'});
    
    % Convert the zeros of countries without VA to NaN
    col_VA_used = config.RFR_Str_lists.Str_numcol_curncy.VA_calculation;
    vaCalculated = logical(cell2mat(config.RFR_Str_lists.C2D_list_curncy(:,col_VA_used)));
    parameters{'VA',~vaCalculated} = nan;
    
    pData.publicationData(idx).RFRwithVA.parameters = parameters;
    pData.publicationData(idx).RFRwithVA.rates = array2table(...
        round(ER_with_VA.M2D_SW_spot_rates', 5), 'VariableNames', countries);
    
    pData.publicationData(idx).VA.Currency = Str_VA_Currency;
    pData.publicationData(idx).VA.National = Str_VA_National;
    save(fullfile(folder_download, file_download), '-struct', 'pData')
%   =======================================================================
%%  10. Excel files with results. Creating the copies for publication  
%   =======================================================================
              
    RFR_11_for_publication_excel_RFR_curves ...
           (config, config.refDate, Str_assumptions, ...
               ER_no_VA, ER_with_VA, Str_VA_Currency);
               
    RFR_12_for_publication_excel_VA(config, Str_VA_Currency, Str_VA_National, config.refDate);
    
 
    RFR_13_for_publication_excel_PD_CoD_corps ...
                    (config, Str_PD_CoD_outputs, Str_VA_Currency, Str_LTAS, config.refDate);
    
    RFR_14_for_publication_excel_SW_Qb(config, ER_no_VA, ER_with_VA, config.refDate);

 
    RFR_15_internal_file_PD_CoD_govts ...
               (config, config.refDate, Str_assumptions, ER_no_VA, ...
                  Str_VA_Currency, Str_LTAS);
              
    RFR_16_COM_report(config, ER_no_VA, Str_LTAS, Str_PD_CoD_outputs, ER_with_VA);

              
    info = 'Section 10. Generic labelled files for publication successfully generated)';
    RFR_log_register('00_Basic', 'RFR_11 to RFR_15', 'INFO', info, config);             
    
              
    %   Creating the files for publication
    %   -------------------------------------------------------------------
    
    
    %   File with the RFR term structures  --------------------------------
    
    date_string = datestr(config.refDate, 'yyyymmdd');

    name_file_original = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results, ...
        'RFR_for_publication_RFR_curves.xlsx');    
    name_file_publication = fullfile(config.RFR_Str_config.folders.path_RFR_09_Publication,...
        strcat('EIOPA_RFR_', date_string, '_Term_Structures.xlsx'));
    
    if exist(name_file_publication, 'file')
        delete(name_file_publication)
    end
    
    copyfile(name_file_original, name_file_publication)

    
    
    %   File with the RFR VA information   --------------------------------
    
    date_string = datestr(config.refDate, 'yyyymmdd');

    name_file_original = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results, ...
        'RFR_for_publication_VA.xlsx');    
    name_file_publication = fullfile(config.RFR_Str_config.folders.path_RFR_09_Publication,...
        strcat('EIOPA_RFR_', date_string, '_VA_portfolios.xlsx'));
    
    if exist(name_file_publication, 'file')
        delete(name_file_publication)
    end
    
    copyfile(name_file_original, name_file_publication)

    
    
    %   File with the RFR PD and COD       --------------------------------
    
    date_string = datestr(config.refDate, 'yyyymmdd');

    name_file_original = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results,...
        'RFR_for_publication_PD_CoD.xlsx');    
    name_file_publication = fullfile(config.RFR_Str_config.folders.path_RFR_09_Publication,...
        strcat('EIOPA_RFR_', date_string, '_PD_Cod.xlsx'));
    
    if exist(name_file_publication, 'file')
        delete(name_file_publication)
    end
    
    copyfile(name_file_original, name_file_publication)
    
    %   IMPORTANT: Without the following line the hyperlinks of this excel
    %              will not work
    
    xlswrite(name_file_publication, {strcat('EIOPA_RFR_', date_string, '_PD_Cod.xlsx')}, 'Main', 'R13');
    
    
    
    %   File with the RFR parameters Smith Wilson   -----------------------
    
    date_string = datestr(config.refDate, 'yyyymmdd');

    name_file_original    = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results,...
        'RFR_for_publication_Qb_SW.xlsx');    
    name_file_publication = fullfile(config.RFR_Str_config.folders.path_RFR_09_Publication,...
        strcat('EIOPA_RFR_', date_string, '_Qb_SW.xlsx'));
    
    if exist(name_file_publication, 'file')
        delete(name_file_publication)
    end
    
    copyfile(name_file_original, name_file_publication)

    

    info = 'Section 10. Files for publication with specific labels(day calculation included) successfully generated)';
    RFR_log_register('00_Basic', 'RFR_00_basic', 'INFO', info, config);             

    
    
    
%   -----------------------------------------------------------------------                           
%%  11. Saving information on this run
%   -----------------------------------------------------------------------
  

    %  9.1. Creating the folder to store this run    ----------------------
       
       str_now = datestr(now(),'yyyy_mm_dd HH_MM');
       
       
       %    an explorer pops up allowing the user to select the folder
       %    where the mirror of the run should be saved
       
        [folder_to_write] = ...
            uigetdir(config.RFR_Str_config.folders.path_RFR_history_runs, ...
                      'Select the folder where the mirror of this session should be saved.');

                %   variable  'folder_to_write'  stores 
                %       the complete path of the selected folder, or...
                %       0 if the user pressed 'Cancel' or closed the box

        drawnow

        if folder_to_write == 0

           process_msg = {'Risk free rates calculation concluded';...
                           ''; ...
                           'IMPORTANT: The mirror of this run has not been created'; ...
                           'because the user did not select a folder for saving it.'; '' };

            h = warndlg(process_msg, 'End of basic risk free curves calculation');
       
            drawnow
            uiwait(h);
            
            info = 'Section 11. History run mirror not saved in hard disk because the user did not identify a folder to copy the files of this run';
            RFR_log_register('00_Basic', 'RFR_00_basic', 'ERROR', info, config);
            RFR_write_log_to_CSV(config); 
            
            return
        end

       config.RFR_Str_config.folders.path_RFR_history_runs = folder_to_write;

       mkdir(config.RFR_Str_config.folders.path_RFR_history_runs, strcat('RFR_curves_', str_now));            

       folder_history_this_run = fullfile(...
                        config.RFR_Str_config.folders.path_RFR_history_runs, ...
                            strcat('RFR_curves_', str_now));
       
       histCodeDirectory = fullfile(folder_history_this_run, 'code');
       mkdir(histCodeDirectory);
       
       histDataDirectory = fullfile(folder_history_this_run, 'data');
       mkdir(histDataDirectory);
       
       
                    
    %  9.2. Copying files to the folder of this run   ---------------------
       
       % Write the log file to disk in order to be included in the backup 
       RFR_write_log_to_CSV(config); 
       
       copyfile(config.RFR_Str_config.folders.path_RFR_main, histDataDirectory);
       copyfile(codeDirectory, histCodeDirectory);
 
       info = ['Section 11. RFR calculation concluded. Full session is stored in ',...
           folder_history_this_run]; 
       RFR_log_register('00_Basic', 'RFR_00_basic', 'INFO', info, config);             
           
       RFR_write_log_to_CSV(config);    

       
       
       process_msg = { 'Risk free rates calculation concluded and log of events saved in hard disk';...
                    ''; ...
                    'Results have been saved in'; ...
                    config.RFR_Str_config.folders.path_RFR_09_Publication; ...
                    ''; ... 
                    'and the full session is stored in'; ...
                    folder_history_this_run };

       h = warndlg(process_msg,'End of basic risk free curves calculation');
       
       drawnow
       uiwait(h);