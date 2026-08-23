function [Str_History_basic_RFR] = VA_History_basic_RFR_batch_all_curves(config)

%%  0. Explanation of this function
%   This function manages the historical series of basic risk free rates
%   -----------------------------------------------------------------------
    % to avoid LaTex messages in command window
    set(0, 'DefaulttextInterpreter', 'none');
        

%   =======================================================================
%%  1. Loading configuration and historical series of curves 
%   =======================================================================  

    %   1.1. Loading to workspace the configuration data
    %   ------------------------------------------------------------------- 
    
    info = 'Calculating the historical RFR curves...';
    RFR_log_register('05_History_basic_RFR', 'VA_History_basic_RFR', ...
        'INFO', info, config);     
    
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    
        %   number of the column in cell array
        %   'config.RFR_Str_lists.C2D_list_curncy'  containing ISO3166 and ISO4217
        %   for each of the currencies / countries considered
    
    C1C_countries_ISO4217 = config.RFR_Str_lists.C2D_list_curncy(:,col_ISO4217);
        
    
    %   1.2. Loading the history of swap and government bond curves
    %   -------------------------------------------------------------------   
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'RFR_basic_curves'; 
    
        %   Name of the MatLab structure with all historical series
        %   of interest rates 
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));
    
    
    
    %   1.3. Loading to workspace the history of basic risk-free curves
    %   -------------------------------------------------------------------  
    
    folder_download = config.RFR_Str_config.folders.path_RFR_05_LTAS;    
    file_download = 'Str_History_basic_RFR';   
    
        %   Name of the MatLab structure with the historical
        %   series of basic risk-free interest rates
        %  (all extrapolated for each date and currency with S-W method)
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60

	%   This structure is generated with a batch process
	%   with the function  'VA_History_basic_RFR_batch.m'
        
    load(fullfile(folder_download, file_download));
    

    start_date = config.startDate;
    end_date   = config.refDate;

    
    %   The user introduced start and end dates and these are workable
    
    info = ['User has selected the following dates: Start_date: ', ...
        datestr(start_date, 'dd/mm/yyyy'), '. End_date: ', datestr(end_date, 'dd/mm/yyyy')];      
    RFR_log_register('05_History_basic', 'VA_History_basic_RFR',...
        'INFO', info, config);
 
