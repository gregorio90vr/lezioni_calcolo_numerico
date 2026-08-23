function [yields,dates,durations] = ...
                    RFR_05_DKK_covered_bonds_REF(config, refSettings)
%RFR_05_DKK_COVERED_BONDS_REF downloads and transforms DKK data from TRTH
% The RFR_05_DKK_COVERED_BONDS_REF function downloads the NYKREDIT data 
% from Refinitiv's TRTH API for the DKK LTAS and CORP calculations and 
% transforms it into the numerical vector format needed for the 
% RFR_05_DKK_COVERED_BONDS function.
%
% [yields,dates,durations] = RFR_05_DKK_covered_bonds_REF(config, dssSettings)
% 
% Input:  - config: the main config struct
%         - dssSettings: struct containing a TickHistoryService object in
%                    dssSettings.trthService        
%
% Output: - yields: numerical vector containing all available yields for
%                   the NYKREDIT index corresponding to the dates in the 
%                   dates vector. Contains NaNs in case no yield was
%                   available for a certain date.
%         - dates: datenum vector containing all work days between and
%                  including config.startDate and config.refDate.
%         - durations: numerical vector containing all available durations 
%                   for the NYKREDIT index corresponding to the dates in the 
%                   dates vector. Contains NaNs in case no duration was
%                   available for a certain date.

    startDate = datetime(config.startDate, 'ConvertFrom', 'datenum');
    endDate = datetime(config.refDate, 'ConvertFrom', 'datenum');
    
    workDays = busdays(startDate, endDate, 'daily', nan);
    
    trthData = refSettings.trthService.getTimeSeries(...
        refSettings.tickHistory.dkkInstrumentList,...
        startDate, endDate, 'THT.Trade - Price');
    
    trthData(~isbusday(trthData.Date, nan),:) = [];
    
    additionalDates = workDays(~ismember(workDays, trthData.Date));
    
    if ~isempty(additionalDates)
        alignmentData = [num2cell(additionalDates) ...
            num2cell(nan(length(additionalDates), size(trthData, 2) - 1))];
        
        trthData = [trthData;alignmentData];
        trthData = sortrows(trthData);
    end
    
    dates = datenum(trthData.Date);
    yields = trthData{:,'NYKROYTM'};
    durations = trthData{:,'NYKRRYTM'};
end