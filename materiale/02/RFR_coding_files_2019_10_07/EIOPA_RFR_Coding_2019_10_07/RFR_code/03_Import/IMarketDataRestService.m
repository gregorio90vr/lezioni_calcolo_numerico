classdef (Abstract) IMarketDataRestService < handle
    %IMARKETDATARESTSERVICE Interface for high-level API access implementations   
    methods (Access = public, Abstract)      
        getTimeSeries(obj, instrumentList, startDate, endDate, fields)
    end
end

