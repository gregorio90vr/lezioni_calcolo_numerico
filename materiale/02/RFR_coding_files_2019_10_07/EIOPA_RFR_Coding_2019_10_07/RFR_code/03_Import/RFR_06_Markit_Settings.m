function varargout = RFR_06_Markit_Settings(varargin)
%RFR_06_MARKIT_SETTINGS MATLAB code file for RFR_06_Markit_Settings.fig
%      RFR_06_MARKIT_SETTINGS, by itself, creates a new RFR_06_MARKIT_SETTINGS or raises the existing
%      singleton*.
%
%      H = RFR_06_MARKIT_SETTINGS returns the handle to a new RFR_06_MARKIT_SETTINGS or the handle to
%      the existing singleton*.
%
%      RFR_06_MARKIT_SETTINGS('Property','Value',...) creates a new RFR_06_MARKIT_SETTINGS using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to RFR_06_Markit_Settings_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      RFR_06_MARKIT_SETTINGS('CALLBACK') and RFR_06_MARKIT_SETTINGS('CALLBACK',hObject,...) call the
%      local function named CALLBACK in RFR_06_MARKIT_SETTINGS.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help RFR_06_Markit_Settings

% Last Modified by GUIDE v2.5 01-Jul-2019 11:55:14

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @RFR_06_Markit_Settings_OpeningFcn, ...
                   'gui_OutputFcn',  @RFR_06_Markit_Settings_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
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


% --- Executes just before RFR_06_Markit_Settings is made visible.
function RFR_06_Markit_Settings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

    handles.action = '';
    handles.output = {};
    
% Choose default command line output for RFR_06_Markit_Settings
handles.output = hObject;

    % If the config structure was supplied, fill in the date fields
    if nargin >= 4
        config = varargin{1};
        set(handles.beginEdit, 'String', datestr(config.startDate, 'dd/mm/yyyy'));
        set(handles.endEdit, 'String', datestr(config.refDate, 'dd/mm/yyyy'));
    end
    
    % If the second argument is "true", fill in also the connection details
    if nargin >= 5 && varargin{2}      
          connDetails = varargin{1}.RFR_Str_lists.connections.Markit;
          set(handles.serverEdit, 'String', connDetails.server);
          set(handles.userEdit, 'String', connDetails.user);
          set(handles.passwordEdit, 'String', connDetails.password);
          
          downloadPath = fullfile(connDetails.downloadPath,...
              ['iBoxx_csv_' datestr(config.refDate, 'yyyy_mm')]);
          set(handles.dpathEdit, 'String', downloadPath);
          
           set(handles.fingerprintEdit, 'String', connDetails.fingerprint);
    end
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes RFR_06_Markit_Settings wait for user response (see UIRESUME)
 uiwait(handles.markitFigure);


% --- Outputs from this function are returned to the command line.
function varargout = RFR_06_Markit_Settings_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
   
    % Get default command line output from handles structure
    if strcmp(handles.action,'')
        handles.action = 'Cancel';
    end
    
    varargout{1} = handles.action;
    varargout{2} = handles.output;
  
    delete(handles.markitFigure);

% --- Executes on button press in okButton.
function okButton_Callback(hObject, eventdata, handles)
% hObject    handle to okButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    handles.action = 'OK';
        
    server = get(handles.serverEdit,'String');
    user = get(handles.userEdit,'String');
    password = get(handles.passwordEdit,'String');
    dpath = get(handles.dpathEdit, 'String');
    bdate = get(handles.beginEdit, 'String');
    edate = get(handles.endEdit, 'String');
    fingerprint = get(handles.fingerprintEdit, 'String');
    
    % Check if connection settings fields are empty
    if isempty(server) || isempty(user) || ...
            isempty(dpath) || isempty(bdate) || isempty(edate) || ...
            isempty(fingerprint)
        errMessage = sprintf(['All fields have to be filled in with data.\n' ...
            'Check and retry again.']);
        uiwait(errordlg(errMessage,'Empty fields'));

        return
    end

    % Validate and convert the dates
    try 
        bdate = datetime(bdate, 'InputFormat', 'dd/MM/yyyy', 'Format', ...
            'dd/MM/yyyy');
        edate = datetime(edate, 'InputFormat', 'dd/MM/yyyy', 'Format', ...
            'dd/MM/yyyy');
    catch
        errMessage = 'Please enter dates in the format ''dd/mm/yyyy''!';
        uiwait(errordlg(errMessage,'Wrong dates'));
        return
    end
    
    if bdate >= edate
        errMessage = 'The begin date must be before the end date!';
        uiwait(errordlg(errMessage,'Wrong dates'));
        return
    end
    
    handles.output = struct('server',server,'user',user,...
            'password',password, 'dpath', dpath, 'bdate', bdate, 'edate',...
            edate, 'fingerprint', fingerprint);

    guidata(hObject,handles);

    close(handles.markitFigure);

% --- Executes on button press in cancelButton.
function cancelButton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    handles.action = 'Cancel';
    
    guidata(hObject,handles);

    close(handles.markitFigure);


function serverEdit_Callback(hObject, eventdata, handles)
% hObject    handle to serverEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of serverEdit as text
%        str2double(get(hObject,'String')) returns contents of serverEdit as a double


% --- Executes during object creation, after setting all properties.
function serverEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to serverEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function userEdit_Callback(hObject, eventdata, handles)
% hObject    handle to userEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of userEdit as text
%        str2double(get(hObject,'String')) returns contents of userEdit as a double


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



function passwordEdit_Callback(hObject, eventdata, handles)
% hObject    handle to passwordEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of passwordEdit as text
%        str2double(get(hObject,'String')) returns contents of passwordEdit as a double


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



function dpathEdit_Callback(hObject, eventdata, handles)
% hObject    handle to dpathEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dpathEdit as text
%        str2double(get(hObject,'String')) returns contents of dpathEdit as a double


% --- Executes during object creation, after setting all properties.
function dpathEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dpathEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function beginEdit_Callback(hObject, eventdata, handles)
% hObject    handle to beginEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of beginEdit as text
%        str2double(get(hObject,'String')) returns contents of beginEdit as a double


% --- Executes during object creation, after setting all properties.
function beginEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to beginEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function endEdit_Callback(hObject, eventdata, handles)
% hObject    handle to endEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of endEdit as text
%        str2double(get(hObject,'String')) returns contents of endEdit as a double


% --- Executes during object creation, after setting all properties.
function endEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to endEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when user attempts to close markitFigure.
function markitFigure_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to markitFigure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
if isequal(get(hObject, 'waitstatus'), 'waiting')
    uiresume(hObject);
else
    delete(hObject);
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over beginEdit.
function beginEdit_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to beginEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
        'DestinationUI', {handles.beginEdit, 'String'});
    


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over endEdit.
function endEdit_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to endEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
    'DestinationUI', {handles.endEdit, 'String'});


% --- Executes on button press in chooseButton.
function chooseButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    filepath = ...
        uigetdir('R:\', 'Select the download directory...');
    if filepath ~= 0
        set(handles.dpathEdit, 'String', filepath);
    end



function fingerprintEdit_Callback(hObject, eventdata, handles)
% hObject    handle to fingerprintEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of fingerprintEdit as text
%        str2double(get(hObject,'String')) returns contents of fingerprintEdit as a double


% --- Executes during object creation, after setting all properties.
function fingerprintEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to fingerprintEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
