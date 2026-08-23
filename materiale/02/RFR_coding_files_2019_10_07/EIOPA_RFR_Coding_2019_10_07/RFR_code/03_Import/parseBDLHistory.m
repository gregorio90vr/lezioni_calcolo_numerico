function [dataTable] = parseBDLHistory(bdlOutput, varargin)
%PARSEBDLHISTORY Parse output of the bdlloader function for gethistory into a table.
%   Detailed explanation goes here
   
    p = inputParser;
    
    defaultDates = 'output';
    validDates = {'output','weekdays'};
    checkDates = @(x) any(validatestring(x, validDates));
    
    addRequired(p, 'bdlOutput', @isstruct);
    addOptional(p, 'outDates', defaultDates, checkDates);
    
    parse(p,bdlOutput,varargin{:});
    
    dates = [];
    prices = [];
    indices = {};
    dataTable = table();

    % Parse the securities into a table (concatenation or unstacking take
    % about the same amount of time)
    for iRow=1:length(bdlOutput.Data)
        if strcmpi(bdlOutput.Data{iRow,1},'START SECURITY')
            indices{length(indices)+1} = strrep(bdlOutput.Data{iRow,2}, ...
                ' ','_');
        elseif strcmpi(bdlOutput.Data{iRow,1},'END SECURITY')
            if isempty(dates)
                if isempty(dataTable)
                    % If the first index is empty, the index gets pushed
                    % into the table by introducing a NaN on 01/01/0000.
                    % Later on, this row will be deleted.
                    dataTable = table(datetime(0,1,1),nan,'VariableNames',{'Date',...
                        indices{end}});
                else
                    dataTable.(indices{end}) = NaN(size(dataTable, 1), 1);
                end
            else
                tempTable = table(datetime(dates,'InputFormat','dd-MMM-yy',...
                    'Format','dd/MM/yyyy'),prices,'VariableNames',{'Date',...
                    indices{end}});

                if length(indices) == 1
                    dataTable = tempTable;
                else
                    dataTable = outerjoin(dataTable,tempTable,'MergeKeys',...
                        true);
                end

                prices = [];
                dates = [];
            end
        else
            dates = [dates;bdlOutput.Data{iRow,2}];
            prices = [prices;str2double(bdlOutput.Data{iRow,3})];
        end
    end

    % Remove the possible 1/1/0000 row
    dataTable(dataTable.Date == datetime(0,1,1),:) = [];
    
    % Return all and only workdays (i.e. extend the dates and remove rows
    % as necessary).
    if strcmpi(p.Results.outDates, 'weekdays')
        % Remove all weekends
        dataTable(~isbusday(dataTable.Date, NaN),:) = [];
        
        % Add all missing workdays
        minDate = min(dataTable.Date);
        maxDate = max(dataTable.Date);
        
        allDates = busdays(minDate, maxDate, 'd', NaN);
        missing = allDates(~ismember(allDates, dataTable.Date));
        
        if ~isempty(missing)
            catTable = [table(missing, 'VariableNames', {'Date'}),...
                array2table(nan(size(missing, 1), ...
                length(dataTable.Properties.VariableNames) - 1),...
                'VariableNames',dataTable.Properties.VariableNames(2:end))];
            
            dataTable = [dataTable;catTable];
        end
    end
    
    dataTable = sortrows(dataTable); 
end