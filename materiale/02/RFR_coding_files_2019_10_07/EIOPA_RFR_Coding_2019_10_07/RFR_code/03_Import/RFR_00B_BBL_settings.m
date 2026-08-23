function varargout = RFR_00B_BBL_settings(varargin)
% RFR_00B_BBL_SETTINGS MATLAB code for RFR_00B_BBL_settings.fig
%      RFR_00B_BBL_SETTINGS, by itself, creates a new RFR_00B_BBL_SETTINGS or raises the existing
%      singleton*.
%
%      H = RFR_00B_BBL_SETTINGS returns the handle to a new RFR_00B_BBL_SETTINGS or the handle to
%      the existing singleton*.
%
%      RFR_00B_BBL_SETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RFR_00B_BBL_SETTINGS.M with the given input arguments.
%
%      RFR_00B_BBL_SETTINGS('Property','Value',...) creates a new RFR_00B_BBL_SETTINGS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before RFR_00B_BBL_settings_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to RFR_00B_BBL_settings_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help RFR_00B_BBL_settings

% Last Modified by GUIDE v2.5 10-Jan-2018 12:57:03

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @RFR_00B_BBL_settings_OpeningFcn, ...
                       'gui_OutputFcn',  @RFR_00B_BBL_settings_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
end

% --- Executes just before RFR_00B_BBL_settings is made visible.
function RFR_00B_BBL_settings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)
% varargin   command line arguments to RFR_00B_BBL_settings (see VARARGIN)

    % Choose default command line output for RFR_00B_BBL_settings
    handles.action = '';
    handles.type = '';
    handles.output = {};
    
    handles.lastPath = 'R:\';
    
     % Update handles structure
    guidata(hObject, handles);
    
    % Get the import settings and deactivate the not used edit boxes
    if nargin>=4
      handles.importSettings = varargin{1};
      
      if nargin > 4
          config = varargin{2};
          
          set(handles.dlPathEdit, 'String', ...
              config.RFR_Str_config.folders.path_RFR_02_Downloads);
          
          connDetails = config.RFR_Str_lists.connections.BBL;
          
          set(handles.hostEdit, 'String', connDetails.server);
          set(handles.portEdit, 'String', connDetails.port);
          set(handles.userEdit, 'String', connDetails.user);
          set(handles.passwordEdit, 'String', connDetails.password);
          set(handles.decryptEdit, 'String', connDetails.decryptCode);
          
          set(handles.startDateEdit, 'String', datestr(config.startDate, 'dd/mm/yyyy'));
          set(handles.endDateEdit, 'String', datestr(config.refDate, 'dd/mm/yyyy'));
          set(handles.refDateEdit, 'String', datestr(config.refDate, 'dd/mm/yyyy'));
      end
      
      % Update handles structure
      guidata(hObject, handles);
      
      disableImportSettings(hObject, handles, 'FILE');
    end

    % UIWAIT makes RFR_00B_BBL_settings wait for hostEdit response (see UIRESUME)
    uiwait(handles.importFigure);
end

% --- Outputs from this function are returned to the command line.
function varargout = RFR_00B_BBL_settings_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

    % Get default command line output from handles structure
    if strcmp(handles.action,'')
        handles.action = 'Cancel';
    end
    
    varargout{1} = handles.action;
    varargout{2} = handles.type;
    varargout{3} = handles.output;
  
    delete(handles.importFigure);
end

function hostEdit_Callback(hObject, eventdata, handles)
% hObject    handle to hostEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of hostEdit as text
%        str2double(get(hObject,'String')) returns contents of hostEdit as a double
end

% --- Executes during object creation, after setting all properties.
function hostEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to hostEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function portEdit_Callback(hObject, eventdata, handles)
% hObject    handle to portEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of portEdit as text
%        str2double(get(hObject,'String')) returns contents of portEdit as a double
end

% --- Executes during object creation, after setting all properties.
function portEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to portEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function userEdit_Callback(hObject, eventdata, handles)
% hObject    handle to userEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of userEdit as text
%        str2double(get(hObject,'String')) returns contents of userEdit as a double
end

