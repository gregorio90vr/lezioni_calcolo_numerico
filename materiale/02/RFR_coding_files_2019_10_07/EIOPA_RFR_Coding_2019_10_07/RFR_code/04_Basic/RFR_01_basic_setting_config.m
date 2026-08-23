function RFR_config_mat_file = RFR_01_basic_setting_config(main_folder)

%   -----------------------------------------------------------------------
%%  Paths where RFR application is installed + excel file configuration
%   -----------------------------------------------------------------------

    %   Set of paths are created in this function and should be stored 
    %       in a MatLab mat file named      EIOPA_RFR_config.mat
    %       in a structure named            RFR_Str_config
    %   which should be stored in folder '01_Config' just below main folder

    %   Configurations are read from an excel file and should be stored 
    %       in a MatLab mat file named      EIOPA_RFR_config.mat  
    %       in a structure named            RFR_Str_lists
    %       and cell arrays 'RFR_basic_ADLT_SWP' and 'RFR_basic_ADLT_GVT'
    %   which should be stored in folder '01_Config' just below main folder

    RFR_config_mat_file = fullfile(main_folder, '01_Config',...
        'EIOPA_RFR_config.mat');
    RFR_Str_config.folders.path_RFR_main = main_folder;
    RFR_Str_config.folders.path_RFR_00_Uploads = fullfile(main_folder, '00_Uploads');
    RFR_Str_config.folders.path_RFR_01_Config = fullfile(main_folder, '01_Config');
    RFR_Str_config.folders.path_RFR_02_Downloads = fullfile(main_folder, '02_Downloads');
    RFR_Str_config.folders.path_RFR_03_Import = fullfile(main_folder, '03_Import');
    RFR_Str_config.folders.path_RFR_05_LTAS = fullfile(main_folder, '05_LTAS');
    RFR_Str_config.folders.path_RFR_06_VA = fullfile(main_folder, '06_VA');
    RFR_Str_config.folders.path_RFR_07_DVA = fullfile(main_folder, '07_DVA');
    RFR_Str_config.folders.path_RFR_08_Results = fullfile(main_folder, '08_Results');
    RFR_Str_config.folders.path_RFR_09_Publication=fullfile(main_folder, '09_Publication');
    RFR_Str_config.folders.path_RFR_10_Documents=fullfile(main_folder, '10_Documents');

    RFR_Str_config.folders.path_RFR_96_extLib = fullfile(main_folder, '96_extLib');
    RFR_Str_config.folders.path_RFR_97_Batchs = fullfile(main_folder, '97_Batchs');           
    RFR_Str_config.folders.path_RFR_98_Runs_Logs = fullfile(main_folder, '98_Runs_Logs');       
    RFR_Str_config.folders.path_RFR_99_Workspace = fullfile(main_folder, '99_Workspace');   

    
    %   OTHER PATHS TO SET OUT IN CONFIG
    %   -------------------------------------------------------------------
    
    RFR_Str_config.folders.path_RFR_import_iBoxx = ... 
    'R:\Bloomberg\Backoffice\RFR\Backups\Corps\'; 

    RFR_Str_config.folders.path_RFR_history_runs = ... 
        'R:\Production\History runs';
    
    % Load the JSON configuration file
    jsonConfigFile = fullfile(RFR_Str_config.folders.path_RFR_01_Config,...
        'configuration.json');
    try
        jsonConfiguration = jsondecode(fileread(jsonConfigFile));
    catch ME
       error('Couldn''t read the configuration file. Aborting...'); 
    end
    
    % Get the logging configuration
    RFR_Str_config.loggingEnabled = jsonConfiguration.general.loggingEnabled;
    
    
    save(RFR_config_mat_file, 'RFR_Str_config', '-append')
    


