function [user_action] = RFR_06_Downloads_iBoxx_from_Markit(config, markitConfig, automatic)

%   =======================================================================
%%  0. Explanation of this function 
%   =======================================================================

%   Import to MatLab databases of the information stored in csv files
%   donwloaded from iBoxx FTP webpage

    %   Markit provides the information of all indices for a given date
    %   in a single file (one file per day and currency 
    %   containing information for all in each row)
    
    %   All files should be stored in a single folder, 
    %   at discretion of the user,
    %   but distributed in four subfolders NECESSARILY labelled:
    %       Euro,   Euro_HY,    GBP,    USD         

  
    
    %   OUTPUT ============================================================
    
    %   There is no output although this function produces
    %   an updated MatLab file  'Str_Corporates.mat',  
    %   changing its element    'Str_Corporates_iBoxx_Bid'
    %   by adding the new downloaded corporate yields and durations.
    %   This file is saved in the folder  02_Downloads
    
    %   'Str_Corporates_iBoxx_Bid' contains 72 2-dimensional matrices
    
    %   Rows of the matrices refer to dates, while columns refer to
    %   either yields (yield matrices) or durations (duration matrices),
    %   for the six buckets of duration Markit provides.

    %   There are as many matrices as the combination of the following
    %   features(2x3x2x7 = 72)
    %       yield and durations for each of the six buckets Markot provides
    %       three possible currencies (EUR, GBP and USD)
    %       two economic sectors: Financial and Non-financial
    %       seven credit quality steps
    
    %   The combination of this four dimensions explains 
    %   the list of matrices in element 'Str_Corporates_iBoxx_Bid'
    
    %   For a more detailed explanation refer to sub-section 12.B
    %   of EIOPA Technical Documentation (published October 27th, 2015)

    
    
%   ===================================================================================
%%  1. Loading configuration and history of basic risk-free curves and corporate curves   
%   ===================================================================================
 
    if nargin < 2
        markitConfig = struct();
        automatic = false;
    elseif nargin < 3
        automatic = false;
    end
    
    user_action = 'Continue';
    
        %   only in case of failure below the user may change the value
        %   of 'user_action'

    %   1.2. Loading to workspace the history of swap curves
    %   ----------------------------------------------------   
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'RFR_basic_curves'; 
    
        %   Name of the MatLab structure with all historical series
        %   of interest rates, government bonds included 
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));
    
    
    %   1.3. Loading to workspace corporate bonds curves
    %   ------------------------------------------------   
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;    
    file_download = 'Str_Corporates'; 
    
        %   Name of the MatLab structure with all historical series
        %   of interest rates for corporate bonds 
        %   Each serie is a 2-dimensional matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 rates observed for maturities 1 to 60
        
    load(fullfile(folder_download, file_download));
    

     
%   =======================================================================
%%  2. Reading the CONFIG information on iBoxx corporate bonds
%   =======================================================================

    %   Information on the configuration of Markit FTP and 
    %   Markit csv files is stored in excel file 'iBoxx_FTP_inventory.xlsx'
    %   Such information proceeds from Markit specifications
    folder_import = config.RFR_Str_config.folders.path_RFR_03_Import;
    iboxxFile = fullfile(folder_import, 'iBoxx_FTP_inventory.xlsx');
    
    if ~exist(iboxxFile, 'file')
        info_message = [iboxxFile ...
                ' doesn''t exist. Configuration file couldn''t be found. Aborting...'];            
                             
        RFR_log_register('01_Import', '06_Download', 'ERROR',...
            info_message, config);
        return
    end
    
    [num, txt] = xlsread(iboxxFile, 'iBoxx_FTP', 'B11:F500');
    
    
    C1C_name_RFR = txt(:,1);
        %   name of each database in MatLab file  'Str_Corporates',
        %   element  'Str_Corporates_iBoxx_Bid'
    V1C_RFR_yield = num(:,1);
        %   column where the yield of the index is stored in the 
        %   relevant element of the structure  'Str_Corporates_iBoxx_Bid' 
    V1C_RFR_duration = num(:,2);
        %   column where the duration of the index is stored in the 
        %   relevant element of the structure  'Str_Corporates_iBoxx_Bid'     
    C1C_ISIN_iBoxx = txt(:,4);
        %   ISIN TRI of each iBoxx index
           
       
        
