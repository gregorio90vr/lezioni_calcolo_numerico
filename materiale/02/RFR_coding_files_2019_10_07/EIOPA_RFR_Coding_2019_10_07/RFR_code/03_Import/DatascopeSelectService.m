classdef DatascopeSelectService < DatascopeService
    %DATASCOPESELECTSERVICE High-level class handling data retrieval from DSS.
    %   DatascopeSelectService handles the retrieval of price history data and
    %   instument list members from the DSS RESTful JSON API.
    methods (Access = public)
        function obj = DatascopeSelectService(varargin)
            %DATASCOPESELECTSERVICE Construct an instance of this class
            %   obj = DatascopeSelectService(session) creates an object of
            %   DatascopeSelectService with a DatascopeSession session supplied.
            %   obj = DatascopeSelectService(user, password) creates an object of
            %   DatascopeSelectService and instantiates automatically a
            %   corresponding DatascopeSession object, which handles the
            %   communication with the API.
            obj@DatascopeService(varargin{:});
        end

        function priceTable = getTimeSeries(obj, instrumentList, startDate, endDate,...
                fields)
            %GETTIMESERIES returns the price history of an instrument list
            %   result = getPriceHistory(instrumentList, startDate, endDate, fields)
            %   returns the price history for a specified instrument list
            %   between startDate and endDate as a table.
            %   
            %   Input: - instrumentList: char vector with the name of the
            %            instrument list as saved in the DatascopeSelect API
            %          - startDate: datetime value of the first date for
            %            which data should be downloaded
            %          - endDate: datetime value of the last date for which
            %            data should be downloaded
            %          - fields: char vector or cell-array of char vectors
            %            containing the price fields that should be
            %            downloaded (e.g. 'Universal Close Price')
            %
            %   Output: - priceTable: table consisting of a Date column and
            %             columns for each instrument of the instrument
            %             list. If only one field was given, the field data
            %             is given directly in the instrument column.
            %             Otherwise, each column will consist of a
            %             cell-array with data for all fields.
           
            listId = obj.getInstrumentListId(instrumentList);
            
            requestBody = obj.createExtractionRequestBody(listId, fields,...
                startDate, endDate);

            extractionEndpoint = 'Extractions/ExtractWithNotes';
            response = obj.session.sendPostRequest(extractionEndpoint,...
                [], requestBody);
            
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                throw(MException('DatascopeSelectService:UnhandledResponseException',...
                    'Unhandled Response %s.', char(response.StatusCode)));
            end
            
            obj.saveResponse(jsonencode(response.Body.Data), 'DSS_Data');
            
            priceTable = obj.convertJsonToTable(response.Body.Data);
        end
    end
    
    methods (Access = private, Static)
        function tableData = convertJsonToTable(jsonData)
            %CONVERTJSONTOTABLE converts the JSON response to a table obj.
            %   tableData = convertJsonToTable(jsonData) converts the API
            %   JSON price history data object from DSS to a table object 
            %   in tableData.
            %   In particular, we assume that in addition to the specified
            %   fields the following fields are present: 'IdentifierType',
            %   'Identifier', 'RIC', 'TradeDate'. All other fields are
            %   combined and unstacked under the corresponding RIC.
            %   tableData will therefore be a table with a datetime column
            %   Date and additional columns per RIC containing either the
            %   price data in case of one field or a cell array of the
            %   price fields.
            
            % Identify the price fields and combine them
            fieldData = jsonData.Contents;
            fieldData = rmfield(fieldData, {'IdentifierType','Identifier',...
                'RIC','TradeDate'});
            
            identifiers = fieldnames(fieldData);
            
            % JSON null will be decoded to []. Replace [] by nan.
            for i = 1:length(fieldData)
                for j = 1:length(identifiers)
                    if isempty(fieldData(i).(identifiers{j}))
                        fieldData(i).(identifiers{j}) = nan;
                    end
                end
            end
            
            if length(identifiers) > 1
               combinedData = struct2cell(fieldData);
               combinedData = combinedData.';
            else
               combinedData = num2cell([fieldData.(identifiers{1})]);
            end
            
            % Create a table with RICs as columns and the trade dates as
            % rows. At the same time, remove special characters from the
            % RICs.
            finalData = jsonData.Contents;
            allFields = fieldnames(finalData);
            
            [a,~] = ismember(allFields, {'RIC','TradeDate'});
            finalData = rmfield(finalData, allFields(~a));
            finalData = struct2cell(finalData);
            
            finalData(1,:) = cellfun(@(x) regexprep(x, '\W', ''), finalData(1,:),...
                'UniformOutput', false);
            
            finalData = [finalData',combinedData'];   
            
            tableData = cell2table(finalData, 'VariableNames', ...
                {'RIC','Date', 'Data'});
            
            % RICs to which access was denied contain empty dates and should
            % therefore be removed.
            emptyIdx = cellfun(@isempty, tableData.Date);
            tableData(emptyIdx,:) = [];
    
            tableData.Date = datetime(tableData.Date);
            
            tableData = unstack(tableData, 'Data', 'RIC');
            tableData = sortrows(tableData, 'Date');
        end

        function body = createExtractionRequestBody(listId, fields, startDate, endDate)
            %CREATEEXTRACTIONREQUESTBODY price history request body
            % body = createExtractionRequestBody(listId, fields, startDate,
            %   endDate) returns the JSON encoded extraction request in
            %   body for an instrument list with the instrument list id
            %   listId, the pricing fields and a date range between
            %   startDate and endDate (inclusive).
            extractionRequest = containers.Map('UniformValues', false);
            extractionRequest('@odata.type') = ...
                '#ThomsonReuters.Dss.Api.Extractions.ExtractionRequests.PriceHistoryExtractionRequest';
            extractionRequest('ContentFieldNames') = [{'RIC','Trade Date'},fields];
            extractionRequest('IdentifierList') = ...
                containers.Map({'@odata.type','InstrumentListId'},...
                {'#ThomsonReuters.Dss.Api.Extractions.ExtractionRequests.InstrumentListIdentifierList',...
                listId});
            
            queryStartDate = datestr(startDate, 'yyyy-mm-ddT00:00:00.000Z');
            queryEndDate = datestr(endDate, 'yyyy-mm-ddT23:59:59.999Z');
            
            extractionRequest('Condition') = ...
                containers.Map({'QueryStartDate','QueryEndDate'},...
                {queryStartDate,queryEndDate});
                
            body = containers.Map('ExtractionRequest', extractionRequest);
            body = jsonencode(body);
        end
    end
end