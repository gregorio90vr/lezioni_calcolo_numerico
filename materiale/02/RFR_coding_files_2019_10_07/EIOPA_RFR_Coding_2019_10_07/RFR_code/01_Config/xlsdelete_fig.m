function xlsdelete_fig(file,sheet)

% Set default values.
Sheet1 = 1;

if nargin < 2
    sheet{1,1} = Sheet1;
elseif ischar(sheet)
    sheet=cellstr(sheet);    
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


    [nfil,ncol]=size(sheet);
    % Asignamos la hoja si es que no se ha asignado.
    for i=1:nfil
        if iscell(sheet(i,1))
            A(i,1)=sheet(i,1);
        else
            A(i,1)=num2cell(sheet(i,1));
        end
        if isempty(sheet(i,1))
            sheet(i,1) = Sheet1;
        end
    end
catch
    error('MATLAB:xlsdelete:NoSheets',...
        ['no hay hojas especificadas']);

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

    catch % Throw data range error.
        error('MATLAB:xlswrite:SelectDataRange',lasterr);
    end

    try
        Shapes=Excel.Activesheet.Shapes;
        nn=get(Shapes,'Count');
        
%        Selection=invoke(Shapes,'SelectAll');
        for i=1:nn
            ss=Shapes.Item(1);
            invoke(ss,'Delete');
        end
        
    catch
        warning('No se pueden borrar figuras');
    end

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