%   -----------------------------------------------------------------------
%%  2. Importing to MatLab excel file configuration settings 
%   -----------------------------------------------------------------------
 
    %   Configurations are read from an excel file and should be stored 
    %       in a MatLab mat file named      EIOPA_RFR_config.mat  
    %       in a structure named            RFR_Str_lists
    %       and cell arrays 'RFR_basic_ADLT_SWP' and 'RFR_basic_ADLT_GVT'
    %   which should be stored in  folder '01_Config' just below main folder

    
    % 2.1. List of currencies and information of the financial instruments
    %      and assumptions used to derive the basic risk free curve
    % ---------------------------------------------------------------------
        
    name_excel_file_config = fullfile(main_folder, '01_Config', 'RFR_excel_config.xlsx');
    
    if ~exist(name_excel_file_config, 'file')
        info_message = [name_excel_file_config ...
                ' doesn''t exist. Configuration file couldn''t be found. Aborting...'];            
                             
        RFR_log_register('04_Basic', '01_Config', 'ERROR',...
            info_message, RFR_config_mat_file);
        return
    end
    
    [num,RFR_Str_lists.C2D_list_curncy] = ...
          xlsread(name_excel_file_config, 'C2D_list_curncy', 'B11:AZ300');
    
        % 'xlsread' allocates columns with numeric inputs to a matrix
        %           while columns with strings are stored in a cell array
        %  therefore it is necessary to  merge both of them
        
    cols_with_nums = [2 8 13 15 16 17 18 19 20 22 23 27 29 32 33 42 43 44 45];
      
    RFR_Str_lists.C2D_list_curncy(:,cols_with_nums) = ...
                    num2cell(num(:,cols_with_nums - 1));

         % CAUTION: The first column of the cell array is lost in the
         %          numerical matrix, therefore columns of the 
         %          numerical matric should be reduced in 1
         %          in order to match with columns of the cell array
                

         
    % 2.2.  Identification of the number of column containing each concept
    %       of the cell array  'RFR_Str_lists.C2D_list_curncy' 
    % ---------------------------------------------------------------------
  
    RFR_Str_lists.Str_numcol_curncy.name_country =   1;
    RFR_Str_lists.Str_numcol_curncy.ISO3166      =   3;
    RFR_Str_lists.Str_numcol_curncy.Currency     =   4;    
    RFR_Str_lists.Str_numcol_curncy.ISO4217      =   5;
    RFR_Str_lists.Str_numcol_curncy.EEA          =   6;
    RFR_Str_lists.Str_numcol_curncy.Member_EU    =   7;
    RFR_Str_lists.Str_numcol_curncy.VA_calculation = 8;
   
    RFR_Str_lists.Str_numcol_curncy.gvt_coupon   =  13;
    RFR_Str_lists.Str_numcol_curncy.gvt_cont_compounding = 15;
    
    RFR_Str_lists.Str_numcol_curncy.AN1_order   =  16;
    RFR_Str_lists.Str_numcol_curncy.AN21_order   =  17;
    RFR_Str_lists.Str_numcol_curncy.AN22_order   =  18;
    RFR_Str_lists.Str_numcol_curncy.AN23_order   =  19;
    RFR_Str_lists.Str_numcol_curncy.AN3_order   =  20;
    
    RFR_Str_lists.Str_numcol_curncy.swp_coupon   =  23;
    RFR_Str_lists.Str_numcol_curncy.SWP_float_leg = 26;
    RFR_Str_lists.Str_numcol_curncy.CRA_OIS_rate =  36;
    RFR_Str_lists.Str_numcol_curncy.CRA_IBOR_rate = 37;
    RFR_Str_lists.Str_numcol_curncy.CRA_REF_OIS_rate =  38;
    RFR_Str_lists.Str_numcol_curncy.CRA_REF_IBOR_rate = 39;
    RFR_Str_lists.Str_numcol_curncy.SWP_GVT      =  41;
    RFR_Str_lists.Str_numcol_curncy.LLP_GVT      =  42;
    RFR_Str_lists.Str_numcol_curncy.LLP_SWP      =  43;
    RFR_Str_lists.Str_numcol_curncy.convergence  =  44;
    RFR_Str_lists.Str_numcol_curncy.UFR          =  45;

   
    
         
    % 2.3. List of currencies and identification of DLT maturities
    %      ( DLT are identified for both swaps and government bond rates,
    %        notwithstanding which of them is used to derive
    %        the relevant basic risk free interest rates term structure )
    % ---------------------------------------------------------------------           
    
    
    %   Government bond rates   -------------------------------------------
    
    [num,RFR_basic_ADLT_GVT] = ...
            xlsread(name_excel_file_config, 'ADLT_GVT', 'B11:BZ300');
            
        % 'xlsread' allocates columns with numeric inputs to a matrix
        %           while columns with strings are stored in a cell array
        %  therefore it is necessary to  merge both of them
       
    RFR_basic_ADLT_GVT(:,2) = num2cell(num(:,1));
    
    C2D_num = num2cell(num(:,10:end));
      
    RFR_basic_ADLT_GVT = [RFR_basic_ADLT_GVT,C2D_num];
          
        %   After this instruction, 'RFR_basic_ADLT_GVT' is a cell array.
        %   Ten first columns contain qualitative data of each currency
        %   (some of them are empty for the time being)
        %   Columns 11 to 70 contains either '0' or '1'
        %   depending on the DLT feature of maturities from 1 to 60 years

    % GVT tickers
    % 1. BBG
    RFR_BBG_GVT_Tickers = readTickerTable('BBG_GVT_Tickers', 'GVT_TICKER_TABLE');
    
    % 2. REF
    RFR_REF_GVT_Tickers = readTickerTable('REF_GVT_Tickers', 'GVT_TICKER_TABLE');
   
    %   Swap fixing ibor rates   ------------------------------------------    
                  
    [num,RFR_basic_ADLT_SWP] = ...
            xlsread(name_excel_file_config, 'ADLT_SWP', 'B11:BZ300');
            
        % 'xlsread' allocates columns with numeric inputs to a matrix
        %           while columns with strings are stored in a cell array
        %  therefore it is necessary to  merge both of them
      
    RFR_basic_ADLT_SWP(:,2) = num2cell(num(:,1));

    C2D_num = num2cell(num(:,10:end));       

    RFR_basic_ADLT_SWP = [RFR_basic_ADLT_SWP,C2D_num];

        %   After this instruction, 'RFR_basic_ADLT_SWP' is a cell array.
        %   Ten first columns contain qualitative data of each currency
        %   Columns 11 to 70 contains either '0' or '1'
        %   depending on the DLT feature of maturities from 1 to 60 years
    
    % SWP tickers
    % 1. BBG
    RFR_BBG_SWP_Tickers = readTickerTable('BBG_SWP_Tickers', 'SWP_TICKER_TABLE');
    
    % 2. REF
    RFR_REF_SWP_Tickers = readTickerTable('REF_SWP_Tickers', 'SWP_TICKER_TABLE');   
    
    % CRA tickers
    RFR_basic_CRA_Tickers = RFR_Str_lists.C2D_list_curncy(:,...
        [RFR_Str_lists.Str_numcol_curncy.CRA_OIS_rate ...
        RFR_Str_lists.Str_numcol_curncy.CRA_IBOR_rate]);
    RFR_basic_CRA_Tickers = [RFR_basic_CRA_Tickers(:)]; 
        
    % DKK ticker
    [~,RFR_basic_DKK_Ticker] = ...
            xlsread(name_excel_file_config, 'DKK_Ticker', 'DKK_TICKER');
    [~,RFR_basic_DKK_Duration_Ticker] = ...
            xlsread(name_excel_file_config, 'DKK_Ticker', 'DKK_DURATION_TICKER');

    %   DLT maturities for the calculation of LTAS of Government bonds  ---
    %   -------------------------------------------------------------------
    
    [~,sheets] = xlsfinfo(name_excel_file_config);
    ltasSheets = sheets(cellfun(@(x) ~isempty(x), strfind(sheets, 'DLT_LTAS_GVT')));
    
    [~,ltasDates] = regexp(ltasSheets, 'DLT_LTAS_GVT_(\d{8})', 'match', 'tokens');
    ltasDates = [ltasDates{:}];
    ltasDates = datenum([ltasDates{:}], 'yyyymmdd');
    
    for i=1:length(ltasSheets)
        [num,dltTable] = ...
            xlsread(name_excel_file_config, ltasSheets{i}, 'B11:BZ300');
            
        % 'xlsread' allocates columns with numeric inputs to a matrix
        %           while columns with strings are stored in a cell array
        %  therefore it is necessary to  merge both of them
       
        dltTable(:,2) = num2cell(num(:,1));

        C2D_num = num2cell(num(:,10:end));

        dltTable = [dltTable,C2D_num];

            %   After this instruction, 'dltTable' is a cell array.
            %   Ten first columns contain qualitative data of each currency
            %   (some of them are empty for the time being)
            %   Columns 11 to 70 contains either '0' or '1'
            %   depending on the DLT feature of maturities from 1 to 60 years
            
        RFR_basic_DLT_LTAS_GVT(i).dltTable = dltTable;
        RFR_basic_DLT_LTAS_GVT(i).validFrom = ltasDates(i); 
    end

    % 2.4. List currencies and format years maturity for Bloomberg download
    % ---------------------------------------------------------------------           
                  
    [num,RFR_Str_lists.C2D_years_formats] = ...     
            xlsread(name_excel_file_config, 'Various', 'B11:E70');
    
    C2D_num = num2cell(num);
    
    RFR_Str_lists.C2D_years_formats = ...
                    [RFR_Str_lists.C2D_years_formats, C2D_num];
      
        %   Four columns with different possible formats 
        %   for years expressing maturities
        
  
        
    % 2.5. List of CORPORATE BONDS CURVES
    % ---------------------------------------------------------------------           
                  
    [~,RFR_Str_lists.C2D_list_corporates] = ...     
            xlsread(name_excel_file_config, 'C2D_list_corporates', 'B11:C52');
    

    % 2.6. List of PARAMETERS used throughout the coding
    % ---------------------------------------------------------------------           
                  
    [VecCol_param,~] = ...     
            xlsread(name_excel_file_config, 'Parameters', 'E5:E39');
        
        % 'xlsread' allocates columns with numeric inputs to a matrix
        %           while columns with strings are stored in a cell array
       
        
    RFR_Str_lists.Parameters.CRA_corridor_upper_limit = VecCol_param(1);
    RFR_Str_lists.Parameters.CRA_corridor_lower_limit = VecCol_param(2);
    RFR_Str_lists.Parameters.CRA_threshold_option_1 = VecCol_param(3);
    
    RFR_Str_lists.Parameters.SW_tolerance_convergence = VecCol_param(5);
    RFR_Str_lists.Parameters.SW_lower_bound_alpha = VecCol_param(6);
    RFR_Str_lists.Parameters.SW_minimum_number_rates = VecCol_param(7);
 
     
    RFR_Str_lists.Parameters.FS_recovery_rate = VecCol_param(10);
    RFR_Str_lists.Parameters.Veccol_CoD_spreads_CQS = VecCol_param(12:18);
    RFR_Str_lists.Parameters.CoD_average_duration = VecCol_param(20);
    
    RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_EEA = VecCol_param(22);
    RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_non_EEA = VecCol_param(23);
    RFR_Str_lists.Parameters.FS_percent_LTAS_Corps = VecCol_param(24);

    RFR_Str_lists.Parameters.k_factor_corps_spreads = VecCol_param(28);    
    
    RFR_Str_lists.Parameters.IRR_guess_rate = VecCol_param(30);    
    RFR_Str_lists.Parameters.IRR_number_iterations = VecCol_param(31);    
    
    RFR_Str_lists.Parameters.VA_percentage_RCS = VecCol_param(33);

    RFR_Str_lists.Parameters.nInputMaturities = VecCol_param(35);
    
    % 2.7. Connection settings for the data import
    % ---------------------------------------------------------------------           
    RFR_Str_lists.connections.BBL = jsonConfiguration.connections.bloomberg;
    
    RFR_Str_lists.connections.REF.datascopeSelect = ...
        jsonConfiguration.connections.refinitiv.datascopeSelect;
    RFR_Str_lists.connections.REF.tickHistory = ...
        jsonConfiguration.connections.refinitiv.tickHistory;
    
    RFR_Str_lists.connections.Markit = jsonConfiguration.connections.markit;

    % 2.8.  Saving on the hard disk the structures generated in this function
    %       with the values of the excel file 'RFR_excel_config.xlsx'.
    % ---------------------------------------------------------------------           
    save(RFR_config_mat_file, 'RFR_Str_lists' , '-append')
    save(RFR_config_mat_file, 'RFR_basic_ADLT_GVT', '-append')
    save(RFR_config_mat_file, 'RFR_BBG_GVT_Tickers', '-append')
    save(RFR_config_mat_file, 'RFR_REF_GVT_Tickers', '-append')
    save(RFR_config_mat_file, 'RFR_basic_ADLT_SWP', '-append')
    save(RFR_config_mat_file, 'RFR_BBG_SWP_Tickers', '-append')
    save(RFR_config_mat_file, 'RFR_REF_SWP_Tickers', '-append')
    save(RFR_config_mat_file, 'RFR_basic_DLT_LTAS_GVT', '-append')
    save(RFR_config_mat_file, 'RFR_basic_CRA_Tickers', '-append')
    save(RFR_config_mat_file, 'RFR_basic_DKK_Ticker', '-append')
    save(RFR_config_mat_file, 'RFR_basic_DKK_Duration_Ticker', '-append')
   

    info = ['Calculations of the risk-free interest rate term structures started at ' ...
                datestr(now,'dd-mm-yy HH:MM') ...
               ' using the version installed in the main folder ' main_folder];
   
    config = struct('RFR_Str_config', RFR_Str_config);
    
    RFR_log_register('04_Basic', '01_Config', 'INFO',...
                info, config);
            
    function tickers = readTickerTable(worksheet, tableRange)
        [~,~,tickers] = xlsread(name_excel_file_config, worksheet, tableRange);
        
        % The raw output of xlsread contains cells with NaN for empty cells in
        % Excel. Convert them to empty char arrays.
        idx = cellfun(@(x) isnumeric(x) && isnan(x), tickers);
        tickers(idx) = {''};
    end           
end

%PARSECONNDETAILS extracts the name-value pairs of the Connections sheet
% and converts it to a struct. The argument arr is expected to be the n x 2 
% cell array resulting of a xlsread from the associated named range of the
% connection sheet.
function connection = parseConnDetails(arr)
    for i=1:size(arr, 1)
       connection.(arr{i,1}) = arr{i,2};
    end
end