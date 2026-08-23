function RFR_02A_Downloads_SWP_GVT(config, curve, source, settings)

%  ------------------------------------------------------------------------
%%  1. Loading variables common to the following steps within this function
%  ------------------------------------------------------------------------

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_cont_compounding = config.RFR_Str_lists.Str_numcol_curncy.gvt_cont_compounding;
                   
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;       
    file_storage    = 'RFR_basic_curves';
        
    load(fullfile(folder_download, file_storage), 'RFR_download_BBL_Mid');   

    switch curve 
        case 'GVT'    
            name_excel_file_download = ...
                fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads,...
                'Download_basic_Govts.xlsx');

            name_fix = '_RAW_GVT_BBL';
            name_instrument = 'Government bonds';  % variable to be used in 2.C.3.
            instrument = 'GVT';
        case 'SWP'    
            name_excel_file_download = ...
                fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads,...
                'Download_basic_Swaps.xlsx');

            name_fix = '_RAW_SWP_BBL';
            name_instrument = 'Swaps';             % variable to be used in 2.C.3.
            instrument = 'SWP';
    end

    num_maturities = config.RFR_Str_lists.Parameters.nInputMaturities;

    % In case data is imported from the Excel workbooks, determine the
    % range to be read from each sheet (Currency/Country) by looking at
    % the available data in the first worksheet containing data. The
    % underlying assumption of this approach is, that all sheets
    % containing data have at least the same date column.
    switch source
        case 'XLS'
            [~,sheets] = xlsfinfo(name_excel_file_download);
            % Take the first worksheet after the "Master"-sheet to extract
            % information on the size of the range to read.
            dataSheet = sheets{find(~strcmp('Master', sheets), 1)};            
            [~,txt] = xlsread(name_excel_file_download, dataSheet, 'B11:B2000');
            range_to_read = calcexcelrange(11, 2, length(txt), 61);

            info = ['Importing ' instrument ' data from XLS.'];
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [M3D_rates_download] = RFR_02B_Downloads_SWP_GVT_reading_excel_files...
                        (name_excel_file_download, config.RFR_Str_lists, ...
                          num_maturities, curve, range_to_read, ...
                          config);
        case 'BDL'
            info = ['Importing ' instrument ' data from BBL Data License.'];
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [M3D_rates_download] = RFR_02B_Downloads_SWP_GVT_BBL...
                        (instrument, source, settings, config);
        case 'BRF'
            info = ['Importing ' instrument ' data from BBL request output files.'];
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config); 

            [M3D_rates_download] = RFR_02B_Downloads_SWP_GVT_BBL...
                        (instrument, source, settings.(instrument), config);
        case 'DSS'
            info = ['Importing ' instrument ' data from the DSS API.'];
            RFR_log_register('01_Import', 'RFR_01_Download', 'INFO', info, config);
            
            % Refactor the instrument variable to use the new Instruments
            % enumeration.
            switch instrument
                case 'GVT'
                    tempInstrument = Instruments.GovernmentBond;
                case 'SWP'
                    tempInstrument = Instruments.Swap;
            end
            
            [M3D_rates_download] = RFR_02D_Downloads_SWP_GVT_REF...
                        (tempInstrument, settings, config);           
    end

    %   3-dimensional matrix where
    %       rows    = dates downloaded
    %       columns = maturities downloaded
    %       pannel  = rates of each country/currency 
    %                 

    % Convert continuously compounded GVT rates to annual
    % compounded rates
    if strcmp('GVT', curve) && ismember(source, {'BDL','BRF'})
       idxCont = config.RFR_Str_lists.C2D_list_curncy(:,col_cont_compounding);
       idxCont = [idxCont{:}];
       idxCont = logical(idxCont);

       M3D_rates_download(:,2:end,idxCont) = 100*(exp(M3D_rates_download(:,2:end,idxCont)/100)-1);
    end
        
    %  ------------------------------------------------------------------------
    %%  2.C. Inside loop. Runs to read each country/currency 
    %  ------------------------------------------------------------------------        

    for count_curncy = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1)

        %   'config.RFR_Str_lists.C2D_list_curncy'  is a
        %   2-D cell array with the list of currencies/countries and
        %   Bloomberg tickers of the three basic interest rates curves
        %   ( governments, swaps Ibor and swaps OIS)
        %   It has been previously read from the excel file
        %           ...01_Config\RFR_excel_config.xlsx
        %   when executing the function
        %           RFR_01_basic_setting_config.m


        %  ----------------------------------------------------------------
        %%  2.C.1. Inside loop. Skipping governements euro area
        %  ----------------------------------------------------------------                                    

        if ~strcmp(curve, 'GVT')  %   external loop referred to swaps Ibor 
            if strcmp(config.RFR_Str_lists.C2D_list_curncy(count_curncy, col_ISO4217), 'EUR') && ...
               ~strcmp( config.RFR_Str_lists.C2D_list_curncy(count_curncy, col_ISO3166), 'EUR')

               %    code country = euro area, but no 'EUR'

               continue   % rest loop ignored & next iteration started
            end       
        end

        % Copy the market data for the currency / country and check if
        % data was downloaded at all (0s in the date column mean that
        % there was no download).
        data_new  = M3D_rates_download(:,:,count_curncy);                  
        num_dates_new = size(M3D_rates_download, 1);

        if any(data_new(:,1) == 0)
            continue
        end

        %  ------------------------------------------------------------
        %%  2.C.2. Inside loop. Currency and Instrument code
        %  ------------------------------------------------------------      

        code_curncy = config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_ISO3166};
            %   string identifier of government / currency

        instrCode = strcat(code_curncy, name_fix);

            %   Name of the MatLab numeric 2-D matrix with the historical
            %   serie of interest rates for the currency and curve of
            %   each run (for each run of the inside loop)

        %  ------------------------------------------------------------------------------
        %%  2.C.3. Inside loop. Test whether dates downloaded exist in historical storage 
        %  ------------------------------------------------------------------------------        

        try
            data_stored = RFR_download_BBL_Mid.(instrCode);

            %   'data_stored' is a 2-D numeric matrix
            %   with the historical data already stored
            %       rows = dates of observation
            %   columns
            %       first column = dates in numeric MatLab format
            %       rest = terms of interest rates in increasing value

            rows = (1:size(data_stored, 1))';

                %   'rows' = column vector of consecutive numbers
                %            ( 1 , 2 , 3, ...) with so many rows as
                %            rows of the historical data serie

                %   This vector will change its value to 'zero'
                %   when a date existing in the historical serie
                %   exists as well in the new data downloaded
                %   from Bloomberg.

                %   The procedure is to replace old data with
                %   most recent data (those of the matrix 'data_new')
                %   In this manner all matrices remain EQUALLY SIZED

            for count_datesnew = 1:num_dates_new
                control = find(data_stored(:,1) == ...
                                data_new(count_datesnew, 1), 1);

                if ~isempty(control) 
                    rows(control) = 0;
                end
            end

            rows_to_keep = rows(rows > 0);

            data_stored = data_stored(rows_to_keep,:);

        %  ------------------------------------------------------------------------------
        %%  2.C.4. Inside loop. Merging historical data (not duplicated) and new data
        %  ------------------------------------------------------------------------------        

            data_stored = [data_stored;data_new];
            data_stored = sortrows(data_stored, 1);

            RFR_download_BBL_Mid.(instrCode) = data_stored;

                %   This instruction gives appropriate name
                %   according to the currency and curve of the run
                %   to the 2-D matrix with interest rates merged
                %   (old data - dates duplicated + new data)

        catch

            %   this catch only should be activated 
            %   when the first instruction of the 'try' fails
            %   i.e. there is no previous curves for that currency
            %   (rest of instructions within the 'try' should not fail)

            data_new  = M3D_rates_download(:,:,count_curncy);

            if sum(data_new(:,1)) == 0 || ...             % no dates in downloaded market data
                 sum(sum(data_new(:,2:end))) == 0  % no interest rates in downloaded market data

                 info_message = [code_curncy, '.', name_instrument, ' ---> ', ... 
                       'No market data available. NO IMPORT OF THIS CASE'];

                 RFR_log_register('01_Import', '02A_Download', 'WARNING', info_message, config)
                 continue

                    % theoretically the code arrives here only where
                    % there was no data stored and
                    % there are no new data
                    %   Hence it lacks sense to store nothing
            else
                    % theoretically the code arrives here only if
                    % there was no data stored BUT
                    % there are new data

                    %   Hence, new data are stored and 
                    %   rows for previous dates filled in with zeros
                    %   (except first column, filled in with the
                    %   relevant dates)