%   =======================================================================
%%  3. User selection of the MAIN folder where files are stored
%   =======================================================================
         
    %   Explorer where the user will select the MAIN folder with 
    %   the four subfolders containing the csv files withiBoxx indices.
    %   IMPORTANT: The main folder should have four subfolders labelled
    %       Euro, Euro_HY, GBP, USD with the relevantcsv files
    %   Otherwise the process cannot be completed
    %   -------------------------------------------------------------------
    
    if isfield(markitConfig, 'dpath')
        dataPath = markitConfig.dpath;
    else
        dataPath = '';
    end
    
    if isempty(dataPath)
        [dataPath] = ...
            uigetdir(config.RFR_Str_config.folders.path_RFR_import_iBoxx, ...
                      'Select the folder containing Markit csv files to import');

                %   the default folder is identified in section 1. of function
                %       'RFR_01_basic_setting_config.m'

                %   variable  'folder_to_read'  stores 
                %       the complete path of the selected folder, or...
                %       0 if the user pressed 'Cancel' or closed the box

        drawnow

        if dataPath == 0

            info_message = 'It is necessary to identify the folder with iBoxx csv files to import. The process will be cancelled';
            msgbox(info_message, 'IMPORT Markit iBoxx data CANCELLED') 

            RFR_log_register('01_Import', 'RFR_06_Download', 'ERROR',...
                info_message, config)

            drawnow

            return
        end
    end
    
    if exist(dataPath, 'dir') ~= 7
        info_message = [dataPath ' doesn''t exist. Aborting...'];
             

        RFR_log_register('01_Import', 'RFR_06_Download', 'ERROR',...
            info_message, config)
        return
    end

        
        
%   =======================================================================
%%  4. Dates of import process aligned with dates Bloomberg Euroswapcurve
%   =======================================================================
    
    %   The benchmark is the Euroswap curve.

    %   The dates of this element in 'RFR_download_BBL_Mid.EUR_RAW_SWP_BBL'
    %   will be compared to the starting date the user introduces
    
    %   Should be more recent dates for Euroswaps 
    %   the import process will start, 
    %   otherwise the function ends without any other action
    if ~automatic
        last_date_iBoxx  = max(Str_Corporates_iBoxx_Bid.EUR_Nonfinan_0_iBoxx_yields(:,1));

        input_msg = ['Starting date of the import process (dd/mm/yyyy). Last date in iBoxx database is ',...
                            datestr(last_date_iBoxx, 'dd/mm/yyyy')];

        dlg_title = 'Starting date of import process';
        num_lines = 1;

        date_start = inputdlg(input_msg, dlg_title, num_lines, {datestr(last_date_iBoxx + 1, 'dd/mm/yyyy')});

        drawnow
    else
        date_start = datestr(markitConfig.bdate, 'dd/mm/yyyy');
    end
    
    if isempty(date_start)
        
        info_message = 'User did not introduced any starting date. Import cancelled';        
        RFR_log_register('01_Import', 'RFR_06_Download', 'ERROR',...
            info_message, config)
        
        return        
    end

    rows_new_for_iBoxx = (RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(:,1) >= datenum(date_start, 'dd/mm/yyyy'));

    
    if ~any(rows_new_for_iBoxx)

        info_message = 'No Euroswap dates for the selected starting date or onwards. Import cancelled';
        msgbox(info_message, 'IMPORT Markit iBoxx data CANCELLED') 
        
        RFR_log_register('01_Import', 'RFR_06_Download', 'ERROR', ...
            info_message, config)

        drawnow
        return
        
    else
        info_message = ['Import of Markit iBoxx. Starting date ', char(date_start)];        
        RFR_log_register('01_Import', 'RFR_06_Download', 'INFO',...
            info_message, config)
    end

    
    
    V1C_new_dates = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(rows_new_for_iBoxx,1);
    
    num_new_dates= length(V1C_new_dates);
    
        
    %   Creating structure  'Str_new_iBoxx_data' with the same elements
    %   as the database     'Str_Corporates_iBoxx_Bid'  
    %   but with empty matrices and only the new dates in the first column.
    
    %   The information of the csv files obtained via FTP will be stored
    %   in this new structure, and only at the end of the process
    %   new data will be added to the structure 'Str_Corporates_iBoxx_Bid' 
    %   and saved in the hard disk in MatLab file  'Str_Corporates.mat'
    
    M2D_download_empty = [V1C_new_dates,zeros(num_new_dates, 6)];
    
    C1C = fieldnames(Str_Corporates_iBoxx_Bid);

    for k = 1 : length(C1C)
        Str_new_iBoxx_data.(C1C{k}) = M2D_download_empty;
    end
    
    
    
