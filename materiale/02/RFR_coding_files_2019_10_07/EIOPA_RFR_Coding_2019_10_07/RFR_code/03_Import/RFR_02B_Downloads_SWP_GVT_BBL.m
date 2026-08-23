function M3D_rates_download = RFR_02B_Downloads_SWP_GVT_BBL(instrument, ...
                           source, settings, config)

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    %   number of the column in cell array
    %   'config.RFR_Str_lists.C2D_list_curncy'  containing ISO3166 
    %   for each of the currencies / countries considered
        
    num_maturities = config.RFR_Str_lists.Parameters.nInputMaturities;
    
    % Download / import the BBL DL data
    
    % In case of 'BDL', download and decrypt the files
    if strcmp(source, 'BDL')
       settings = downloadBDLOutput(settings, settings.outputfiles.(instrument), ...
           settings.dlPath, 10); 
       settings = char(settings);
    end
    
    bblData = parseBDLHistory(bdlloader(settings), 'weekdays');

    nCurrencies = size(config.RFR_Str_lists.C2D_list_curncy, 1);
    
    V1C_dates_ref = datenum(bblData.Date);

    M3D_rates_download = zeros(length(V1C_dates_ref), ...
                                num_maturities + 1, ...
                                nCurrencies);
    
%   ======================================================================     
%   2. Loop through all currencies/countries  
%   ======================================================================
    for i = 1:nCurrencies

        if strcmp(instrument, 'GVT')
            tickers = config.RFR_BBG_GVT_Tickers(i,:);
        elseif strcmp(instrument, 'SWP')
            tickers = config.RFR_BBG_SWP_Tickers(i,:);
        elseif strcmp(instrument, 'OIS')
            % TODO: Remove in future versions
            tickers = config.RFR_basic_BBG_Tickers(i,:);
        end
        
          
        if all(cellfun(@(x) isempty(x), tickers))
            id_curncy = config.RFR_Str_lists.C2D_list_curncy{i, col_ISO3166};            
            info_message = [id_curncy,'.',instrument,...
                ': No tickers specified in the Excel config file. NO DATA IMPORTED'];           
                                         
            RFR_log_register('01_Import', '02B_Download', 'WARNING', ...
                info_message, config)
            
            continue
        end
       
        % Find the tickers in the ticker list
        tickers = strrep(tickers, ' ', '_');
        tickerNames = bblData.Properties.VariableNames;
        [tickerFound, tickerPos] = ismember(tickers, tickerNames);
        
        % Check if tickers were found
        if ~any(tickerFound)
            id_curncy = config.RFR_Str_lists.C2D_list_curncy{i, col_ISO3166};
            info_message = [id_curncy ...
                ': Necessary tickers weren''t downloaded. Aborting...'];            
                             
            RFR_log_register('01_Import', '02B_Download', 'WARNING',...
                info_message, config)

            continue
        end
        
        maturities = find(tickerFound);
        tickerPos = tickerPos(maturities);
        tickers = tickers(maturities);
        
        
        %   Control whether no numerical data has been read 
        if all(isnan(bblData{:,tickerPos}))
            
            id_curncy = config.RFR_Str_lists.C2D_list_curncy{i, col_ISO3166};
            info_message = [id_curncy ...
                ': No numerical data read for this case. NO DATA TO IMPORT'];            
                             
            RFR_log_register('01_Import', '02B_Download', 'WARNING',...
                info_message, config)

            continue
        end

        M3D_rates_download(:,1,i) = V1C_dates_ref;
        M3D_rates_download(:,maturities+1,i) = bblData{:,tickers};
        
        [nanRows,nanCols] = find(isnan(M3D_rates_download(:,:,i)));
        
        if ~isempty(nanRows)
            linNanIdx = sub2ind(size(M3D_rates_download), nanRows, nanCols, ...
                repmat(i, length(nanRows), 1));
            M3D_rates_download(linNanIdx) = 0;
        end
    end

end