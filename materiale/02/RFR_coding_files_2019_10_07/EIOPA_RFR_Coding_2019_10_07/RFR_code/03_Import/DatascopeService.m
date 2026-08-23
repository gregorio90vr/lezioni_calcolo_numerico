classdef DatascopeService < IDatascopeService
    %DATASCOPESERVICE High-level class handling data retrieval from DSS.
    %   DatascopeService handles the retrieval of price history data and
    %   instument list members from the DSS RESTful JSON API.
    properties (Access = protected)
        session
        responseDirectory = ''
    end
    
    methods (Access = public)
        function obj = DatascopeService(varargin)
            %DATASCOPESERVICE Construct an instance of this class
            %   obj = DatascopeService(session) creates an object of
            %   DatascopeService with a DatascopeSession session supplied.
            %   obj = DatascopeService(user, password) creates an object of
            %   DatascopeService and instantiates automatically a
            %   corresponding DatascopeSession object, which handles the
            %   communication with the API.
            %   obj = DatascopeService(user, password, responseDirectory)
            %   also stores data of ResponseMessage objects in the
            %   specified directory.
            if nargin == 1
               obj.session = varargin{1};
            elseif nargin >= 2
               obj.session = DatascopeSession(varargin{1}, varargin{2});
            	
               if nargin >= 3
                 obj.responseDirectory = varargin{3};
               end
            else
                error('Input arguments don''t match any constructor.');
            end

        end
        
        function members = getInstrumentListMembers(obj, instrumentList)
            %GETINSTRUMENTLISTMEMBERS returns the members of an instr.list
            %   members = getInstrumentListMembers(obj, instrumentList)
            %   returns a cell-array with the members of the specified
            %   instrumentList.
            
            listId = obj.getInstrumentListId(instrumentList);
            
            memberEndpoint = ['Extractions/InstrumentLists(''' listId ...
                ''')/ThomsonReuters.Dss.Api.Extractions.InstrumentListGetAllInstruments'];
            
            memberResponse = obj.session.sendGetRequest(memberEndpoint, []);
            
            if memberResponse.StatusCode ~= matlab.net.http.StatusCode.OK
                throw(MException('DatascopeService:UnhandledResponseException',...
                    'Unhandled Response %s.', char(memberResponse.StatusCode)));
            end
            
            % Return only the identifier information of the instrument list
            % members.
            members = arrayfun(@(x) x.Identifier, memberResponse.Body.Data.value, ...
                'UniformOutput', false);
            members = members.';
           
        end
        
        function count = getInstrumentListMemberCount(obj, instrumentList)
            %GETINSTRUMENTLISTMEMBERCOUNT returns the count of members of an instr.list
            %   count = getInstrumentListMemberCount(obj, instrumentList)
            %   returns a double with the count of members of the specified
            %   instrumentList.
            
            idEndpoint = ['Extractions/InstrumentListGetByName(ListName=''' ...
                instrumentList ''')'];
            idResponse = obj.session.sendGetRequest(idEndpoint, []);
            
            if idResponse.StatusCode == matlab.net.http.StatusCode.NotFound
                throw(MException('DatascopeService:UnknownInstrumentListException',...
                    'Instrument list with the name ''%s'' not found.', instrumentList));
            elseif idResponse.StatusCode ~= matlab.net.http.StatusCode.OK
                throw(MException('DatascopeService:UnhandledResponseException',...
                    'Unhandled Response %s.', char(idResponse.StatusCode)));
            end
            
            count = idResponse.Body.Data.Count;           
        end       
    end

    methods (Access = protected)
        function listId = getInstrumentListId(obj, listName)
            %GETINSTRUMENTLISTID returns the ID for an instrument list name
            % listId = getInstrumentListId(obj, listName) retrieves the
            % listId for an instrument list name (listName) from the DSS
            % API. This id is necessary for getting the members of an
            % instrument list or for pricing the members of an instrument
            % list.
            idEndpoint = ['Extractions/InstrumentListGetByName(ListName=''' ...
                listName ''')'];
            idResponse = obj.session.sendGetRequest(idEndpoint, []);
            
            if idResponse.StatusCode == matlab.net.http.StatusCode.NotFound
                throw(MException('DatascopeService:UnknownInstrumentListException',...
                    'Instrument list with the name ''%s'' not found.', listName));
            elseif idResponse.StatusCode ~= matlab.net.http.StatusCode.OK
                throw(MException('DatascopeService:UnhandledResponseException',...
                    'Unhandled Response %s.', char(idResponse.StatusCode)));
            end
            
            listId = idResponse.Body.Data.ListId;
        end
        
        function saveResponse(obj, data, prefix)
            if ~isempty(obj.responseDirectory)
                newFile = fullfile(obj.responseDirectory, [prefix '_' ...
                    strrep(char(java.util.UUID.randomUUID),'-','_') '.txt']);
                
                fid = fopen(newFile, 'w');
                fprintf(fid, '%s', data);
                fclose(fid);
            end
        end
    end
end