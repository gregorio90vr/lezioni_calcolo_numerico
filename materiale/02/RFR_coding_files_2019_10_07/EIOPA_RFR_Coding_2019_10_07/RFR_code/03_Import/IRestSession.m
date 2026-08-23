classdef (Abstract) IRestSession < handle
%IRESTSESSION Interface representing the session with a RESTful API
%   This abstract class defines the interface to a RESTful API with a
%   base URL and request methods.    
    methods (Access = public, Abstract)        
        sendPostRequest(obj, endpoint, header, body)
        sendGetRequest(obj, endpoint, header)
    end
end

