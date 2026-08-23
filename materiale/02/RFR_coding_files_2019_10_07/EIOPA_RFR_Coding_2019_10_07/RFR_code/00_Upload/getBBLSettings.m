function varargout = getBBLSettings(varargin)
% GETBBLSETTINGS MATLAB code for getBBLSettings.fig
%      GETBBLSETTINGS, by itself, creates a new GETBBLSETTINGS or raises the existing
%      singleton*.
%
%      H = GETBBLSETTINGS returns the handle to a new GETBBLSETTINGS or the handle to
%      the existing singleton*.
%
%      GETBBLSETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GETBBLSETTINGS.M with the given input arguments.
%
%      GETBBLSETTINGS('Property','Value',...) creates a new GETBBLSETTINGS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before getBBLSettings_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to getBBLSettings_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help getBBLSettings

% Last Modified by GUIDE v2.5 03-May-2017 17:32:34

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @getBBLSettings_OpeningFcn, ...
                       'gui_OutputFcn',  @getBBLSettings_OutputFcn, ...
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

% --- Executes just before getBBLSettings is made visible.
function getBBLSettings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)
% varargin   command line arguments to getBBLSettings (see VARARGIN)

    % Choose default command line output for getBBLSettings
    handles.action = '';
    handles.type = '';
    handles.output = {};
    
    handles.lastPath = 'R:\';

    % Get the configuration settings from the config file
    if nargin >= 4     
      connDetails = varargin{1};
          
      set(handles.hostEdit, 'String', connDetails.server);
      set(handles.portEdit, 'String', connDetails.port);
      set(handles.userEdit, 'String', connDetails.user);
      set(handles.passwordEdit, 'String', connDetails.password);
      set(handles.decryptEdit, 'String', connDetails.decryptCode); 
      
      if nargin >= 5
          set(handles.startDateEdit, 'String', datestr(varargin{2}, 'dd/mm/yyyy'));
            
          if nargin == 6
            set(handles.endDateEdit, 'String', datestr(varargin{3}, 'dd/mm/yyyy'));
            set(handles.refDateEdit, 'String', datestr(varargin{3}, 'dd/mm/yyyy'));
          end
      end
    end

    % Update handles structure
    guidata(hObject, handles);
    
    % UIWAIT makes getBBLSettings wait for hostEdit response (see UIRESUME)
    uiwait(handles.importFigure);
end

% --- Outputs from this function are returned to the command line.
function varargout = getBBLSettings_OutputFcn(hObject, eventdata, handles) 
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
    handles.type = 'server';

    host = get(handles.hostEdit,'String');
    port = get(handles.portEdit,'String');
    user = get(handles.userEdit,'String');
    password = get(handles.passwordEdit,'String');
    decrypt = get(handles.decryptEdit,'String');

    requestfiles.CRA = strtrim(get(handles.requestFileEditCRA,'String'));
    requestfiles.GVT = strtrim(get(handles.requestFileEditGVT,'String'));
    requestfiles.SWP = strtrim(get(handles.requestFileEditSWP,'String'));
    requestfiles.DKK = strtrim(get(handles.requestFileEditDKK,'String'));
    
    generateFiles = {};
    
    % Check all checkboxes and add the ticked ones to the generateFiles
    % list
    if get(handles.chkGenCRA, 'Value') == 1
       generateFiles =  [generateFiles,'CRA'];
    end
    
    if get(handles.chkGenGVT, 'Value') == 1
       generateFiles =  [generateFiles,'GVT'];
    end
    
    if get(handles.chkGenSWP, 'Value') == 1
       generateFiles =  [generateFiles,'SWP'];
    end
    
    if get(handles.chkGenDKK, 'Value') == 1
       generateFiles =  [generateFiles,'DKK'];
    end
