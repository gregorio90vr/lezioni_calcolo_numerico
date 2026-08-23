classdef (Abstract) IDatascopeService < IMarketDataRestService 
    %IDatascopeService abstract class for high-level API access implementations    
    methods (Access = public, Abstract)      
        getInstrumentListMembers(obj, instrumentList)
        getInstrumentListMemberCount(obj, instrumentList)
    end
end

