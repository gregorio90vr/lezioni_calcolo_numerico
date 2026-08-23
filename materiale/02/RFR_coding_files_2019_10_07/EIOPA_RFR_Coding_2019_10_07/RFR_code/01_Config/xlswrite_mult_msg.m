
function [success,message]= xlswrite_mult_msg(file,data,sheet,range,text_waitbar,convert)

% XLSWRITE_MULT es un desarrollo de  XLSWRITE función de Matlab
%   Escribe varios rangos en un mismo archivo
%   
%
%   INPUT:
%       file:   nombre del archivo.
%               directorio predeterminado el actual; extensión predeter. 'xls'.
%       array:  cell array de m x 1 
%       sheet:  cell array of m x 1 nombres que definen hojas o
%                                   numeros,que definen índices de hojas.
%       range:  cell array of m x 1 nombre del rango donde se escriben los
%                                   datos usando anotación de Excel 'A1'
%       convert: boolean true si se quiere cambiar de NaN a '' de +/-Inf a
%               '+/-Infinito' 
%
%
% Ver la documentación de  XLSREAD, WK1WRITE, CSVWRITE.
%

%==============================================================================
% Set default values.

Sheet1 = 1;

if nargin < 3
    sheet = Sheet1;
    range = '';
    convert=false;
    text_waitbar = 'Writing data' ;
elseif nargin < 4
    range = '';
    convert=false;
    text_waitbar = 'Writing data' ;
elseif nargin < 5
    convert=false;
    text_waitbar = 'Writing data' ;
elseif nargin < 6
    convert=false;
end

if nargout > 0
    success = true;
    message = struct('message',{''},'identifier',{''});
end

% Handle input.
try
    % handle requested Excel workbook filename.
    if ~isempty(file)
        if ~ischar(file)
            error('MATLAB:xlswrite:InputClass','Filename must be a string');
        end
        % check for wildcards in filename
        if any(findstr('*', file))
            error('MATLAB:xlswrite:FileName', 'Filename must not contain *');
        end
        [Directory,file,ext]=fileparts(file);
        if isempty(ext) % add default Excel extension;
            ext = '.xls';
        end
        file = abspath(fullfile(Directory,[file ext]));
        [a1 a2 a3] = fileattrib(file);
        if a1 && ~(a2.UserWrite == 1)
            error('MATLAB:xlswrite:FileReadOnly', 'File can not be read only.');
        end
    else % get workbook filename.
        error('MATLAB:xlswrite:EmptyFileName','Filename is empty.');
    end

    % Check for empty input data
    if isempty(data)
        error('MATLAB:xlswrite:EmptyInput','Input array is empty.');
    end

    % Check for N-D array input data
    if ndims(data)>2
        error('MATLAB:xlswrite:InputDimension',...
            'Dimension of input array cannot be higher than two.');
    end

    % Check class of input data
    if ~(iscell(data) || isnumeric(data) || ischar(data)) && ~islogical(data)
        error('MATLAB:xlswrite:InputClass',...
            'Input data must be a numeric, cell, or logical array.');
    end

    [nfil,ncol]=size(data);
    % convert input to cell array of data.
    if convert==true %No hay diferencia por ahora
        for i=1:nfil
            if iscell(data(i,1))
                A(i,1)=data(i,1);
            else
                A(i,1)=num2cell(data(i,1));
            end
        
            if isempty(sheet(i,1))
                sheet(i,1) = Sheet1;
            end
        end
    else
        for i=1:nfil
            if iscell(data(i,1))
                A(i,1)=data(i,1);
            else
                A(i,1)=num2cell(data(i,1));
            end
        
            if isempty(sheet(i,1))
                sheet(i,1) = Sheet1;
            end
        end
        
    end

catch
    if ~isempty(nargchk(2,4,nargin))
        error('MATLAB:xlswrite:InputArguments',nargchk(2,4,nargin));
    elseif nargout == 0
        rethrow(lasterror);  	   % Display last error.
    else
        success = false;
        message = lasterror;       % Return last error.
    end
    return;
end
%------------------------------------------------------------------------------
% Attempt to start Excel as ActiveX server.
try
    Excel = actxserver('Excel.Application');