% --- Executes during object creation, after setting all properties.
function userEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to userEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function passwordEdit_Callback(hObject, eventdata, handles)
% hObject    handle to passwordEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of passwordEdit as text
%        str2double(get(hObject,'String')) returns contents of passwordEdit as a double
end

% --- Executes during object creation, after setting all properties.
function passwordEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to passwordEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function decryptEdit_Callback(hObject, eventdata, handles)
% hObject    handle to decryptEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of decryptEdit as text
%        str2double(get(hObject,'String')) returns contents of decryptEdit as a double
end

% --- Executes during object creation, after setting all properties.
function decryptEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to decryptEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes on button press in okButton.
function okButton_Callback(hObject, eventdata, handles)
% hObject    handle to okButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)
    handles.action = 'OK';
    
    if get(handles.fileImportButton,'Value') == 1
        handles.type = 'file';
        filenames.CRA = strtrim(get(handles.filepathCRAEdit,'String'));
        filenames.GVT = strtrim(get(handles.filepathGVTEdit,'String'));
        filenames.SWP = strtrim(get(handles.filepathSWPEdit,'String'));
        filenames.DKK = strtrim(get(handles.filepathDKKEdit,'String'));
        
        if isempty(filenames.CRA) && isempty(filenames.GVT) && ...
                isempty(filenames.SWP) && isempty(filenames.DKK)
            errMessage = sprintf(strcat('No filepath supplied.\n', ...
                'Check and retry again.'));
            uiwait(errordlg(errMessage,'Empty fields'));
            return
        end
        
        handles.output = filenames;
    else
        handles.type = 'server';
        
        host = get(handles.hostEdit,'String');
        port = get(handles.portEdit,'String');
        user = get(handles.userEdit,'String');
        password = get(handles.passwordEdit,'String');
        decrypt = get(handles.decryptEdit,'String');
        
        bdate = get(handles.startDateEdit,'String');
        edate = get(handles.endDateEdit,'String');
        refdate = get(handles.refDateEdit,'String');
    
        dlPath = strtrim(get(handles.dlPathEdit, 'String'));
        
        % Check if connection settings fields are empty
        if isempty(host) || isempty(port) || isempty(user) || ...
                isempty(password) || isempty(decrypt)
            errMessage = sprintf(strcat('All fields have to be filled in with data.\n', ...
                'Check and retry again.'));
            uiwait(errordlg(errMessage,'Empty fields'));
            
            return
        end

        % Check if the download path is empty
        if isempty(dlPath)
            errMessage = sprintf(strcat('Please enter a valid download path.\n', ...
                'Check and retry again.'));
            uiwait(errordlg(errMessage,'Empty fields'));
            
            return
        end
        
        % Validate and convert the dates
        try 
            bdate = datetime(bdate, 'InputFormat', 'dd/MM/yyyy', 'Format', ...
                'dd/MM/yyyy');
            edate = datetime(edate, 'InputFormat', 'dd/MM/yyyy', 'Format', ...
                'dd/MM/yyyy');
            refdate = datetime(refdate, 'InputFormat', 'dd/MM/yyyy', 'Format', ...
                'dd/MM/yyyy');
        catch
            errMessage = sprintf(strcat('Please enter dates in the format ''dd/mm/yyyy''!'));
            uiwait(errordlg(errMessage,'Wrong dates'));
            return
        end

        if bdate >= edate
            errMessage = sprintf(strcat('The begin date must be before the end date!'));
            uiwait(errordlg(errMessage,'Wrong dates'));
            return
        end

        handles.output = struct('host',host,'port',port,'user',user,...
            'password',password,'decrypt',decrypt,...
            'dlPath', dlPath, 'startdate', bdate, 'enddate', edate, 'refdate', refdate);
    end

    guidata(hObject,handles);

    close(handles.importFigure);
end

% --- Executes on button press in cancelButton.
function cancelButton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)
    handles.action = 'Cancel';
    
    guidata(hObject,handles);

    close(handles.importFigure);