%   =======================================================================
%%  5. Threefold loop to move data from csv files to MatLab structure
%   =======================================================================
    
    %   Three loops will read data from iBoxx csv files 
    
    %   Markit provides the information of all indices for a given date
    %   in a single file (one csv file per day and currency EUR-GBP-USD)
    %   Therefore three loops are necessary to read the csv files
    %       loop per folder
    %           loop per date
    %               loop per index
    
    %   Each csv file has a systematic name with a fixed first part
    %   where the currency is identifyied. The name of each file ends
    %   with the day of reference expressed in format 'yyyymmdd'

    
    %   =========================================================================
    %%  5.1. External loop. Reading sucessively subfolders Euro,Euro_HY, GPB, USD
    %   =========================================================================
    
    for k_folder = 1:4
        
        switch k_folder
            case 1
                folder_to_read = fullfile(dataPath, 'Euro'); 
            case 2
                folder_to_read = fullfile(dataPath, 'Euro_HY'); 
            case 3
                folder_to_read = fullfile(dataPath, 'GBP'); 
            case 4
                folder_to_read = fullfile(dataPath, 'USD'); 
        end

        if exist(folder_to_read, 'dir') == 0

            msg_headline = 'Import of iBoxx indices';

            msg_instructions = ...
                    {   'The process cannot find the folder'; ...
                         folder_to_read; ...
                        'and the import of iBoxx indices is cancelled.'  ; ''; ...
                        'Select whether you wish to continue or not with'; ...
                        'the following steps of the import process.'     ; '';...
                        'Be aware that while NO iBoxx index has been imported,'; ''; ...
                        'the steps of the import process previously executed will not be reverted'  ; '' };

            user_action = questdlg(msg_instructions, msg_headline, ...
                                     'Continue', 'Cancel', 'Continue');    
                    %   variable  'user_action'  stores whether the user
                    %   selected  'Continue' or 'Cancel'  or closed the box
                    %   (in this last case  'user_action'  is empty)

            if strcmp(user_action,'Cancel download') || isempty(user_action) 
                info_message = strcat('Not found folder  -', folder_to_read, '. User selected to cancel import iBoxx indices.') ; 
                RFR_log_register('01_Import', 'RFR_06_Download', 'ERROR', info_message, config)
                return  %  the coding of this function is cancelled
            else
                info_message = strcat('Couldn''t find folder ', folder_to_read, '. User selected to continue with the following folders.') ; 
                RFR_log_register('01_Import', 'RFR_06_Download', 'ERROR', info_message, config)
                continue   % rest of the loop ignored and next run started
            end   
        end


        %   progress bar is made visible to the user in order to inform
        %   the folder that is being read
        %   ---------------------------------------------------------------
        
        info_bar = waitbar(0, ...
            strcat('Import iBoxx indices. Reading csv files in folder: ', folder_to_read));

        
        folder_info = dir(folder_to_read);
        C1C_list_name_files = cell(length(folder_info), 1);
        
        for k_file = 1:length(folder_info)
            C1C_list_name_files{k_file} = folder_info(k_file).name;
        end
        
            %   now 'C1C_list_name_files' is a cell array with 
            %   the list of names in the folder of each run
        
            
    
        %   =================================================================
        %%  5.2. Intermediate loop. Reading sucessive dates in each subfolder
        %   =================================================================
            
        for k_date = 1:num_new_dates

            date_iBoxx = datestr(V1C_new_dates(k_date), 'yyyymmdd');

            %  updating the message of the waitbar  ======================= 
     
               waitbar(k_date / num_new_dates, info_bar, ...
                        strcat('Reading csv files folder: ', ...
                                folder_to_read, '. Date imported:',...
                                date_iBoxx));

            for k_file = 1:length(folder_info)
                
                test = regexp(C1C_list_name_files(k_file), date_iBoxx);

                if ~isempty(cell2mat(test))
                   name_csvfile = fullfile(folder_to_read,...
                                  C1C_list_name_files{k_file});
                   break
                else
                   name_csvfile = [];
                end
                
            end
             
             if isempty(name_csvfile)
                continue
                %   Bloomberg provides data for a given date
                %   but iBoxx does not in the folder of the run
             end
            
            % Instructions to open a file and move its content
            % to a MatLab cell array named 'C1R_csv'

            fid = fopen(name_csvfile);
                % asigning an internal identifier to the file that is going
                % to be opened in the following lines

            formatSpec = strcat(repmat('%s ', 1, 82));
                % string describing the format of the information 
                % in each column (all texts because of the heading line)
                % The hard-coded number of columns is set out 
                % by Markit csv files structure.

            C1R_csv = textscan(fid, strcat(formatSpec, ' %*[^\n]'), 'Delimiter', ',');
                %   the content of the file is now in cell array C1R_csv
                %   It is a cell array with one row and as many columns
                %   as content of the csv file read
                %   Each element C1R_csv{r,c} is in itself 
                %   a column cell array with the data iBoxx provides
                %   for a concrete date for all indices in the currency
                
                %   The meaning and different values for the inputs
                %   of function 'textscan' have been obtained
                %   from MatLab help (for example in the following webpage)
                %   http://matlab.izmiran.ru/help/techdoc/ref/textscan.html 

                
            fclose(fid);
                %   the csv file is closed 


            %  Identifying the columns with the ISIN_TRI and 
            %  the relevant yield and duration
            %  This is necessary only for first file read for each currency

            for j = 1:size(C1R_csv, 2)
                if strcmp(C1R_csv{1,j}(1), 'ISIN_TRi') || strcmp(C1R_csv{1,j}(1), 'ISIN_Tri')
                    col_ISIN_iBoxx	 = j;
                end                           
                if strcmp(C1R_csv{1,j}(1), 'Annual Yield')
                    col_iBoxx_yield	 = j;
                end            

                if strcmp(C1R_csv{1,j}(1), 'Duration')
                    col_iBoxx_duration = j;
                end 
            end

    
            %   =====================================================================
            %%  5.3. Internal. Reading sucessive ISIN in each subfolder for each date
            %   =====================================================================

            for k_ISIN = 1:size(C1C_ISIN_iBoxx)

                isin_iBoxx_run = C1C_ISIN_iBoxx(k_ISIN);

                row_index = strcmp(isin_iBoxx_run, C1R_csv{1,col_ISIN_iBoxx});

                if ~any(row_index)
                    continue
                    %   the csv files does not contain information
                    %   for the index of the run
                end

                iBoxx_yield = str2double(cell2mat(C1R_csv{1,col_iBoxx_yield}(row_index)));
                iBoxx_duration = str2double(cell2mat(C1R_csv{1,col_iBoxx_duration}(row_index)));

                if isempty(iBoxx_yield)
                    iBoxx_yield = 0;
                end

                if isempty(iBoxx_duration)
                    iBoxx_duration = 0;
                end

                num_col_yield = V1C_RFR_yield(k_ISIN);
                num_col_duration = V1C_RFR_duration(k_ISIN);

                %   See section 2. above to understand why these variables
                %   identify the relevant fields 
                
                % These instructions have been replaced by the waitbar info:
                % msg_screen = strcat(date_iBoxx, '__', num2str(k_ISIN), '__', isin_iBoxx_run);
                % display(msg_screen)

                Str_new_iBoxx_data.(strcat(C1C_name_RFR{k_ISIN},...
                  '_yields'))(k_date,num_col_yield) = iBoxx_yield;

                Str_new_iBoxx_data.(strcat(C1C_name_RFR{k_ISIN},...
                  '_durations'))(k_date,num_col_duration) = iBoxx_duration;        
            end   % for k_ISIN


        end     % for k_date

        close(info_bar);
        
        
    end     % for k_folder
        
    
    
