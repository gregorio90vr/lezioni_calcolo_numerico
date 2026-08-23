function varargout = RFR_00A_Import_settings(varargin)
% RFR_00A_IMPORT_SETTINGS MATLAB code for RFR_00A_Import_settings.fig
%      RFR_00A_IMPORT_SETTINGS, by itself, creates a new RFR_00A_IMPORT_SETTINGS or raises the existing
%      singleton*.
%
%      H = RFR_00A_IMPORT_SETTINGS returns the handle to a new RFR_00A_IMPORT_SETTINGS or the handle to
%      the existing singleton*.
%
%      RFR_00A_IMPORT_SETTINGS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RFR_00A_IMPORT_SETTINGS.M with the given input arguments.
%
%      RFR_00A_IMPORT_SETTINGS('Property','Value',...) creates a new RFR_00A_IMPORT_SETTINGS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before RFR_00A_Import_settings_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to RFR_00A_Import_settings_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help RFR_00A_Import_settings

% Last Modified by GUIDE v2.5 08-Jun-2017 09:50:56

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @RFR_00A_Import_settings_OpeningFcn, ...
                   'gui_OutputFcn',  @RFR_00A_Import_settings_OutputFcn, ...
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


% --- Executes just before RFR_00A_Import_settings is made visible.
function RFR_00A_Import_settings_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to RFR_00A_Import_settings (see VARARGIN)

% Choose default command line output for RFR_00B_BBL_settings
    handles.action = '';
    handles.output = {};

    % Update handles structure
    guidata(hObject, handles);

    % UIWAIT makes RFR_00B_BBL_settings wait for hostEdit response (see UIRESUME)
    uiwait(handles.importSettings);

    
% --- Outputs from this function are returned to the command line.
function varargout = RFR_00A_Import_settings_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
    if strcmp(handles.action, '')
        handles.action = 'Cancel';
    end
    
    varargout{1} = handles.action;
    varargout{2} = handles.output;
  
    delete(handles.importSettings);


% --- Executes on button press in gvtCheck.
function gvtCheck_Callback(hObject, eventdata, handles)
% hObject    handle to gvtCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of gvtCheck
    if get(hObject,'Value')
        set(handles.gvtDrop, 'Enable', 'on');
    else
        set(handles.gvtDrop, 'Enable', 'off');
    end

% --- Executes on button press in craCheck.
function craCheck_Callback(hObject, eventdata, handles)
% hObject    handle to craCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of craCheck
    if get(hObject,'Value')
        set(handles.craDrop, 'Enable', 'on');
    else
        set(handles.craDrop, 'Enable', 'off');
    end

% --- Executes on button press in swpCheck.
function swpCheck_Callback(hObject, eventdata, handles)
% hObject    handle to swpCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of swpCheck
     if get(hObject,'Value')
        set(handles.swpDrop, 'Enable', 'on');
    else
        set(handles.swpDrop, 'Enable', 'off');
    end

% --- Executes on button press in ecbCheck.
function ecbCheck_Callback(hObject, eventdata, handles)
% hObject    handle to ecbCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ecbCheck
    if get(hObject,'Value')
        set(handles.ecbDrop, 'Enable', 'on');
    else
        set(handles.ecbDrop, 'Enable', 'off');
    end

% --- Executes on button press in dkkCheck.
function dkkCheck_Callback(hObject, eventdata, handles)
% hObject    handle to dkkCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dkkCheck
    if get(hObject,'Value')
        set(handles.dkkDrop, 'Enable', 'on');
    else
        set(handles.dkkDrop, 'Enable', 'off');
    end

% --- Executes on button press in corpCheck.
function corpCheck_Callback(hObject, eventdata, handles)
% hObject    handle to corpCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of corpCheck
    if get(hObject,'Value')
        set(handles.corpDrop, 'Enable', 'on');
    else
        set(handles.corpDrop, 'Enable', 'off');
    end


% --- Executes on button press in curvesCheck.
function curvesCheck_Callback(hObject, eventdata, handles)
% hObject    handle to curvesCheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of curvesCheck
    if get(hObject,'Value')
        set(handles.curvesDrop, 'Enable', 'on');
    else
        set(handles.curvesDrop, 'Enable', 'off');
    end

