function varargout = MainMenu(varargin)
% MAINMENU MATLAB code for MainMenu.fig
%      MAINMENU, by itself, creates a new MAINMENU or raises the existing
%      singleton*.
%
%      H = MAINMENU returns the handle to a new MAINMENU or the handle to
%      the existing singleton*.
%
%      MAINMENU('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MAINMENU.M with the given input arguments.
%
%      MAINMENU('Property','Value',...) creates a new MAINMENU or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MainMenu_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MainMenu_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MainMenu

% Last Modified by GUIDE v2.5 07-Nov-2017 12:55:04

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MainMenu_OpeningFcn, ...
                   'gui_OutputFcn',  @MainMenu_OutputFcn, ...
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


% --- Executes just before MainMenu is made visible.
function MainMenu_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MainMenu (see VARARGIN)

% Choose default command line output for MainMenu
handles.output = hObject;

% Grab the data and code directory arguments
handles.codeDir = varargin{1};
handles.dataDir = varargin{2};

% Update the data and code directory text strings
set(handles.txtCode, 'String', strcat('Code: ', handles.codeDir));
set(handles.txtData, 'String', strcat('Data: ', handles.dataDir));


% Load the configuration data
h = waitbar(0,'Loading the configuration data...');
RFR_config_mat_file = RFR_01_basic_setting_config(handles.dataDir);
handles.config = load(RFR_config_mat_file);

% Attach the code and data directory paths to config for logging purposes
handles.config.dataDirectory = handles.dataDir;
handles.config.codeDirectory = handles.codeDir;

% Compare the hash values of the data files with the current ones
action = checkHashValues(handles.config);



% Set default values of the start and reference date
% The default value of the reference data will be set to the last day of
% the previous month.
lastDatePrevMon = eomdate(datetime('now') - calmonths(1));
set(handles.editRefDate, 'String', datestr(lastDatePrevMon, 'dd/mm/yyyy'));

% The default value of the start date will be set to the first business day
% after the last calculated historical basic RFR date of the EUR. However,
% it is constrained by not being after the reference date.
folder_download = handles.config.RFR_Str_config.folders.path_RFR_05_LTAS;    
file_download = 'Str_History_basic_RFR'; 
histData = load(fullfile(folder_download, file_download));

lastHistDate = histData.Str_History_basic_RFR.EUR_RFR_basic_spot(end,1);
startDate = min(busdate(lastHistDate, 1, NaN), datenum(lastDatePrevMon));
set(handles.editStartDate, 'String', datestr(startDate, 'dd/mm/yyyy'));

set(handles.lastHistRFR, 'String', strcat('Last historical RFR: ', datestr(lastHistDate, 'dd/mm/yyyy')));


folder_download = handles.config.RFR_Str_config.folders.path_RFR_02_Downloads;    
file_download = 'RFR_basic_curves'; 
inputData = load(fullfile(folder_download, file_download));
lastInputDate = inputData.RFR_download_BBL_Mid.EUR_RAW_GVT_BBL(end,1);

set(handles.lastImport, 'String', strcat('Last imported date: ', datestr(lastInputDate, 'dd/mm/yyyy')));

% Update handles structure
guidata(hObject, handles);

info = ['RFR Calculator successfully started on ' ...
                datestr(now,'dd-mm-yy HH:MM') ...
               ' using the code directory ' handles.codeDir ...
               ' together with the data directory ' handles.dataDir];

RFR_log_register('MainMenu', 'MainMenu', 'INFO',...
            info, handles.config);
            
close(h);
% UIWAIT makes MainMenu wait for user response (see UIRESUME)
 if strcmp(action, 'Continue')
     uiwait(handles.mainMenuFigure);
 else
     close(handles.mainMenuFigure);
 end


% --- Outputs from this function are returned to the command line.
function varargout = MainMenu_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
% varargout{1} = handles.output;



function editStartDate_Callback(hObject, eventdata, handles)
% hObject    handle to editStartDate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editStartDate as text
%        str2double(get(hObject,'String')) returns contents of editStartDate as a double


% --- Executes during object creation, after setting all properties.
function editStartDate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editStartDate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function editRefDate_Callback(hObject, eventdata, handles)
% hObject    handle to editRefDate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editRefDate as text
%        str2double(get(hObject,'String')) returns contents of editRefDate as a double


% --- Executes during object creation, after setting all properties.
function editRefDate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editRefDate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btnQuit.
function btnQuit_Callback(hObject, eventdata, handles)
% hObject    handle to btnQuit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
     guidata(hObject,handles);
    close(handles.mainMenuFigure);

% --- Executes on button press in chkCalc.
function chkCalc_Callback(hObject, eventdata, handles)
% hObject    handle to chkCalc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkCalc


% --- Executes on button press in chkGenRep.
function chkGenRep_Callback(hObject, eventdata, handles)
% hObject    handle to chkGenRep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkGenRep


% --- Executes on button press in chkImport.
function chkImport_Callback(hObject, eventdata, handles)
% hObject    handle to chkImport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkImport


% --- Executes on button press in chkHistory.
function chkHistory_Callback(hObject, eventdata, handles)
% hObject    handle to chkHistory (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkHistory


% --- Executes on button press in btnRun.
function btnRun_Callback(hObject, eventdata, handles)
% hObject    handle to btnRun (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  
    % Check if the start and reference date are valid dates
    try
        startDate = datenum(get(handles.editStartDate, 'String'), 'dd/mm/yyyy');
    catch
        h = errordlg('Please enter a valid start date!', 'Invalid start date');
        uiwait(h);
        
        return
    end
    
    try
        refDate = datenum(get(handles.editRefDate, 'String'), 'dd/mm/yyyy');
    catch
        h = errordlg('Please enter a valid reference date!', 'Invalid reference date');
        uiwait(h);
        
        return
    end
    
    if refDate < startDate
        h = errordlg('The start date has to be before or on the reference date!', ...
            'Invalid start/reference date');
        uiwait(h);
        
        return
    end
    
    handles.config.startDate = startDate;
    handles.config.refDate = refDate;
    
    guidata(hObject, handles);
    
    % Disable all components in the main menu
    disableAllComponents(handles.mainMenuFigure);
        
    % Check all checkboxes if they were ticked off and then run the
    % corresponding tasks
    doImport = logical(get(handles.chkImport,'Value'));
    doUpdate = logical(get(handles.chkHistory,'Value'));
    doCalc = logical(get(handles.chkCalc,'Value'));
    doGenRep = logical(get(handles.chkGenRep,'Value'));
   
    if doImport
        action = RFR_00_Download_main(handles.config);
        
        if strcmp(action, 'Cancel')
             % Enable all components in the main menu
            enableAllComponents(handles.mainMenuFigure);
            return
        end
        
        folder_download = handles.config.RFR_Str_config.folders.path_RFR_02_Downloads;    
        file_download = 'RFR_basic_curves'; 
        inputData = load(fullfile(folder_download, file_download));
        lastInputDate = inputData.RFR_download_BBL_Mid.EUR_RAW_GVT_BBL(end,1);

        set(handles.lastImport, 'String', strcat('Last imported date: ', datestr(lastInputDate, 'dd/mm/yyyy')));
    end
    
    if doUpdate
        action = VA_History_basic_RFR_batch_all_curves(handles.config);
        
        if strcmp(action, 'Cancel')
             % Enable all components in the main menu
            enableAllComponents(handles.mainMenuFigure);
            return
        end
        
        folder_download = handles.config.RFR_Str_config.folders.path_RFR_05_LTAS;    
        file_download = 'Str_History_basic_RFR'; 
        histData = load(fullfile(folder_download, file_download));

        lastHistDate = histData.Str_History_basic_RFR.EUR_RFR_basic_spot(end,1);
        set(handles.lastHistRFR, 'String', strcat('Last historical RFR: ', datestr(lastHistDate, 'dd/mm/yyyy')));
    end
    
    if doCalc
        action = RFR_00_basic_main_function(handles.codeDir, handles.config);
        
        if strcmp(action, 'Cancel')
             % Enable all components in the main menu
            enableAllComponents(handles.mainMenuFigure);
            return
        end
    end
    
    if doGenRep
        % Generate two technical notes in case of a end of quarter
        % calculation.
        if ismember(handles.config.refDate, [datenum(year(handles.config.refDate), 3, 31),...
            datenum(year(handles.config.refDate), 6, 30),...
            datenum(year(handles.config.refDate), 9, 30),...
            datenum(year(handles.config.refDate), 12, 31)])
        
            RFR_02_Technical_Notes(handles.config, true);
        end
        
        RFR_02_Technical_Notes(handles.config, false);
        RFR_03_Result_Overview(handles.config);
        RFR_01_GVT_SWP_Report(handles.config);
    end
    
    % Enable all components in the main menu
    enableAllComponents(handles.mainMenuFigure);
    guidata(hObject, handles);
    

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over editStartDate.
function editStartDate_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to editStartDate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
     'DestinationUI', {handles.editStartDate, 'String'});  


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over editRefDate.
function editRefDate_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to editRefDate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    uicalendar('OutputDateFormat', 'dd/mm/yyyy', 'InitDate', today, ...
     'DestinationUI', {handles.editRefDate, 'String'}); 
 
function enableAllComponents(handle)
    % enable all components in the main menu
    childrenHandles = allchild(handle);
    
    for i=1:length(childrenHandles)
        if isa(childrenHandles(i), 'matlab.ui.container.Panel')
            enableAllComponents(childrenHandles(i));
        else
            set(childrenHandles(i),'enable','on');
        end
    end
    
    
function disableAllComponents(handle)
    % disable all components in the main menu
    childrenHandles = allchild(handle);
    
    for i=1:length(childrenHandles)
        if isa(childrenHandles(i), 'matlab.ui.container.Panel')
            disableAllComponents(childrenHandles(i));
        else
            set(childrenHandles(i),'enable','off');
        end
    end
    
function action = checkHashValues(config)
    action = 'Continue';

    % Load the comparison hash values
    configDir = config.RFR_Str_config.folders.path_RFR_01_Config;
    h = load(fullfile(configDir, 'hashes.mat'));
    
    errors = {};
    
    % 02_Download
    downloadDir = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    
    if ~strcmp(h.hashes.RFR_basic_curves, getHashOfFile(fullfile(downloadDir, 'RFR_basic_curves.mat')))
       errors = [errors,'RFR_basic_curves.mat'];
    end
    
    if ~strcmp(h.hashes.RFR_CRA, getHashOfFile(fullfile(downloadDir, 'RFR_CRA.mat')))
       errors = [errors,'RFR_CRA.mat'];
    end
    
    if ~strcmp(h.hashes.Str_Corporates, getHashOfFile(fullfile(downloadDir, 'Str_Corporates.mat')))
       errors = [errors,'Str_Corporates.mat'];
    end
    
    
    % 05_LTAS
    ltasDir = config.RFR_Str_config.folders.path_RFR_05_LTAS;
    
    if ~strcmp(h.hashes.Str_History_basic_RFR, getHashOfFile(fullfile(ltasDir , 'Str_History_basic_RFR.mat')))
       errors = [errors,'Str_History_basic_RFR.mat'];
    end
    
    % 06_VA
    vaDir = config.RFR_Str_config.folders.path_RFR_06_VA;
    
    if ~strcmp(h.hashes.Str_LTAS_YE2015, getHashOfFile(fullfile(vaDir , 'Str_LTAS_YE2015.mat')))
       errors = [errors,'Str_LTAS_YE2015.mat'];
    end
    
    if ~strcmp(h.hashes.Str_PD_CoD, getHashOfFile(fullfile(vaDir, 'Str_PD_CoD.mat')))
       errors = [errors,'Str_PD_CoD.mat'];
    end
    
    if ~strcmp(h.hashes.Str_VA_market_data, getHashOfFile(fullfile(vaDir, 'Str_VA_market_data.mat')))
       errors = [errors,'Str_VA_market_data.mat'];
    end
    
    if ~isempty(errors)
       errors = strjoin(errors, ',');
       
       RFR_log_register('Main_Menu', 'checkHashValues', 'WARNING', ...
           ['Different hash values for the following files: ', errors], config);
       
       warningMsg = {['The following files have been changed since the last calculation: ',...
                      errors]; 'Would you like to continue?'};
       action = questdlg(warningMsg, 'WARNING: Files were changed', 'Continue', ...
           'Cancel', 'Cancel');            
       
    end
    
function updateHashValues(config)
    hw = waitbar(0,'Saving the recalculated hash values...');
    
    % Load the comparison hash values
    configDir = config.RFR_Str_config.folders.path_RFR_01_Config;
    h = load(fullfile(configDir, 'hashes.mat'));

    % 02_Download
    downloadDir = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    
    h.hashes.RFR_basic_curves = getHashOfFile(fullfile(downloadDir, 'RFR_basic_curves.mat'));
    h.hashes.RFR_CRA = getHashOfFile(fullfile(downloadDir, 'RFR_CRA.mat'));
    h.hashes.Str_Corporates = getHashOfFile(fullfile(downloadDir, 'Str_Corporates.mat'));
    
    % 05_LTAS
    ltasDir = config.RFR_Str_config.folders.path_RFR_05_LTAS;
    
    h.hashes.Str_History_basic_RFR = getHashOfFile(fullfile(ltasDir , 'Str_History_basic_RFR.mat'));

    % 06_VA
    vaDir = config.RFR_Str_config.folders.path_RFR_06_VA;
    
    h.hashes.Str_LTAS_YE2015 = getHashOfFile(fullfile(vaDir , 'Str_LTAS_YE2015.mat'));
    h.hashes.Str_PD_CoD = getHashOfFile(fullfile(vaDir, 'Str_PD_CoD.mat'));
    h.hashes.Str_VA_market_data = getHashOfFile(fullfile(vaDir, 'Str_VA_market_data.mat'));

    save(fullfile(configDir, 'hashes.mat'), '-struct', 'h');
    close(hw);


% --- Executes when user attempts to close mainMenuFigure.
function mainMenuFigure_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to mainMenuFigure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
   updateHashValues(handles.config);
    
   RFR_write_log_to_CSV(handles.config);
   delete(hObject);