%   =======================================================================
%%  6. Updating the structure with the historical iBoxx information
%   =======================================================================

    %   The new data stored up to now in  'Str_new_iBoxx_data' 
    %   is added to the 'Str_Corporates_iBoxx_Bid' in workspace    
    
    C1C = fieldnames(Str_Corporates_iBoxx_Bid);

    
    for k = 1:length(C1C)

        
        % Replacing or completing data with new downloaded data -----------
        M2D_existing_iBoxx_data = Str_Corporates_iBoxx_Bid.(C1C{k});
        M2D_new_iBoxx_data = Str_new_iBoxx_data.(C1C{k});
      
        
        % Removing 'Nan' cells, otherwise calculation VA will fail --------     
        M2D_existing_iBoxx_data(isnan(M2D_existing_iBoxx_data)) = 0;
        M2D_new_iBoxx_data(isnan(M2D_new_iBoxx_data)) = 0;
         
        
        %   Merging or adding the relevant rows of 
        %   the existing database and the new download
        
        for  k_date = 1:size(M2D_new_iBoxx_data, 1)
            
            rows_control = (M2D_existing_iBoxx_data(:,1) == ...
                            M2D_new_iBoxx_data(k_date,1));
            
            if sum(rows_control) == 1
                M2D_existing_iBoxx_data(rows_control,:) = ...
                               M2D_new_iBoxx_data(k_date,:);
            else
                M2D_existing_iBoxx_data = ...
                        [ M2D_existing_iBoxx_data; ... 
                          M2D_new_iBoxx_data(k_date,:)];
            end
            
        end
        
        
        %   Storing in the structure to be saved in the hard disk
        %   in the next step
        Str_Corporates_iBoxx_Bid.(C1C{k}) = M2D_existing_iBoxx_data; 
                                              
   end
    
   
        
%   =======================================================================
%%  7. Saving to hard disk
%   =======================================================================  
  save(fullfile(folder_download, 'Str_Corporates'), ...
      'Str_Corporates_iBoxx_Bid', '-append');
