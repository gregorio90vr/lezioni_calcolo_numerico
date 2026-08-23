function [numericArray,textArray] = parse_data(data)
% PARSE_DATA parse data from raw cell array into a numeric array and a text
% cell array.
% [numericArray,textArray] = parse_data(data)
% Input:
%        data: cell array containing data from spreadsheet
% Return:
%        numericArray: double array containing numbers from spreadsheet
%        textArray: cell string array containing text from spreadsheet
%==========================================================================

% ensure data is in cell array
if ischar(data)
    data = cellstr(data);
elseif isnumeric(data)
    data = num2cell(data);
end

% Check if raw data is empty
if isempty(data)
    % Abort when all data cells are empty.
    textArray = {};
    numericArray = [];
    return
else
    % Trim empty leading and trailing rows
    % find empty cells
    emptycells = cellfun('isempty',data);
    nrows = size(emptycells,1);
    firstrow = 1;
    % find last of leading empty rows
    while (firstrow<=nrows && all(emptycells(firstrow,:)))
         firstrow = firstrow+1;
    end
    % remove leading empty rows
    data = data(firstrow:end,:);
    
    % find start of trailing empty rows
    nrows = size(emptycells,1);
    lastrow = nrows;
    while (lastrow>0 && all(emptycells(lastrow,:)))
        lastrow = lastrow-1;
    end
    % remove trailing empty rows
    data = data(1:lastrow,:);
    
    % find start of trailing NaN rows
    warning('off', 'MATLAB:nonIntegerTruncatedInConversionToChar');
    while (lastrow>0 && all(isnan([data{lastrow,:}])))
        lastrow = lastrow-1;
    end
    warning('on', 'MATLAB:nonIntegerTruncatedInConversionToChar');
    % remove trailing NaN rows    
    data=data(1:lastrow,:);
    
    [n,m] = size(data);
    textArray = cell(size(data));
    textArray(:) = {''};
end

vIsNaN = false(n,m);

% find non-numeric entries in data cell array
vIsText = cellfun('isclass',data,'char');
vIsNaN = cellfun('isempty',data)|strcmpi(data,'nan')|cellfun('isclass',data,'char');

% place text cells in text array
if any(vIsText(:))
    textArray(vIsText) = data(vIsText);
else
    textArray = {};
end
% Excel returns COM errors when it has a #N/A field.
textArray = strrep(textArray,'ActiveX VT_ERROR: ','#N/A');

% place NaN in empty numeric cells
if any(vIsNaN(:))
    data(vIsNaN)={NaN};
end

% extract numeric data
numericArray = reshape(cat(1,data{:}),n,m);       

% trim all-NaN leading rows and columns from numeric array
% trim all-empty trailing rows and columns from text arrays
[numericArray,textArray]=trim_arrays(numericArray,textArray);

% ensure numericArray is 0x0 empty.
if isempty(numericArray)
    numericArray = [];
end

