function [newDates,craRates] = ...
    RFR_01A_Downloads_CRA_REF(config, refSettings)
%RFR_01A_DOWNLOADS_CRA_REF downloads and transforms CRA data from DSS
% The RFR_01A_DOWNLOADS_CRA_REF function downloads IBOR and OIS data 
% from Refinitiv's DSS API for the CRA and transforms it into the numerical
% array format needed for the RFR_01_Downloads_CRA function.
%
% [newDates,craRates] = RFR_01A_Downloads_CRA_REF(config, dssSettings)
% creates a numerical 3d array containing for each currency/country a
% timeseries of the IBOR rates (panel 1) and OIS rates (panel 2) as
% specified in the Excel config file.
% 
% Input:  - config: the main config struct
%         - refSettings: struct containing a DatascopeService object in
%                    refSettings.dssService        
%
% Output: - newDates: datenum vector containing all dates for which data
%                  was available in the download 
%         - craRates: 3d numerical array with a panel for IBOR and another
%                  panel for OIS rates.
%                  The first column of each panel consists of datenums and
%                  the other columns contain the IBOR or OIS rates. The
%                  order of the currencies/countries follows the order in
%                  the Excel config file.
    
    colISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;        
    
    colCraIborRate = config.RFR_Str_lists.Str_numcol_curncy.CRA_REF_IBOR_rate;
    colCraOisRate = config.RFR_Str_lists.Str_numcol_curncy.CRA_REF_OIS_rate;
    
    panelRicCol = [colCraIborRate colCraOisRate];
    
    nCountries  = size(config.RFR_Str_lists.C2D_list_curncy, 1);
    nPanels = 2; % IBOR and OIS
    iborPanel = 1;
    oisPanel = 2;
    
    startDate = config.startDate;
    endDate = config.refDate;
    
    data = refSettings.dssService.getTimeSeries(refSettings.datascopeSelect.craInstrumentList,...
        startDate, endDate, 'Universal Close Price');
    
    trthInstrumentList = refSettings.tickHistory.craInstrumentList;
    
    if refSettings.trthService.getInstrumentListMemberCount(trthInstrumentList) > 0
        trthData = refSettings.trthService.getTimeSeries(trthInstrumentList, ...
            startDate, endDate, 'ETS.Average of Bid and Ask');
        
        data = outerjoin(data, trthData, 'MergeKeys', true);
    end
    
    % Remove non workdays
    data(~isbusday(data.Date, nan),:) = [];
    
    newDates = datenum(data.Date);
      
    craRates = zeros(length(newDates), nCountries + 1, nPanels);
    craRates(:,1,:) = repmat(newDates, 1, 1, nPanels);  
    
    for countryIdx = 1:nCountries                                                   
        updateCraRatesForCountry(countryIdx, iborPanel);
        updateCraRatesForCountry(countryIdx, oisPanel);
    end
    
    
    function updateCraRatesForCountry(idx, panel)
        ric = config.RFR_Str_lists.C2D_list_curncy{idx,panelRicCol(panel)};
        % Remove special characters from the RIC in order to make it 
        % compatible to MATLAB's variable names
        ric = regexprep(ric, '\W', ''); 
        
        if ~isempty(ric)
            [ricAvailable,ricPos] = ismember(ric, data.Properties.VariableNames);

            if ricAvailable
               craRates(:,idx+1,panel) = data{:,ricPos};
            else
                isoCode = config.RFR_Str_lists.C2D_list_curncy{idx,colISO3166};            
                msg = [isoCode,':',ric,...
                    ': RIC not found in the download. No data available.'];           

                RFR_log_register('01_Import', '01A_Download', 'WARNING', ...
                    msg, config);    
            end
        end    
    end
end