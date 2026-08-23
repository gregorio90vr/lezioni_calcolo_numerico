classdef TickHistoryService < DatascopeService
    %TICKHISTORYSERVICE High-level class handling data retrieval from DSS.
    %   TickHistoryService handles the retrieval of price history data and
    %   instument list members from the DSS RESTful JSON API.
    methods (Access = public)
        function obj = TickHistoryService(varargin)
            %TICKHISTORYSERVICE Construct an instance of this class
            %   obj = TickHistoryService(session) creates an object of
            %   TickHistoryService with a DatascopeSession session supplied.
            %   obj = TickHistoryService(user, password) creates an object of
            %   TickHistoryService and instantiates automatically a
            %   corresponding DatascopeSession object, which handles the
            %   communication with the API.
            obj@DatascopeService(varargin{:});
        end

        function priceTable = getTimeSeries(obj, instrumentList, startDate, endDate,...
                fields)
            %GETTIMESERIES returns the time series of an instrument list
            %   priceTable = getTimeSeries(instrumentList, startDate, endDate, fields)
            %   returns the time series for a specified instrument list
            %   between startDate and endDate as a table.
            %   
            %   Input: - instrumentList: char vector with the name of the
            %            instrument list as saved in the TickHistory API
            %          - startDate: datetime value of the first date for
            %            which data should be downloaded
            %          - endDate: datetime value of the last date for which
            %            data should be downloaded
            %          - fields: char vector or cell-array of char vectors
            %            containing the price fields that should be
            %            downloaded (e.g. 'THT.Trade - Price')
            %
            %   Output: - priceTable: table consisting of a Date column and
            %             columns for each instrument of the instrument
            %             list. If only one field was given, the field data
            %             is given directly in the instrument column.
            %             Otherwise, each column will consist of a
            %             cell-array with data for all fields.
           
            listId = obj.getInstrumentListId(instrumentList);
            
            if iscell(fields)
                queryField = fields{1};
            else
                queryField = fields;
            end
            
            queryField = queryField(1:3);
            
            switch queryField
                case 'THT'
                    requestFields = strrep(fields, 'THT.', '');
                    requestBody = obj.createTasRequestBody(listId, requestFields,...
                                    startDate, endDate);
                case 'ETS'
                    requestFields = strrep(fields, 'ETS.', '');
                    requestBody = obj.createElektronRequestBody(listId, requestFields,...
                                    startDate, endDate);    
                otherwise
                    throw(MException('TickHistoryService:UnknownFieldPrefixException',...
                        ['The field prefix ' queryField ' is unknown.']));
            end
            
            extractionEndpoint = 'Extractions/ExtractRaw';
            response = obj.session.sendPostRequest(extractionEndpoint,...
                [], requestBody);
            
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                throw(MException('TickHistoryService:UnhandledResponseException',...
                    'Unhandled Response %s.', char(response.StatusCode)));
            end
            
            obj.saveResponse(jsonencode(response.Body.Data), 'TRTH_Notes');
            
            if ~contains(response.Body.Data.Notes, 'Processing completed successfully')
                throw(MException('TickHistoryService:UnsuccessfulProcessingException',...
                    'Data wasn''t processed successfully: %s', ...
                    char(response.Body.Data.Notes)));
            end
            
            jobId = response.Body.Data.JobId;
            
            rawEndpoint = ['Extractions/RawExtractionResults(''' jobId ''')/$value'];
            rawResponse = obj.session.sendGetRequest(rawEndpoint, [], true, true);
            
            if rawResponse.StatusCode ~= matlab.net.http.StatusCode.OK
                throw(MException('TickHistoryService:UnhandledResponseException',...
                    'Unhandled Response %s.', char(rawResponse.StatusCode)));
            end
            
            obj.saveResponse(rawResponse.Body.Data, 'TRTH_Data');
            
            switch queryField
                case 'THT'
                    priceTable = obj.convertTasCsvToTable(rawResponse.Body.Data);
                case 'ETS'
                    priceTable = obj.convertElektronCsvToTable(rawResponse.Body.Data);
            end
        end
    end
    
    methods (Access = private, Static)
        function tableData = convertElektronCsvToTable(csvData)
            %CONVERTELEKTRONCSVTOTABLE converts the CSV response to a table obj.
            %   tableData = convertElektronCsvToTable(csvData) converts the API
            %   CSV time series data object from TRTH to a table object 
            %   in tableData.
            %   In particular, we assume that in addition to the specified
            %   fields the following fields are present:
            %   'RIC', 'Trade Date'. All other fields are
            %   combined and unstacked under the corresponding RIC.
            %   tableData will therefore be a table with a datetime column
            %   Date and additional columns per RIC containing either the
            %   price data in case of one field or a cell array of the
            %   price fields.
           
           data = char(csvData);
           data = splitlines(data);
           emptyIdx = cellfun(@isempty, data);
           data(emptyIdx) = [];
           
           data = split(data, ',');
           
           if size(data, 2) > 3
               combinedData = cell(size(data, 1), 1);
               
               for row = 2:size(data, 1)
                    combinedData(row) = num2cell(str2double(data(row,3:end)));
               end
           else
               combinedData = num2cell(str2double(data(2:end,end)));
           end
           
           tableData = cell2table([cellstr(data(2:end,1:2)),combinedData],...
               'VariableNames', {'RIC','Date','Data'});
            
            % RICs to which access was denied contain empty dates and should
            % therefore be removed.
            emptyIdx = cellfun(@isempty, tableData.Date);
            tableData(emptyIdx,:) = [];
            
            % Remove special characters from RICs
            tableData.RIC = cellfun(@(x) regexprep(x, '\W', ''), tableData.RIC,...
                'UniformOutput', false);
    
            tableData.Date = datetime(tableData.Date, 'InputFormat', ...
                'yyyy/MM/dd');
            
            tableData = unstack(tableData, 'Data', 'RIC');
            tableData = sortrows(tableData, 'Date');
        end
        
        function tableData = convertTasCsvToTable(csvData)
            %CONVERTTASCSVTOTABLE converts the CSV response to a table obj.
            %   tableData = convertTasCsvToTable(csvData) converts the API
            %   CSV time series data object from TRTH to a table object 
            %   in tableData.
            %   In particular, we assume that in addition to the specified
            %   fields the following fields are present: 'IdentifierType',
            %   'Identifier', 'RIC', 'DateTime', 'Date'. All other fields are
            %   combined and unstacked under the corresponding RIC.
            %   tableData will therefore be a table with a datetime column
            %   Date and additional columns per RIC containing either the
            %   price data in case of one field or a cell array of the
            %   price fields.
            
           data = char(csvData); 
           data = splitlines(data);
           emptyIdx = cellfun(@isempty, data);
           data(emptyIdx) = [];
           
           data = split(data, ',');
           
           header = data(1,:);
           header = cellfun(@(x) regexprep(x, '\W', ''), header,...
                'UniformOutput', false);
           
           % Keep only the columns "RIC", "DateTime", "Date" and everything after 
           % the column "Type" (excluding "Date").
           [a,locb] = ismember({'RIC','DateTime','Date','Type'}, header);
           
           if sum(a) ~= 4
               throw(MException('TickHistoryService:CorruptedResponseException',...
                   'The returned raw data is corrupted.'));
           end
           
           standardData = data(2:end,locb(1:3));
           
           startFieldIdx = locb(4)+1;
           endFieldIdx = size(header, 2);
           
           dataIndices = startFieldIdx:endFieldIdx;
           dataIndices = setdiff(dataIndices, locb(3));
           
           if length(dataIndices) > 1
               combinedData = cell(size(data(:,dataIndices), 1), 1);
               
               for row = 2:size(data, 1)
                    combinedData(row) = num2cell(str2double(data(row,dataIndices)));
               end
           else
               combinedData = num2cell(str2double(data(2:end,dataIndices)));
           end
           
           tableData = cell2table([standardData,combinedData],...
               'VariableNames', {'RIC','DateTime','Date','Data'});
            
            % RICs to which access was denied contain empty dates and should
            % therefore be removed.
            emptyIdx = cellfun(@isempty, tableData.DateTime);
            tableData(emptyIdx,:) = [];
    
            % Remove rows with empty Date fields
            emptyDateIdx = cellfun(@isempty, tableData.Date);
            tableData(emptyDateIdx,:) = [];
            
            % Remove special characters from RICs
            tableData.RIC = cellfun(@(x) regexprep(x, '\W', ''), tableData.RIC,...
                'UniformOutput', false);
            
            tableData.DateTime = datetime(tableData.DateTime, 'InputFormat', ...
                'yyyy-MM-dd''T''HH:mm:ss.SSSSSSSSSX', 'TimeZone',  'UTC');

            groups = findgroups(tableData.RIC, tableData.Date);
            
            selectLast = @(x) x{:,end};
            func = @(dt, data) selectLast(topkrows(table(dt, data), 1)); 
            
            lastData = splitapply(func, tableData.DateTime, tableData.Data, groups);
            
            tableData.Data = lastData(groups);
            tableData.DateTime = [];
            tableData = unique(tableData(:,{'RIC','Date','Data'}));
           
            tableData = unstack(tableData, 'Data', 'RIC');
            tableData = sortrows(tableData, 'Date');
        end
    end
    
    methods (Access = private, Static)
        function body = createElektronRequestBody(listId, fields, startDate, endDate)
            %CREATEELEKTRONREQUESTBODY TickHistory request body
            % body = createElektronRequestBody(listId, fields, startDate,
            %   endDate) returns the JSON encoded extraction request in
            %   body for an instrument list with the instrument list id
            %   listId, the pricing fields and a date range between
            %   startDate and endDate (inclusive).
            extractionRequest = containers.Map('UniformValues', false);
            extractionRequest('@odata.type') = ...
                '#ThomsonReuters.Dss.Api.Extractions.ExtractionRequests.ElektronTimeseriesExtractionRequest';
            extractionRequest('ContentFieldNames') = [{'RIC','Trade Date'},fields];
            extractionRequest('IdentifierList') = ...
                containers.Map({'@odata.type','InstrumentListId'},...
                {'#ThomsonReuters.Dss.Api.Extractions.ExtractionRequests.InstrumentListIdentifierList',...
                listId});
            
            queryStartDate = datestr(startDate, 'yyyy-mm-ddT00:00:00.000Z');
            queryEndDate = datestr(endDate, 'yyyy-mm-ddT23:59:59.999Z');
            
            extractionRequest('Condition') = ...
                containers.Map({'ReportDateRangeType','QueryStartDate','QueryEndDate'},...
                {'Range',queryStartDate,queryEndDate});
                
            body = containers.Map('ExtractionRequest', extractionRequest);
            body = jsonencode(body);
        end
        
        function body = createTasRequestBody(listId, fields, startDate, endDate)
            %CREATETASREQUESTBODY TickHistory request body
            % body = createTasRequestBody(listId, fields, startDate,
            %   endDate) returns the JSON encoded extraction request in
            %   body for an instrument list with the instrument list id
            %   listId, the pricing fields and a date range between
            %   startDate and endDate (inclusive).
            extractionRequest = containers.Map('UniformValues', false);
            extractionRequest('@odata.type') = ...
                '#ThomsonReuters.Dss.Api.Extractions.ExtractionRequests.TickHistoryTimeAndSalesExtractionRequest';
            extractionRequest('ContentFieldNames') = [cellstr('Trade - Date'),fields];
            extractionRequest('IdentifierList') = ...
                containers.Map({'@odata.type','InstrumentListId'},...
                {'#ThomsonReuters.Dss.Api.Extractions.ExtractionRequests.InstrumentListIdentifierList',...
                listId});
            
            queryStartDate = datestr(startDate, 'yyyy-mm-ddT00:00:00.000Z');
            queryEndDate = datestr(endDate, 'yyyy-mm-ddT23:59:59.999Z');
            
            extractionRequest('Condition') = ...
                containers.Map({'ReportDateRangeType','QueryStartDate',...
                'QueryEndDate','DisplaySourceRIC'},...
                {'Range',queryStartDate,queryEndDate,true});
                
            body = containers.Map('ExtractionRequest', extractionRequest);
            body = jsonencode(body);
        end
    end
end