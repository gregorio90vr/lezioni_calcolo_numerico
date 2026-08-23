function rates = RFR_02D_Downloads_SWP_GVT_REF(instrument, refSettings, config)
%RFR_02D_DOWNLOADS_SWP_GVT_REF downloads and transforms SWP/GVT data from DSS
% The RFR_02D_DOWNLOADS_SWP_GVT_REF function downloads swap and government 
% bond data from Refinitiv's DSS API and transforms it into the numerical
% array format needed for the RFR_02A_DOWNLOADS_SWP_GVT function.
%
% M3D_rates_download = RFR_02D_Downloads_SWP_GVT_REF(instrument, dssSettings, config)
% creates a numerical 3d array containing for each currency/country a 2d
% array with datenums in the first column and the price data for maturities
% 1 to 60 in the other columns.
% 
% Input: - instrument: enumeration of type Instruments
%        - refSettings: struct containing a DatascopeSelectService object in
%                    refSettings.dssService and a TickHistoryService object
%                    in refSettings.trthService
%        - config: the main config struct
%
% Output: - rates: 3d numerical array with panels for all
%                  currencies/countries sorted as in
%                  config.RFR_Str_lists.C2D_list_curncy. The first column
%                  of each panel consists of datenums (or zeros if no data
%                  was available) and the other columns contain the pricing
%                  data. For legacy reasons, unavailable data is returned 
%                  as 0 (instead of nan).
%                  
    colISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166; 
    nTenors = config.RFR_Str_lists.Parameters.nInputMaturities;

    switch instrument
        case Instruments.Swap
            dssInstrumentList = refSettings.datascopeSelect.swpInstrumentList;
            trthInstrumentList = refSettings.tickHistory.swpInstrumentList;
            ricTable = config.RFR_REF_SWP_Tickers;
            priceField = 'Mid Price';
        case Instruments.GovernmentBond
            dssInstrumentList = refSettings.datascopeSelect.gvtInstrumentList;
            dssEcbInstrumentList = refSettings.datascopeSelect.ecbInstrumentList;
            trthInstrumentList = refSettings.tickHistory.gvtInstrumentList;
            ricTable = config.RFR_REF_GVT_Tickers;
            priceField = 'Universal Close Price';
    end
    
    startDate = datetime(config.startDate, 'ConvertFrom', 'datenum');
    endDate = datetime(config.refDate, 'ConvertFrom', 'datenum');
    
    data = refSettings.dssService.getTimeSeries(dssInstrumentList, ...
        startDate, endDate, priceField);
    
    if instrument == Instruments.GovernmentBond
        ecbData = refSettings.dssService.getTimeSeries(dssEcbInstrumentList, ...
            startDate, endDate, 'Last Trade Price');

        data = outerjoin(data, ecbData, 'MergeKeys', true);
    end
    
    if refSettings.trthService.getInstrumentListMemberCount(trthInstrumentList) > 0
        trthData = refSettings.trthService.getTimeSeries(trthInstrumentList, ...
            startDate, endDate, 'ETS.Average of Bid and Ask');
        
        data = outerjoin(data, trthData, 'MergeKeys', true);
    end
    
    downloadedRics = data.Properties.VariableNames;
    
    nCurrencies = size(config.RFR_Str_lists.C2D_list_curncy, 1);
    
    % Remove non workdays
    data(~isbusday(data.Date, nan),:) = [];
    
    % Extend the data table in case of missing workdays
    dates = busdays(startDate, endDate, 'daily', nan);
    additionalDates = dates(~ismember(dates, data.Date));
    
    if ~isempty(additionalDates)
        additionalRows = [num2cell(additionalDates),...
            num2cell(nan(length(additionalDates), size(data(:,2:end), 2)))];

        data = [data;additionalRows];
        data = sortrows(data, 'Date');
    end
    
    dates = datenum(data.Date);
    rates = zeros(length(dates), nTenors + 1, nCurrencies);
    
    for i = 1:nCurrencies
        rics = ricTable(i,:);
            
        if all(cellfun(@(x) isempty(x), rics))
            currencyId = config.RFR_Str_lists.C2D_list_curncy{i,colISO3166};            
            msg = [currencyId,'.',char(instrument),...
                ': No tickers specified in the Excel config file. NO DATA IMPORTED'];           
                                         
            RFR_log_register('01_Import', '02D_Download', 'WARNING', ...
                msg, config);      
            continue
        end
       
        % Find the country's/currency's RICs in the RIC list of the
        % downloaded data
        rics = regexprep(rics, '\W', '');
        [ricFound, ricPos] = ismember(rics, downloadedRics);
        
        % Check if RICs were found
        if ~any(ricFound)
            currencyId = config.RFR_Str_lists.C2D_list_curncy{i,colISO3166};
            msg = [currencyId,'.',char(instrument), ...
                ': Necessary tickers weren''t downloaded. Aborting...'];            
                             
            RFR_log_register('01_Import', '02D_Download', 'WARNING',...
                msg, config);
            continue
        end
        
        tenors = find(ricFound);
        ricPos = ricPos(tenors);
        sortedRics = rics(tenors);
        
        %   Control whether no numerical data has been read 
        if all(isnan(data{:,ricPos}))  
            currencyId = config.RFR_Str_lists.C2D_list_curncy{i,colISO3166};
            msg = [currencyId,'.',char(instrument), ...
                ': No numerical data read for this case. NO DATA TO IMPORT'];            
                             
            RFR_log_register('01_Import', '02D_Download', 'WARNING',...
                msg, config)
            continue
        end

        rates(:,1,i) = dates;
        rates(:,tenors+1,i) = data{:,sortedRics};
        
        % Convert GVT continuously compounded discount factors to spot rates
        % TODO: Move the property of being continously compounded to the
        % instrument objects.
        countryName = config.RFR_Str_lists.C2D_list_curncy{i,colISO3166};
        
        if instrument == Instruments.GovernmentBond && ~strcmp(countryName(1:2), 'EU')
            rates(:,tenors+1,i) = 100 * (rates(:,tenors+1,i).^(-1./tenors)-1);
        end
    end
    
    % Convert NaN to 0 in order to be consistent with the missing data
    % convention used so far.
    rates(isnan(rates)) = 0;
end