end

function filepathCRAEdit_Callback(hObject, eventdata, handles)
% hObject    handle to filepathCRAEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filepathCRAEdit as text
%        str2double(get(hObject,'String')) returns contents of filepathCRAEdit as a double
end

% --- Executes during object creation, after setting all properties.
function filepathCRAEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filepathCRAEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes on button press in chooseCRAButton.
function chooseCRAButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseCRAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg CRA data output...');
    if filepath ~= 0
        set(handles.filepathCRAEdit,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
end

% --- Executes on button press in fileImportButton.
function fileImportButton_Callback(hObject, eventdata, handles)
% hObject    handle to fileImportButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fileImportButton

% Disable server import settings
    childrenHandles = allchild(handles.connectionSettingsPanel);
    arrayfun(@(x)set(x,'enable','off'),childrenHandles);
    
    childrenHandles = allchild(handles.datePanel);
    arrayfun(@(x)set(x,'enable','off'),childrenHandles);
    

    childrenHandles = allchild(handles.filesettingsPanel);
    arrayfun(@(x)set(x,'enable','on'),childrenHandles);
    disableImportSettings(hObject, handles, 'FILE');
end


% --- Executes on button press in serverImportButton.
function serverImportButton_Callback(hObject, eventdata, handles)
% hObject    handle to serverImportButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of serverImportButton
    childrenHandles = allchild(handles.connectionSettingsPanel);
    arrayfun(@(x)set(x,'enable','on'),childrenHandles);
    
    childrenHandles = allchild(handles.datePanel);
    arrayfun(@(x)set(x,'enable','on'),childrenHandles);
    

    childrenHandles = allchild(handles.filesettingsPanel);
    arrayfun(@(x)set(x,'enable','off'),childrenHandles);
    disableImportSettings(hObject, handles, 'SERVER');
end


function outputFileEditCRA_Callback(hObject, eventdata, handles)
% hObject    handle to outputFileEditCRA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of outputFileEditCRA as text
%        str2double(get(hObject,'String')) returns contents of outputFileEditCRA as a double
end

% --- Executes during object creation, after setting all properties.
function outputFileEditCRA_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputFileEditCRA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes when user attempts to close importFigure.
function importFigure_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to importFigure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    % Hint: delete(hObject) closes the figure
    if isequal(get(hObject, 'waitstatus'), 'waiting')
        uiresume(hObject);
    else
        delete(hObject);
    end
end


function filepathGVTEdit_Callback(hObject, eventdata, handles)
% hObject    handle to filepathGVTEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filepathGVTEdit as text
%        str2double(get(hObject,'String')) returns contents of filepathGVTEdit as a double
end

% --- Executes during object creation, after setting all properties.
function filepathGVTEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filepathGVTEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes on button press in chooseGVTButton.
function chooseGVTButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseGVTButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg GVT data output...');
    if filepath ~= 0
        set(handles.filepathGVTEdit,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
end


function filepathSWPEdit_Callback(hObject, eventdata, handles)
% hObject    handle to filepathSWPEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filepathSWPEdit as text
%        str2double(get(hObject,'String')) returns contents of filepathSWPEdit as a double
end

% --- Executes during object creation, after setting all properties.
function filepathSWPEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filepathSWPEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end

% --- Executes on button press in chooseSWPButton.
function chooseSWPButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseSWPButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg SWP data output...');
    if filepath ~= 0
        set(handles.filepathSWPEdit,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
end


function outputFileEditGVT_Callback(hObject, eventdata, handles)
% hObject    handle to outputFileEditGVT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of outputFileEditGVT as text
%        str2double(get(hObject,'String')) returns contents of outputFileEditGVT as a double
end

% --- Executes during object creation, after setting all properties.
function outputFileEditGVT_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputFileEditGVT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


function outputFileEditSWP_Callback(hObject, eventdata, handles)
% hObject    handle to outputFileEditSWP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of outputFileEditSWP as text
%        str2double(get(hObject,'String')) returns contents of outputFileEditSWP as a double
end

% --- Executes during object creation, after setting all properties.
function outputFileEditSWP_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputFileEditSWP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end



function dlPathEdit_Callback(hObject, eventdata, handles)
% hObject    handle to dlPathEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dlPathEdit as text
%        str2double(get(hObject,'String')) returns contents of dlPathEdit as a double
end

% --- Executes during object creation, after setting all properties.
function dlPathEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dlPathEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end


% --- Executes on button press in chooseDLButton.
function chooseDLButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseDLButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    filepath = ...
        uigetdir(handles.lastPath, 'Select the download directory...');
    if filepath ~= 0
        set(handles.dlPathEdit, 'String', filepath);
        updateLastPath(hObject, handles, filepath);
    end
end



function filepathDKKEdit_Callback(hObject, eventdata, handles)
% hObject    handle to filepathDKKEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filepathDKKEdit as text
%        str2double(get(hObject,'String')) returns contents of filepathDKKEdit as a double
end

% --- Executes during object creation, after setting all properties.
function filepathDKKEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filepathDKKEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end

% --- Executes on button press in chooseDKKButton.
function chooseDKKButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseDKKButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg DKK data output...');
    if filepath ~= 0
        set(handles.filepathDKKEdit,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
    
end



function outputFileEditDKK_Callback(hObject, eventdata, handles)
% hObject    handle to outputFileEditDKK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of outputFileEditDKK as text
%        str2double(get(hObject,'String')) returns contents of outputFileEditDKK as a double
end

% --- Executes during object creation, after setting all properties.
function outputFileEditDKK_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputFileEditDKK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function disableImportSettings(hObject, handles, source)

  [member,idx] = ismember('CRA', handles.importSettings);
      
  if ~member || ~strcmp('BBL API', handles.importSettings{idx,2})
      if strcmp(source, 'FILE')
        set(handles.filepathCRAEdit, 'Enable', 'off');
        set(handles.chooseCRAButton, 'Enable', 'off');
      end
  end

  [member,idx] = ismember('GVT', handles.importSettings);

  if ~member || ~strcmp('BBL API', handles.importSettings{idx,2})
      if strcmp(source, 'FILE')
        set(handles.filepathGVTEdit, 'Enable', 'off');
        set(handles.chooseGVTButton, 'Enable', 'off');
      end
  end

  [member,idx] = ismember('SWP', handles.importSettings);

  if ~member || ~strcmp('BBL API', handles.importSettings{idx,2})
      if strcmp(source, 'FILE')
        set(handles.filepathSWPEdit, 'Enable', 'off');
        set(handles.chooseSWPButton, 'Enable', 'off');
      end
  end

  [member,idx] = ismember('DKK', handles.importSettings);

  if ~member || ~strcmp('BBL API', handles.importSettings{idx,2})
      if strcmp(source, 'FILE')
        set(handles.filepathDKKEdit, 'Enable', 'off');
        set(handles.chooseDKKButton, 'Enable', 'off');
      end
  end
  
  % Update handles structure
  guidata(hObject, handles);
end

function updateLastPath(hObject, handles, filePath)
    [path,~,~] = fileparts(filePath);
    handles.lastPath = path;
    
    % Update handles structure
    guidata(hObject, handles); 
end



function startDateEdit_Callback(hObject, eventdata, handles)
% hObject    handle to startDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of startDateEdit as text
%        str2double(get(hObject,'String')) returns contents of startDateEdit as a double
end

% --- Executes during object creation, after setting all properties.
function startDateEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to startDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function endDateEdit_Callback(hObject, eventdata, handles)
% hObject    handle to endDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of endDateEdit as text
%        str2double(get(hObject,'String')) returns contents of endDateEdit as a double

end

% --- Executes during object creation, after setting all properties.
function endDateEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to endDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function refDateEdit_Callback(hObject, eventdata, handles)
% hObject    handle to refDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of refDateEdit as text
%        str2double(get(hObject,'String')) returns contents of refDateEdit as a double
end

% --- Executes during object creation, after setting all properties.
function refDateEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to refDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