catch
    warning('MATLAB:xlswrite:NoCOMServer',...
        ['Could not start Excel server for export.\n' ...
        'XLSWRITE attempts to file in CSV format.']);
    if nargout > 0
        [message.message,message.identifier] = lastwarn;
    end
    % write data as CSV file, that is, comma delimited.
    file = regexprep(file,'(\.xls)$','.csv'); % change extention to 'csv'.
    try
        dlmwrite(file,data,','); % write data.
    catch
        [last_error] = lasterror;
        erroridentifier = 'MATLAB:xlswrite:dlmwrite';
        errormessage = ['An error occurred on data export in CSV format.\n',...
            last_error.message];
        if nargout == 0
            % Throw error.
            error(erroridentifier,errormessage);
        else
            success = false;
            message.message = sprintf(errormessage);
            message.identifier = erroridentifier;
        end
    end
    return;
end
%------------------------------------------------------------------------------
barraexcel=waitbar(0,'Starting Excel','Name', text_waitbar , 'Position', [300 300 450 50] );

waitbar(0.1,barraexcel,'Analizyng data');
for i=1:nfil
    try
        % Construct range string
        if isempty(strfind(range{i,1},':'))
            % Range was partly specified or not at all. Calculate range.
            [m,n] = size(A{i,1});
            range{i,1} = calcrange(range{i,1},m,n);
        end
    catch
        if nargout == 0
            rethrow(lasterror);  	   % Display last error.
        else
            success = false;
            message = lasterror;       % Return last error.
        end
        return;
    end
end

%------------------------------------------------------------------------------
try
    waitbar(0.2,barraexcel,'Opening Excel file');
    if ~exist(file,'file');
        % Create new workbook.
        ExcelWorkbook = Excel.workbooks.Add;
    else
        % Open workbook.
        ExcelWorkbook = Excel.workbooks.Open(file);
    end

 for i=1:nfil   
    waitbar(0.2+i/nfil*(0.9-0.2),barraexcel,'Writing data');
    try % select region.
        % Activate indicated worksheet.
        message = activate_sheet(Excel,sheet{i,1});

        % Select range in worksheet.
        Select(Range(Excel,sprintf('%s',range{i,1})));

    catch % Throw data range error.
        error('MATLAB:xlswrite:SelectDataRange',lasterr);
    end

    % Export data to selected region.
    set(Excel.selection,'Value',A{i,1});
 end

    waitbar(0.95,barraexcel,'Saving data');
    if ~exist(file,'file') % invoke saveAs dialogue;
        ExcelWorkbook.SaveAs(file,1); % save as Excel Workbook;
    else % replace existing file.
        ExcelWorkbook.Save;
    end

    ExcelWorkbook.Close(false)  % Close Excel workbook.
    close(barraexcel);
        Excel.Quit;
        Excel.delete;
catch
    try
        ExcelWorkbook.Close(false);    % Close Excel workbook.
        Excel.Quit;
        Excel.delete;
    end
    delete(Excel);                 % Terminate Excel server.
    if nargout == 0
        rethrow(lasterror);  	   % Display last error.
    else
        success = false;
        message = lasterror;       % Return last error.
    end
end
%--------------------------------------------------------------------------
function message = activate_sheet(Excel,Sheet)
% Activate specified worksheet in workbook.

% Initialise worksheet object
WorkSheets = Excel.sheets;
message = struct('message',{''},'identifier',{''});

% Get name of specified worksheet from workbook
try
    TargetSheet = get(WorkSheets,'item',Sheet);
catch
    % Worksheet does not exist. Add worksheet.
    TargetSheet = addsheet(WorkSheets,Sheet);
    warning('MATLAB:xlswrite:AddSheet','Added specified worksheet.');
    if nargout > 0
        [message.message,message.identifier] = lastwarn;
    end
end

% activate worksheet
Activate(TargetSheet);
%------------------------------------------------------------------------------
function newsheet = addsheet(WorkSheets,Sheet)
% Add new worksheet, Sheet into worsheet collection, WorkSheets.

if isnumeric(Sheet)
    % iteratively add worksheet by index until number of sheets == Sheet.
    while WorkSheets.Count < Sheet
        % find last sheet in worksheet collection
        lastsheet = WorkSheets.Item(WorkSheets.Count);
        newsheet = WorkSheets.Add([],lastsheet);
    end
else
    % add worksheet by name.
    % find last sheet in worksheet collection
    lastsheet = WorkSheets.Item(WorkSheets.Count);
    newsheet = WorkSheets.Add([],lastsheet);