%   =======================================================================
%%  3. Main loop for each date
%   =======================================================================
    for run_date =  start_date:end_date
            
        %   3.1. Controlling there are market data for the date of the run
        %   ---------------------------------------------------------------
        
        row_to_use =(RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(:,1) == run_date);
        
        if ~any(row_to_use)
           % the date is a date with no market data(e.g. non-trading day)
           continue
        end
        
        date_calc = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(row_to_use,1);
        
         info = ['Calculating the historical RFR curves for ', ...
             datestr(date_calc, 'dd/mm/yyyy')];
         RFR_log_register('05_History_basic_RFR', 'VA_History_basic_RFR', ...
        'INFO', info, config);
        
        %   3.2. Running the process as in   'RFR_00_basic_main_function'
        %   see the explanations in such function
        %   ---------------------------------------------------------------
           
        [Str_assumptions,M2D_raw_curves,M2D_DLT] = ...
             RFR_03_basic_Preparing_calculations(config, date_calc);
             
        [Str_assumptions, M2D_raw_curves, M2D_DLT] =...
             RFR_04_basic_currency_specificities ...
               (config, date_calc, Str_assumptions, ...
                   M2D_raw_curves, M2D_DLT);                            

       [V1C_CRA_date_calc] = RFR_05_basic_CRA_calculation ...
                         (config, date_calc, ...
                            M2D_raw_curves, M2D_DLT);
        
        M2D_CRA_date_calc = repmat(V1C_CRA_date_calc, ...
                                1 ,  size(M2D_raw_curves, 2));

        ER_no_VA = RFR_06A_extrapol_main_loop ...
                 (date_calc, Str_assumptions, config, ...
                    M2D_raw_curves, M2D_CRA_date_calc, M2D_DLT, false);

        errors = RFR_08_validation(config, ER_no_VA);
    
        if ~isempty(errors)
            msg = strcat(datestr(run_date, 'dd/mm/yyyy'), ...
                ': Input rates and extrapolated rates differ for: ',...
                join(errors, ';'));
            warning(char(msg));
            RFR_log_register('05_History_basic_RFR', 'RFR_08_validation', 'WARNING', msg, config);
        else
            RFR_log_register('05_History_basic_RFR', 'RFR_08_validation', 'INFO', ...
                ['Validation of the difference between calculated rates and input rates ',...
                'for DLT points finished without any findings.'], config);
        end
              
                
        %   3.3. Storing results in the historical series basic RFR curves
        %        which is the structure  'Str_History-basic_RFR'
        %   ---------------------------------------------------------------

        for k1 = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1)
            
            
            name_curve = strcat(config.RFR_Str_lists.C2D_list_curncy{k1, col_ISO4217}, '_RFR_basic_spot');

            
            if strcmp('EUR', config.RFR_Str_lists.C2D_list_curncy(k1,col_ISO4217)) &&  k1 > 1 
                % The Euro is the first run
                % The countries of the Eurozone are not processed
                continue
            end
            
            if strcmp('ISK', config.RFR_Str_lists.C2D_list_curncy(k1,col_ISO3166))                
                % For the time being there is no history of basic RFR
                % for the Icelandic krona
                continue
            end
            
            if strcmp('LIC', config.RFR_Str_lists.C2D_list_curncy(k1,col_ISO3166))
                name_curve = strcat(config.RFR_Str_lists.C2D_list_curncy{k1,col_ISO3166}, '_RFR_basic_spot');
                %   with this instruction a curve labelled as 'LIC' - Liechtenstein
                %   is created, although using the Swiss Franc as set up in config.RFR_Str_config.xlsx
                continue
            end
 
            
            try

                M2D_existing_History = Str_History_basic_RFR.(name_curve); 
                
                row_to_write =(M2D_existing_History(:,1) == run_date);
                
                if sum(row_to_write) == 1
                    
                   M2D_existing_History(row_to_write, 1) = date_calc;   
                   
                   M2D_existing_History(row_to_write,2:end) = ...
                            100 * ER_no_VA.M2D_SW_spot_rates(k1,1:60);   
                    
                else
                    
                   V1R_new_history = [date_calc, ...
                       100 * ER_no_VA.M2D_SW_spot_rates(k1,1:60)];
                   
                   M2D_existing_History = ...
                              [M2D_existing_History;V1R_new_history]; 
                
                end
                
                Str_History_basic_RFR.(name_curve) = M2D_existing_History;
                               
        
            catch
               info = ['Failed update of historical series of basic RFR curves for ', ...
                                C1C_countries_ISO4217{k1}, ' at ', datestr(run_date, 'dd/mm/yyyy'), ...
                                'No basic RFR curve saved for this currency on this day.'];
 
               RFR_log_register('05_History_basic_RFR', 'VA_History_basic_RFR', 'ERROR',...
                   info, config);

               
            end     % end of the try
            
            
        end     % end of the loop for k1 

        info = ['Finished calculating the historical RFR curves for ', ...
             datestr(date_calc, 'dd/mm/yyyy')];
         RFR_log_register('05_History_basic_RFR', 'VA_History_basic_RFR', ...
        'INFO', info, config);
    end     %   end of the loop for  dates
    
 
    %   Specific case for Liechtenstein
    %   -------------------------------
    
        Str_History_basic_RFR.LIC_RFR_basic_spot = ...
                            Str_History_basic_RFR.CHF_RFR_basic_spot; 
                        
                        
    %   Saving results to the hard disk
    %   -------------------------------
    
        save(fullfile(config.RFR_Str_config.folders.path_RFR_05_LTAS,...
            'Str_History_basic_RFR'), 'Str_History_basic_RFR');

    %   pop-up informing end of the process
    %   -----------------------------------
       
       info = ['Update of the history of basic RFR curves concluded. Start date: ',...
           datestr(start_date, 'dd/mm/yyyy'), ', End_date: ',  datestr(end_date, 'dd/mm/yyyy')]; 
       RFR_log_register('05_History', 'VA_History_basic_RFR', 'INFO', info, config);             
      
       RFR_write_log_to_CSV(config);

       
       
       process_msg = {'Update of the history of basic RFR curves concluded and log of events saved in hard disk';...
                    ''; ...
                    ['Start date: ', datestr(start_date, 'dd/mm/yyyy'), ', End date: ',  datestr(end_date, 'dd/mm/yyyy')]; ...
                    ''; ...
                    ['Results have been saved in ', config.RFR_Str_config.folders.path_RFR_05_LTAS]};

       h = warndlg(process_msg, 'End of update of history basic RFR curves');
       
       drawnow
       uiwait(h);
      
end