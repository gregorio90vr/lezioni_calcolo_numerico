function xlswrite_fig(file,data,sheet,range,volumen,relacion)

if nargin==4
    relacion=0.75; volumen=400;
elseif nargin==5
    relacion=0.75
end    

% Set default values.
Sheet1 = 1;

if nargin < 3
    sheet = Sheet1;
    range = '';
elseif nargin < 4
    range = '';
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

    [nfil,ncol]=size(data);
    % Asignamos la hoja si es que no se ha asignado.
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
    error('MATLAB:xlswrite:NoCOMServer',...
        ['Could not start Excel server for export.\n' ...
        'XLSWRITE attempts to file in CSV format.']);
end
%------------------------------------------------------------------------------
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
    if ~exist(file,'file');
        % Create new workbook.
        ExcelWorkbook = Excel.workbooks.Add;
    else
        % Open workbook.
        ExcelWorkbook = Excel.workbooks.Open(file);
    end

 for i=1:nfil   
     
     
    try % select region.
        % Activate indicated worksheet.
        message = activate_sheet(Excel,sheet{i,1});

        % Select range in worksheet.
        Select(Range(Excel,sprintf('%s',range{i,1})));
        
        ancho=get(Excel.selection,'width');
        alto=get(Excel.selection,'height');

    catch % Throw data range error.
        error('MATLAB:xlswrite:SelectDataRange',lasterr);
    end


Select(Range(Excel,sprintf('%s',['A1:' range{i,1}])));
posic_h=get(Excel.selection,'width')-ancho;
posic_v=get(Excel.selection,'height')-alto;

Shapes=Excel.Activesheet.Shapes;

invoke(Shapes,'Addpicture',A{i,1},0,1,posic_h,posic_v,volumen,volumen*relacion);

 end
    if ~exist(file,'file') % invoke saveAs dialogue;
        ExcelWorkbook.SaveAs(file,1); % save as Excel Workbook;
    else % replace existing file.
        ExcelWorkbook.Save;
    end

    ExcelWorkbook.Close(false)  % Close Excel workbook.

catch
    try
        ExcelWorkbook.Close(false);    % Close Excel workbook.
    end
    delete(Excel);                 % Terminate Excel server.
    if nargout == 0
        rethrow(lasterror);  	   % Display last error.
    else
        success = false;
        message = lasterror;       % Return last error.
    end
end