% --- Executes on button press in okButton.
function okButton_Callback(hObject, eventdata, handles)
% hObject    handle to okButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    handles.action = 'OK';
    handles.output = {};
    
    if get(handles.craCheck,'Value')
        val = get(handles.craDrop,'Value');
        choice = get(handles.craDrop,'String');
        choice = choice{val};
        
        handles.output = [handles.output;{'CRA',choice}];
    end
    
    if get(handles.gvtCheck,'Value')
        val = get(handles.gvtDrop,'Value');
        choice = get(handles.gvtDrop,'String');
        choice = choice{val};
        
        handles.output = [handles.output;{'GVT',choice}];
    end
    
    if get(handles.swpCheck,'Value')
        val = get(handles.swpDrop,'Value');
        choice = get(handles.swpDrop,'String');
        choice = choice{val};
        
        handles.output = [handles.output;{'SWP',choice}];
    end
    
    if get(handles.ecbCheck,'Value')
        val = get(handles.ecbDrop,'Value');
        choice = get(handles.ecbDrop,'String');
        choice = choice{val};
        
        handles.output = [handles.output;{'ECB',choice}];
    end
    
    if get(handles.dkkCheck,'Value')
        val = get(handles.dkkDrop,'Value');
        choice = get(handles.dkkDrop,'String');
        choice = choice{val};
        
        handles.output = [handles.output;{'DKK',choice}];
    end
    
    if get(handles.corpCheck,'Value')
        val = get(handles.corpDrop,'Value');
        choice = get(handles.corpDrop,'String');
        choice = choice{val};
        
        handles.output = [handles.output;{'CORP',choice}];
    end  
    
    % Check if connection settings fields are empty
    if isempty(handles.output)
        errMessage = sprintf(strcat('At least one data type has to be selected.', ...
            'Check and retry again.'));
        uiwait(errordlg(errMessage,'All checkboxes empty'));

        return
    end

    guidata(hObject,handles);

    close(handles.importSettings);

% --- Executes on button press in cancelButton.
function cancelButton_Callback(hObject, eventdata, handles)
% hObject    handle to cancelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    handles.action = 'Cancel';
    
    guidata(hObject,handles);

    close(handles.importSettings);

% --- Executes on selection change in craDrop.
function craDrop_Callback(hObject, eventdata, handles)
% hObject    handle to craDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns craDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from craDrop


% --- Executes during object creation, after setting all properties.
function craDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to craDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in gvtDrop.
function gvtDrop_Callback(hObject, eventdata, handles)
% hObject    handle to gvtDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns gvtDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from gvtDrop


% --- Executes during object creation, after setting all properties.
function gvtDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gvtDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in swpDrop.
function swpDrop_Callback(hObject, eventdata, handles)
% hObject    handle to swpDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns swpDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from swpDrop


% --- Executes during object creation, after setting all properties.
function swpDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to swpDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ecbDrop.
function ecbDrop_Callback(hObject, eventdata, handles)
% hObject    handle to ecbDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ecbDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ecbDrop


% --- Executes during object creation, after setting all properties.
function ecbDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ecbDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in dkkDrop.
function dkkDrop_Callback(hObject, eventdata, handles)
% hObject    handle to dkkDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dkkDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dkkDrop


% --- Executes during object creation, after setting all properties.
function dkkDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dkkDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in corpDrop.
function corpDrop_Callback(hObject, eventdata, handles)
% hObject    handle to corpDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns corpDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from corpDrop


% --- Executes during object creation, after setting all properties.
function corpDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to corpDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in curvesDrop.
function curvesDrop_Callback(hObject, eventdata, handles)
% hObject    handle to curvesDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns curvesDrop contents as cell array
%        contents{get(hObject,'Value')} returns selected item from curvesDrop


% --- Executes during object creation, after setting all properties.
function curvesDrop_CreateFcn(hObject, eventdata, handles)
% hObject    handle to curvesDrop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes when user attempts to close importSettings.
function importSettings_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to importSettings (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
	% Hint: delete(hObject) closes the figure
    if isequal(get(hObject, 'waitstatus'), 'waiting')
        uiresume(hObject);
    else
        delete(hObject);
    end