%     outputfiles.OIS = strtrim(get(handles.requestFileEditOIS,'String'));
%     outputfiles.SWPBA = strtrim(get(handles.requestFileEditSWPBA,'String'));
    
    bdate = get(handles.startDateEdit, 'String');
    edate = get(handles.endDateEdit, 'String');
    refdate = get(handles.refDateEdit, 'String');

    % Check if connection settings fields are empty
    if isempty(host) || isempty(port) || isempty(user) || ...
            isempty(password) || isempty(decrypt)
        errMessage = sprintf(strcat('All fields have to be filled in with data.\n', ...
            'Check and retry again.'));
        uiwait(errordlg(errMessage,'Empty fields'));

        return
    end

    % Check if a request filename is missing
    if (isempty(requestfiles.CRA) && ~ismember('CRA', generateFiles)) || ...
       (isempty(requestfiles.GVT) && ~ismember('GVT', generateFiles)) || ...
       (isempty(requestfiles.SWP) && ~ismember('SWP', generateFiles)) || ...
       (isempty(requestfiles.DKK) && ~ismember('DKK', generateFiles))
   
        errMessage = sprintf(strcat('At least one request filename is missing.\n', ...
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
        'password',password,'decrypt',decrypt,'requestfiles',requestfiles,...
        'startdate', bdate, 'enddate', edate, 'refdate', refdate);
    handles.output.generateFiles = generateFiles;

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

% --- Executes on button press in chooseCRAButton.
function chooseCRAButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseCRAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and hostEdit data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg CRA request file...');
    if filepath ~= 0
        set(handles.requestFileEditCRA,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
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

% --- Executes on button press in chooseGVTButton.
function chooseGVTButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseGVTButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg GVT request file...');
    if filepath ~= 0
        set(handles.requestFileEditGVT,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
end

% --- Executes on button press in chooseSWPButton.
function chooseSWPButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseSWPButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg SWP request file...');
    if filepath ~= 0
        set(handles.requestFileEditSWP,'String',strcat(filepath,filename));
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

% --- Executes on button press in chooseDKKButton.
function chooseDKKButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseDKKButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg DKK request file...');
    if filepath ~= 0
        set(handles.requestFileEditDKK,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
    
end

% --- Executes on button press in chooseOISButton.
function chooseOISButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseOISButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    [filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg OIS request file...');
    if filepath ~= 0
        set(handles.requestFileEditOIS,'String',strcat(filepath,filename));
        updateLastPath(hObject, handles, filepath);
    end
end

% --- Executes on button press in chooseSWPBAButton.
function chooseSWPBAButton_Callback(hObject, eventdata, handles)
% hObject    handle to chooseSWPBAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename,filepath,~] = ...
        uigetfile(fullfile(handles.lastPath,'*.*'),'Select the Bloomberg SWP Bid/Ask request file...');
    if filepath ~= 0
        set(handles.requestFileEditSWPBA,'String',strcat(filepath,filename));
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


function outputFileEditOIS_Callback(hObject, eventdata, handles)
% hObject    handle to outputFileEditOIS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of outputFileEditOIS as text
%        str2double(get(hObject,'String')) returns contents of outputFileEditOIS as a double
end

% --- Executes during object creation, after setting all properties.
function outputFileEditOIS_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputFileEditOIS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function outputFileEditSWPBA_Callback(hObject, eventdata, handles)
% hObject    handle to outputFileEditSWPBA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of outputFileEditSWPBA as text
%        str2double(get(hObject,'String')) returns contents of outputFileEditSWPBA as a double
end

% --- Executes during object creation, after setting all properties.
function outputFileEditSWPBA_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputFileEditSWPBA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
end



function updateLastPath(hObject, handles, filePath)
    [path,~,~] = fileparts(filePath);
    handles.lastPath = path;
    
    % Update handles structure
    guidata(hObject, handles); 
end


% --- Executes on button press in chooseOISButton.
function pushbutton14_Callback(hObject, eventdata, handles)
% hObject    handle to chooseOISButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes on button press in chooseSWPBAButton.
function pushbutton15_Callback(hObject, eventdata, handles)
% hObject    handle to chooseSWPBAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
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


function requestFileEditCRA_Callback(hObject, eventdata, handles)
% hObject    handle to requestFileEditCRA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of requestFileEditCRA as text
%        str2double(get(hObject,'String')) returns contents of requestFileEditCRA as a double
end

% --- Executes during object creation, after setting all properties.
function requestFileEditCRA_CreateFcn(hObject, eventdata, handles)
% hObject    handle to requestFileEditCRA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function requestFileEditGVT_Callback(hObject, eventdata, handles)
% hObject    handle to requestFileEditGVT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of requestFileEditGVT as text
%        str2double(get(hObject,'String')) returns contents of requestFileEditGVT as a double
end

% --- Executes during object creation, after setting all properties.
function requestFileEditGVT_CreateFcn(hObject, eventdata, handles)
% hObject    handle to requestFileEditGVT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function requestFileEditSWP_Callback(hObject, eventdata, handles)
% hObject    handle to requestFileEditSWP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of requestFileEditSWP as text
%        str2double(get(hObject,'String')) returns contents of requestFileEditSWP as a double
end

% --- Executes during object creation, after setting all properties.
function requestFileEditSWP_CreateFcn(hObject, eventdata, handles)
% hObject    handle to requestFileEditSWP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function requestFileEditDKK_Callback(hObject, eventdata, handles)
% hObject    handle to requestFileEditDKK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of requestFileEditDKK as text
%        str2double(get(hObject,'String')) returns contents of requestFileEditDKK as a double
end

% --- Executes during object creation, after setting all properties.
function requestFileEditDKK_CreateFcn(hObject, eventdata, handles)
% hObject    handle to requestFileEditDKK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function requestFileEditOIS_Callback(hObject, eventdata, handles)
% hObject    handle to requestFileEditOIS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of requestFileEditOIS as text
%        str2double(get(hObject,'String')) returns contents of requestFileEditOIS as a double
end

% --- Executes during object creation, after setting all properties.
function requestFileEditOIS_CreateFcn(hObject, eventdata, handles)
% hObject    handle to requestFileEditOIS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function requestFileEditSWPBA_Callback(hObject, eventdata, handles)
% hObject    handle to requestFileEditSWPBA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of requestFileEditSWPBA as text
%        str2double(get(hObject,'String')) returns contents of requestFileEditSWPBA as a double
end

% --- Executes during object creation, after setting all properties.
function requestFileEditSWPBA_CreateFcn(hObject, eventdata, handles)
% hObject    handle to requestFileEditSWPBA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end

% --- Executes on button press in chooseCRAButton.
function pushbutton16_Callback(hObject, eventdata, handles)
% hObject    handle to chooseCRAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes on button press in chooseGVTButton.
function pushbutton17_Callback(hObject, eventdata, handles)
% hObject    handle to chooseGVTButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes on button press in chooseSWPButton.
function pushbutton18_Callback(hObject, eventdata, handles)
% hObject    handle to chooseSWPButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes on button press in chooseDKKButton.
function pushbutton19_Callback(hObject, eventdata, handles)
% hObject    handle to chooseDKKButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes on button press in chooseOISButton.
function pushbutton20_Callback(hObject, eventdata, handles)
% hObject    handle to chooseOISButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes on button press in chooseSWPBAButton.
function pushbutton21_Callback(hObject, eventdata, handles)
% hObject    handle to chooseSWPBAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over startDateEdit.
function startDateEdit_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to startDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
    'DestinationUI', {handles.startDateEdit, 'String'});
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over endDateEdit.
function endDateEdit_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to endDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
    'DestinationUI', {handles.endDateEdit, 'String'});
end


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over refDateEdit.
function refDateEdit_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to refDateEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
    'DestinationUI', {handles.refDateEdit, 'String'});
end


% --- Executes on button press in chkGenCRA.
function chkGenCRA_Callback(hObject, eventdata, handles)
% hObject    handle to chkGenCRA (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkGenCRA
    if get(hObject,'Value') == 1
        set(handles.requestFileEditCRA, 'Enable', 'off');
        set(handles.chooseCRAButton, 'Enable', 'off');
    else
        set(handles.requestFileEditCRA, 'Enable', 'on');
        set(handles.chooseCRAButton, 'Enable', 'on');
    end
end

% --- Executes on button press in chkGenGVT.
function chkGenGVT_Callback(hObject, eventdata, handles)
% hObject    handle to chkGenGVT (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkGenGVT
    if get(hObject,'Value') == 1
        set(handles.requestFileEditGVT, 'Enable', 'off');
        set(handles.chooseGVTButton, 'Enable', 'off');
    else
        set(handles.requestFileEditGVT, 'Enable', 'on');
        set(handles.chooseGVTButton, 'Enable', 'on');
    end
end

% --- Executes on button press in chkGenSWP.
function chkGenSWP_Callback(hObject, eventdata, handles)
% hObject    handle to chkGenSWP (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkGenSWP
    if get(hObject,'Value') == 1
        set(handles.requestFileEditSWP, 'Enable', 'off');
        set(handles.chooseSWPButton, 'Enable', 'off');
    else
        set(handles.requestFileEditSWP, 'Enable', 'on');
        set(handles.chooseSWPButton, 'Enable', 'on');
    end
end

% --- Executes on button press in chkGenDKK.
function chkGenDKK_Callback(hObject, eventdata, handles)
% hObject    handle to chkGenDKK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkGenDKK
    if get(hObject,'Value') == 1
        set(handles.requestFileEditDKK, 'Enable', 'off');
        set(handles.chooseDKKButton, 'Enable', 'off');
    else
        set(handles.requestFileEditDKK, 'Enable', 'on');
        set(handles.chooseDKKButton, 'Enable', 'on');
    end
end

% --- Executes on button press in checkbox5.
function checkbox5_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox5
end

% --- Executes on button press in checkbox6.
function checkbox6_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox6
end