end
% If Sheet is a string, rename new sheet to this string.
if ischar(Sheet)
    set(newsheet,'Name',Sheet);
end

%------------------------------------------------------------------------------
function [absolutepath]=abspath(partialpath)

% parse partial path into path parts
[pathname filename ext] = fileparts(partialpath);
% no path qualification is present in partial path; assume parent is pwd, except
% when path string starts with '~' or is identical to '~'.
if isempty(pathname) && isempty(strmatch('~',partialpath))
    Directory = pwd;
elseif isempty(regexp(partialpath,'(.:|\\\\)')) && ...
        isempty(strmatch('/',partialpath)) && ...
        isempty(strmatch('~',partialpath));
    % path did not start with any of drive name, UNC path or '~'.
    Directory = [pwd,filesep,pathname];
else
    % path content present in partial path; assume relative to current directory,
    % or absolute.
    Directory = pathname;
end

% construct absulute filename
absolutepath = fullfile(Directory,[filename,ext]);
%------------------------------------------------------------------------------
function range = calcrange(range,m,n)
% Calculate full target range, in Excel A1 notation, to include array of size
% m x n

range = upper(range);
cols = isletter(range);
rows = ~cols;
% Construct first row.
if ~any(rows)
    firstrow = 1; % Default row.
else
    firstrow = str2double(range(rows)); % from range input.
end
% Construct first column.
if ~any(cols)
    firstcol = 'A'; % Default column.
else
    firstcol = range(cols); % from range input.
end
try
    lastrow = num2str(firstrow+m-1);   % Construct last row as a string.
    firstrow = num2str(firstrow);      % Convert first row to string image.
    lastcol = dec2base27(base27dec(firstcol)+n-1); % Construct last column.

    range = [firstcol firstrow ':' lastcol lastrow]; % Final range string.
catch
    error('MATLAB:xlswrite:CalculateRange',...
        'Data range must be between A1 and IV65536.');
end

%------------------------------------------------------------------------------
function s = dec2base27(d)

%   DEC2BASE27(D) returns the representation of D as a string in base 27,
%   expressed as 'A'..'Z', 'AA','AB'...'AZ', until 'IV'. Note, there is no zero
%   digit, so strictly we have hybrid base26, base27 number system.  D must be a
%   negative integer bigger than 0 and smaller than 2^52, which is the maximum
%   number of columns in an Excel worksheet.
%
%   Examples
%       dec2base(1) returns 'A'
%       dec2base(26) returns 'Z'
%       dec2base(27) returns 'AA'
%-----------------------------------------------------------------------------
b = 26;
symbols = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

d = d(:);
if d ~= floor(d) | any(d < 0) | any(d > 1/eps)
    error('MATLAB:xlswrite:Dec2BaseInput',...
        'D must be an integer, 0 <= D <= 2^52.');
end

% find the number of columns in new base
n = max(1,round(log2(max(d)+1)/log2(b)));
while any(b.^n <= d)
    n = n + 1;
end

% set b^0 column
s(:,n) = rem(d,b);
while n > 1 && any(d)
    if s(:,n) == 0
        s(:,n) = b;
    end
    if d > b
        % after the carry-over to the b^(n+1) column
        if s(:,n) == b
            % for the b^n digit at b, set b^(n+1) digit to b
            s(:,n-1) = floor(d/b)-1;
        else
            % set the b^(n+1) digit to the new value after the last carry-over.
            s(:,n-1) = rem(floor(d/b),b);
        end
    else
        s(:,n-1) = []; % remove b^(n+1) digit.
    end
    n = n - 1;
end
s = symbols(s);
%------------------------------------------------------------------------------
function d = base27dec(s)
%   BASE27DEC(S) returns the decimal of string S which represents a number in
%   base 27, expressed as 'A'..'Z', 'AA','AB'...'AZ', until 'IV'. Note, there is
%   no zero so strictly we have hybrid base26, base27 number system.
%
%   Examples
%       base27dec('A') returns 1
%       base27dec('Z') returns 26
%       base27dec('IV') returns 256
%-----------------------------------------------------------------------------

d = 0;
b = 26;
n = numel(s);
for i = n:-1:1
    d = d+(s(i)-'A'+1)*(b.^(n-i));
end
%-------------------------------------------------------------------------------