%                 num_data_lost = num_dates_stored - size(data_new, 1);
% 
%                 data_lost = [VecCol_dates_stored(1:num_data_lost) ...
%                               zeros(num_data_lost, num_maturities)];
% 
%                 data_new = [data_lost;data_new]; 

                % Register the event in the log of events
                info = [code_curncy, '.', name_instrument, ' ---> ' , ... 
                       'No previous data found. Lost data has been restored at the top of ' , ...
                       instrCode];

                RFR_log_register('01_Import', 'RFR_02A_Downloads_SWP_GVT', 'WARNING', info, config);                   

            end

            data_new = sortrows(data_new, 1);
            RFR_download_BBL_Mid.(instrCode) = data_new;

                %   This instruction gives appropriate name
                %   according to the currency and curve of the run
                %   to the 2-D matrix with interest rates

        end
    end

    save(fullfile(folder_download, file_storage), ...
        'RFR_download_BBL_Mid', '-append')
    
    if ismember(source, {'BDL','BRF','DSS'})
        % Write imported data to an Excel workbook for validation purposes
        
        % Find a currency/country for which data was imported
        selection = find(M3D_rates_download(1,1,:) ~= 0, 1);

        if ~isempty(selection)
            writeImportDataToExcel(config, M3D_rates_download(1,1,selection), ...
                M3D_rates_download(end,1,selection), instrument);
        end
    end
end