classdef DatascopeSession < IRestSession
    %DATASCOPESESSION Session class of the Refinitiv DSS RESTful JSON API.
    %   Implementation of the Refinitiv DSS RESTful JSON API taking care of
    %   the base URL and handling the session token. Methods for GET and 
    %   POST requests to the API are implemented.
    
    properties (Access = private)
        user
        password
        token
        sessionStart
    end
    
    properties (Access = private, Constant)
        URI = 'https://hosted.datascopeapi.reuters.com/RestApi/v1/'
        POLL_TIMEOUT = seconds(60*30);
    end
    
    methods (Access = public)
        function obj = DatascopeSession(user, password)
            %DATESCOPESESSION Construct an instance of this class
            %   Returns an instance of this class with a new session opened
            %   by requesting a token from the DSS API. User and password
            %   are the Datascope credentials.
            obj.user = user;
            obj.password = password;
            
            [obj.token,obj.sessionStart] = obj.getToken();
        end
        
        function response = sendGetRequest(obj, endpoint, header, auth, gzipped)
            %SENDGETREQUEST Send a GET request to the API and return the resp.
            % response = sendGetRequest(obj, endpoint, header, auth) sends
            % a HTTP GET request to the endpoint of the Datascope API with
            % the additional headers in the header variable. Authentication
            % with the token is taken care of, if the boolean parameter is
            % either omitted or set to true. Also, some endpoints respond
            % with gzip encoded data. As MATLAB is not correctly providing
            % the decoded data, a logical true will deactivate transparent 
            % decoding and do a file-based decoding.
            if nargin < 4
                auth = true;
                gzipped = false;
            elseif nargin < 5
                gzipped = false;
            end
            
            if auth && ~obj.isTokenValid()
                [obj.token,obj.sessionStart] = obj.getToken();
            end
            
            uri = matlab.net.URI([obj.URI endpoint]);
            
            [request,options] = obj.createGenericRequest(header, [], auth, gzipped);
            request.Method = matlab.net.http.RequestMethod.GET;
            
            response = obj.poll(request, uri, options);
            
            % If the payload is gzip encoded, decode it and store it in the
            % Body.Data part of the response. This has to be done as MATLAB
            % is only partially returning the decoded message if
            % transparent decoding is activated.
            if gzipped
                response.Body.Data = ...
                    DatascopeSession.decodeGzippedData(response.Body.Payload);
            end
        end
        
        function response = sendPostRequest(obj, endpoint, header, body, auth, gzipped)
            %SENDPOSTREQUEST Send a POST request to the API and return the response
            % response = sendPostRequest(obj, endpoint, header, auth) sends
            % a HTTP POST request to the endpoint of the Datascope API with
            % the additional headers in the header variable and the character array 
            % payload in the body variable. Authentication
            % with the token is taken care of, if the boolean parameter is
            % either omitted or set to true.
            if nargin < 5
                auth = true;
                gzipped = false;
            elseif nargin < 6
                gzipped = false;
            end
            
            if auth && ~obj.isTokenValid()
                [obj.token,obj.sessionStart] = obj.getToken();
            end
            
            uri = matlab.net.URI([obj.URI endpoint]);
            
            header = [header matlab.net.http.field.ContentTypeField(...
                'application/json')];
            
            [request,options] = obj.createGenericRequest(header, body, auth, gzipped);
            request.Method = matlab.net.http.RequestMethod.POST;
            
            response = obj.poll(request, uri, options);
            
            % If the payload is gzip encoded, decode it and store it in the
            % Body.Data part of the response. This has to be done as MATLAB
            % is only partially returning the decoded message if
            % transparent decoding is activated.
            if gzipped
                response.Body.Data = ...
                    DatascopeSession.decodeGzippedData(response.Body.Payload);
            end
        end
    end
    
    methods (Access = private)
        function valid = isTokenValid(obj)
            %ISTOKENVALID checks the validity of the token
            %   valid = isTokenValid(obj) returns true if the token exists
            %   and hasn't timed out. Otherwise, false is returned.
            
            if isempty(obj.token) || ...
                    (datetime('now', 'TimeZone', obj.sessionStart.TimeZone) - ...
                    obj.sessionStart) >= hours(24)
                valid = false;
            else
                valid = true;
            end
        end
        
        function [token,responseDatetime] = getToken(obj)
           %GETTOKEN requests a session token from the API
           % [token,responseDatetime] = getToken(obj) requests an
           % authentication token from the Datascope API and in case of
           % success, it returns the token as well as the time from which
           % on the token has been valid. This is based on Frankfurt time.
           endpoint = 'Authentication/RequestToken';
           
           body = jsonencode(struct('Credentials', ...
               struct('Username', obj.user, 'Password', obj.password)));

           response = obj.sendPostRequest(endpoint, [], body, false);
           
           if response.StatusCode == matlab.net.http.StatusCode.OK
               token = response.Body.Data.value;
               
               responseDatetime = response.getFields('Date');
               responseDatetime = datetime(responseDatetime.Value, ...
                   'InputFormat', 'eee, dd MMM yyyy HH:mm:ss z', ...
                   'TimeZone', 'Europe/Berlin');
           else
               throw(MException('DatascopeSession:AuthenticationErrorException',...
                        'Unable to authenticate. Server responded with status %s', ...
                        char(response.StatusCode)));
           end
        end
        
        function [request,options] = createGenericRequest(obj, header, body, auth, gzipped)
            %CREATEGENERICREQUEST Sets up common request properties
            % [request,options] = createGenericRequest(obj, header, body, auth) 
            % is a helper method setting up the  matlab.net.http.RequestMessage  
            % request with properties common to both a GET and a POST request. 
            % In case of auth true, the Authorization field is properly set
            % with the token of the DSS API. A header gets also the prefer 
            % field and a body is added to the request as-is. Additionally,
            % an matlab.net.http.HTTPOptions object is returned that is
            % required for the request.send method.
            
            % Set up the options (due to the proxy, we have to ignore
            % the SSL certificate)
            options = matlab.net.http.HTTPOptions('ConnectTimeout', 600, ...
                'CertificateFilename', '', 'DecodeResponse', ~gzipped);
            
            request = matlab.net.http.RequestMessage;
            
            preferField = matlab.net.http.field.GenericField('Prefer',...
                'respond-async, wait=20');
            header = [header preferField];
            
            if auth
                authField = matlab.net.http.field.AuthorizationField(...
                    'Authorization', ['Token ' obj.token]);
                header = [header authField];
            end

            request.Header = header;
            request.Body = matlab.net.http.MessageBody;
            request.Body.Payload = body;
        end
        
        function response = pollTillOK(obj, location, timeout, gzipped)
            %POLLTILLOK Poll the DSS API until 200OK (or error or timeout)
            % response = pollTillOK(location, timeout) polls the location
            % URI provided after a 202 Accepted response until a 200 OK
            % reponse is returned. In order to avoid infinite polling, a
            % timeout in seconds is set, at which point an error gets thrown.
            % Also, any HTTP status code other than 202 or 200 will result
            % in an exception.
            
            if nargin < 3
                timeout = obj.POLL_TIMEOUT;
                gzipped = false;
            elseif nargin < 4
                gzipped = false;
                timeout = seconds(timeout);
            else
                timeout = seconds(timeout);
            end
            
            pollingStarted = datetime('now');
            uri = matlab.net.URI(location);
            
            [request,options] = obj.createGenericRequest([], [], true, gzipped);
            request.Method = matlab.net.http.RequestMethod.GET;
            
            [response,~,~] = request.send(uri, options);
            
            while response.StatusCode == matlab.net.http.StatusCode.Accepted &&...
                    (datetime('now') - pollingStarted) < timeout
                 
                newLocation = response.getFields('Location');
                newLocation = newLocation.Value;

                if ~isempty(newLocation)
                    % Poll for 30 minutes
                    uri = matlab.net.URI(newLocation);
                    [response,~,~] = request.send(uri, options);
                else
                    throw(MException('DatascopeSession:MissingLocationResponse',...
                        'Status 202 with no location header received.'));
                end
            end
            
            if response.StatusCode == matlab.net.http.StatusCode.Accepted &&...
                    (datetime('now') - pollingStarted) >= timeout
                throw(MException('DatascopeSession:ConnectionTimeoutException',...
                'Request timeout.'));
            end
        end

        function response = poll(obj, request, uri, options)
            %POLL Sends a request to the API and traverses 202 responses
            % response = poll(obj, request, uri, options) sends a
            % matlab.net.http.RequestMessage to the DSS API at the 
            % matlab.net.URI together with the matlab.net.http.HTTPOptions
            % and returns the matlab.net.http.ResponseMessage. In case of a
            % 202 status response, the method tries to poll 
            [response,~,~] = request.send(uri, options);

            % Check the status code of the response and poll in case of 202
            status = response.StatusCode;
            
            if status == matlab.net.http.StatusCode.Accepted
                location = response.getFields('Location');
                location = location.Value;
                
                if ~isempty(location)
                    % Poll for 30 minutes
                    response = obj.pollTillOK(location);
                else
                    throw(MException('DatascopeSession:MissingLocationResponse',...
                        'Status 202 with no location header received.'));
                end
            end
        end
    end
    
    methods (Access = private, Static)
        function data = decodeGzippedData(gzippedData)
            tempFile = tempname;
            tempFileGzipped = [tempFile '.gz'];
            
            try
                fid = fopen(tempFileGzipped, 'w');
                fwrite(fid, gzippedData);
                fclose(fid);
                
                gunzip(tempFileGzipped);
                
                data = fileread(tempFile);
            catch
                throw(MException('DatascopeSession:GZipDecodingException',...
                    'Unable to decode the payload.'));
            end
        end
    end
end