

function RFR_00_DVA_main_function(main_folder)


set(0, 'DefaulttextInterpreter', 'none');
        % to avoid LaTex messages in command window
        
            
   
    message = strcat({'This process may last 10-20 minutes.'; '';...
                        'Please, confirm you wish to continue'; '' });
                   
    choice = questdlg(message, ...
                        'Descriptive Volatility Analysis(DVA)', ...
                        'Continue DVA calculation', 'Cancel the calculation', 'Continue DVA calculation');  

    drawnow


    if strcmp(choice, 'Cancel the calculation')
        return
    end

    
%%  1. Setting the folders of data, configuration and results  
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------

    RFR_config_mat_file = RFR_01_basic_setting_config(main_folder);

        %   All the folders used in this process should have 
        %       -->   a common parent folder, and
        %       -->   a specific predetermined name.
        
        %   RFR_01_basic_setting_config.m    is a simple function where
        %   the parent or 'main folder' is identified,
        %   and also the complete paths of the children folders that
        %   will be used in this application.
        
        %   All the paths are stored in  'RFR_Str_config.folders'
        %  (i.e. as an element of the MatLab structure 'RFR_Str_config')
        
        %   The structure 'RFR_Str_config' is saved in a MatLab *.mat file
        %   with other structures containing configuration details as well.
        %   The *.mat file is named  'EIOPA_RFR_config.mat'. 
        
        %   File  'EIOPA_RFR_config.mat'  should always be saved in
        %   a folder named '01_Config',   child of the main folder
        %  (e.g. if the main folfer is   'C:\EIOPA\RFR', then file
        %   'EIOPA_RFR_config.mat'  should be in 'C:\EIOPA\RFR\01_Config'
        
        %   The output of this function is a variable string named
        %   'RFR_config_mat_file'  that simply contains the complete name
        %   of the path ending in the folder  '01_Config'
        
        %   This variable will be used repeteadly in the following 
        %   because it gives access to the configuration files,
        %   which allow to access and govern all the elements of the
        %   application


    
%   =======================================================================
%%  2. Calculating the data set   
%   =======================================================================
 
    
    [ Str_vola, date_calc ] = RFR_01_DVA_main_loop(RFR_config_mat_file);     

    
        %   This function reads the market data downloaded in excel files
        %   either via Bloomberg or via Reuter

        %   The excel files used to download market data should have
        %   received such data before launching this application.
        
        %   Such excel files should have a concrete name and structure
        %   as described in this function and technical documentation.
        
        %   Excel files should be stored in a folder named  '02_Downloads'
        %   child of the main folder (e.g. if the main folder is   
        %   'C:\EIOPA\RFR'    then   the folder containing the excel files
        %   with market data should be  'C:\EIOPA\RFR\02_Downloads')
        
        %   This function does not have any output.
        %   The market data are passed from excel files to 
        %   either the structure    'RFR_download_BBL' 
        %   or the structure        'RFR_download_REU'
        %   pending on the provider of market data
        
        %   Each structure has several 2-dimensional matrices containing
        %   the historical series of interest rates curves
        %   for saps-government-OIS and for each currency considered
        
        %   Both  'RFR_download_BBL' and  'RFR_download_REU'  are saved in
        %   a MatLab file named  'RFR_basic_curves.mat'
        %   Thi file is also stored in the child folder  '02_Downloads'

                
    % 1.B. Date of calculation in format 'dd/mm/yyyy' 
    % ---------------------------------------------------------------------

    input_msg = {'Enter date of calculation for statistics. Format dd/mm/yyyy. If no exact match, nearest previous date will be calculated'};
                  
    dlg_title = 'Date of calculation';
    num_lines = 1;
    def = {'31/07/2014'};
    
    date_calc = inputdlg(input_msg, dlg_title, num_lines, def);
    date_calc = datenum(date_calc, 'dd/mm/yyyy');

    drawnow

 [  M3D_stats_bid_ask_spread ] = RFR_06A_Bid_Ask_statistics ...
                                   (RFR_config_mat_file, date_calc);
    
    
%   =======================================================================
%%  3. Statistics of DLT assessment   
%   =======================================================================

    RFR_03A_DVA_statistics(RFR_config_mat_file);
  
        %   This function calculates the statistics on DLT assessment
        
        %   Funtion  'RFR_05B_DVA_statistics_writing_excel_results.m'
        %   writes de statistics in excel file   RFR_DLT_statistics.xlsx

        %   All the results of this process saved in folder  99_Workspace
        %   file  RFR_DVA_workspace.mat
        
%   =======================================================================
%%  4. Screen with charts   
%   =======================================================================

    h = RFR_03_DVA_screen_main([], main_folder);
    uiwait(h);
