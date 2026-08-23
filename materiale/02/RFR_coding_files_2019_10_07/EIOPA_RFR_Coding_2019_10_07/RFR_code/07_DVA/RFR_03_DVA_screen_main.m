function varargout = RFR_03_DVA_screen_main(varargin)
% RFR_03_DVA_screen_main MATLAB code for RFR_03_DVA_screen_main.fig
%      RFR_03_DVA_screen_main, by itself, creates a new RFR_03_DVA_screen_main or
%      raises the existing singleton*.
%
%      H = RFR_03_DVA_screen_main returns the handle to a new RFR_03_DVA_screen_main or the handle to
%      the existing singleton*.
%
%      RFR_03_DVA_screen_main('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RFR_03_DVA_screen_main.M with the given input arguments.
%
%      RFR_03_DVA_screen_main('Property','Value',...) creates a new RFR_03_DVA_screen_main or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before RFR_03_DVA_screen_main_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to RFR_03_DVA_screen_main_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help RFR_03_DVA_screen_main

% Last Modified by GUIDE v2.5 18-May-2014 23:22:28

% Begin initialization code - DO NOT EDIT

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @RFR_03_DVA_screen_main_OpeningFcn, ...
                   'gui_OutputFcn',  @RFR_03_DVA_screen_main_OutputFcn, ...
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


% --- Executes just before RFR_03_DVA_screen_main is made visible.

function RFR_03_DVA_screen_main_OpeningFcn(hObject, eventdata, handles, varargin)

% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to RFR_03_DVA_screen_main (see VARARGIN)

    handles.output = hObject;

    set( handles.edit_dates    , 'Enable' , 'off' )    
    set( handles.edit_maturity , 'Enable' , 'off' )
    set( handles.edit_maturity , 'String' , '- -' )   
    
    setappdata( 0, 'selected_curve'  ,  1 ) ;
    setappdata( 0, 'selected_curncy' ,  1 ) ;
    setappdata( 0, 'selected_matur'  ,  1 ) ;    
    setappdata( 0, 'selected_date'   ,  1 ) ;
    
    setappdata( 0, 'slider_value'    ,  0.01 ) ; 
       
    dataDirectory = varargin{2};
    dataDirectory = dataDirectory{:};
    
    setappdata(hObject.Parent, 'dataDirectory', dataDirectory)
    RFR_config_mat_file = RFR_01_basic_setting_config(dataDirectory);
    
    load(RFR_config_mat_file)
    
    folder_workspace = RFR_Str_config.folders.path_RFR_99_Workspace;
    file_workspace = 'RFR_DVA_workspace';
    
    load(fullfile(folder_workspace, file_workspace));

    setappdata( 0 , 'data_Str_vola'  , Str_vola ) ;
    setappdata( 0 , 'data_Str_lists' , RFR_Str_lists ) ;  
    
 
    
% Update handles structure
guidata(hObject, handles);

    % This sets up the initial plot - only do when we are invisible
    % so window can get raised using RFR_03_DVA_screen_main.
    if strcmp(get(hObject,'Visible'),'off')

    end

% UIWAIT makes RFR_03_DVA_screen_main wait for user response (see UIRESUME)
% uiwait(handles.figure1);


%   -----------------------------------------------------------------------
%%  Outputs from this function are returned to the command line.
%   -----------------------------------------------------------------------


function varargout = RFR_03_DVA_screen_main_OutputFcn(hObject, eventdata, handles)
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Get default command line output from handles structure
    varargout{1} = handles.output;



%   -----------------------------------------------------------------------
%%  1. Popup menu for selecting curves
%   -----------------------------------------------------------------------

% --- 1.A. Executes during object creation, after setting all properties.
% -------------------------------------------------------------------------

    function popupmenu_selected_curve_CreateFcn(hObject, eventdata, handles)

        % Hint: popupmenu controls usually have a white background on Windows.
        %       See ISPC and COMPUTER.

        if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
             set(hObject,'BackgroundColor','white');
        end

        set( hObject , 'String' , { 'Par market rates, term structure for a given date' , ...
                                    'Par market rates. Time serie for a given date' , ...
                                    'Zero-coupon spot rates, term structure for a given date' , ...
                                    'Zero-coupon spot rates, Time serie for a given maturity' , ...
                                    'Forward rates, term structure for a given date' , ...
                                    'Forward rates. Time serie for a given maturity' , ...
                                    'Zero-coupon spot, term structure for a given date. Roll measure' , ...
                                    'Zero-coupon spot. Time serie for a given maturity. Roll measure' , ...                                    
                                    'Forward rates. Fitting the last liquid point' } ) ;

    
% --- 1.B. Executes on selection change in popupmenu_selected_curve  ----
% -------------------------------------------------------------------------

    function popupmenu_selected_curve_Callback(hObject, eventdata, handles)

        % Hints: contents = get(hObject,'String') returns popupmenu_selected_curve contents as cell array
        %        contents{get(hObject,'Value')} returns selected item from popupmenu_selected_curve
     
        setappdata( 0, 'selected_curve' ,  get(hObject , 'Value' ) );

            %   with the instruction above the value selected by the user
            %   is stored in  'seleted_curve'
            %   Note what it is stored is the ordinal of the value selected
            %   (e.g.  3rd or 5th line, not the string in itself)

            %   To use such value in any other control the instruction
            %   curve_selected  = getappdata ( 0 , 'selected_curve' ) ;
            %   returns such value in variable  'curve_selected'  
      
         curve_selected    = getappdata ( 0 , 'selected_curve' ) ;
         
         switch curve_selected
         
            case 1
                set( handles.edit_maturity, 'String' , '- -' )
                set( handles.slider1, 'Enable' , 'on' )               
                set( handles.slider1, 'SliderStep' , [ 0.01  0.01 ] ) 
             case 2
                set( handles.edit_dates, 'String' , '- -' )
                set( handles.slider1, 'Enable' , 'on' )
                set( handles.slider1, 'SliderStep' ,  [ 1/60  1/60 ] ) 
             case 3
                set( handles.edit_maturity, 'String' , '- -' )
                set( handles.slider1, 'Enable' , 'on' )               
                set( handles.slider1, 'SliderStep' , [ 0.01  0.01 ] ) 
             case 4
                set( handles.edit_dates, 'String' , '- -' )
                set( handles.slider1, 'Enable' , 'on' )
                set( handles.slider1, 'SliderStep' ,  [ 1/60  1/60 ] )               
             case 5
                set( handles.edit_maturity, 'String' , '- -' )
                set( handles.slider1, 'Enable' , 'on' )               
                set( handles.slider1, 'SliderStep' , [ 0.01  0.01 ] ) 
             case 6
                set( handles.edit_dates, 'String' , '- -' )
                set( handles.slider1, 'Enable' , 'on' )
                set( handles.slider1, 'SliderStep' ,  [ 1/60  1/60 ] )   
             case 7
                set( handles.edit_dates, 'String' , '- -' )
                set( handles.edit_maturity, 'String' , '- -' )               
                %set( handles.slider1, 'Enable' , 'off' )
                
         end

         setappdata( 0, 'slider_value' , 0 )
       

         
%   -----------------------------------------------------------------------
%%  2. Popup menu for selecting currency
%   -----------------------------------------------------------------------

% --- 2.A. Executes during object creation, after setting all properties --
% -------------------------------------------------------------------------

    function popupmenu_curncy_CreateFcn(hObject, eventdata, handles)

        if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
            set(hObject,'BackgroundColor','white');
        end

        dataDirectory = getappdata(hObject.Parent,'dataDirectory');
        RFR_config_mat_file = RFR_01_basic_setting_config(dataDirectory);
    
        load(RFR_config_mat_file);

        col_ISO4217 = RFR_Str_lists.Str_numcol_curncy.ISO4217 ;
        
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO_4217
        %   for each of the currencies / countries considered 

        VecCol_currencies = unique ( RFR_Str_lists.C2D_list_curncy ( 2:end , col_ISO4217 ) );
        set( hObject , 'String' , VecCol_currencies ) ;
        setappdata( 0, 'selected_curncy' ,  1 ) ;    

    
% --- 2.B. Executes on selection change in popupmenu_curncy ---------------
% -------------------------------------------------------------------------

    function popupmenu_curncy_Callback(hObject, eventdata, handles)

        setappdata( 0, 'selected_curncy' ,  get(hObject , 'Value' ) );
                     
                        

%   -----------------------------------------------------------------------
%%  3. Edit regarding 'maturity'
%   -----------------------------------------------------------------------
                         
% --- Executes during object creation, after setting all properties.

    function edit_maturity_CreateFcn(hObject, eventdata, handles)
        % hObject    handle to edit_maturity (see GCBO)
        % eventdata  reserved - to be defined in a future version of MATLAB
        % handles    empty - handles not created until after all CreateFcns called

        % Hint: edit controls usually have a white background on Windows.
        %       See ISPC and COMPUTER.
        if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
            set(hObject,'BackgroundColor','white');
        end



function edit_maturity_Callback(hObject, eventdata, handles)


%   -----------------------------------------------------------------------
%%  4. Edit regarding 'date' of calculation
%   -----------------------------------------------------------------------
                         
 % --- Executes during object creation, after setting all properties.
    function edit_dates_CreateFcn(hObject, eventdata, handles)

        if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
            set(hObject,'BackgroundColor','white');
        end


        Str_vola  = getappdata(0, 'data_Str_vola') ;
        
        VecCol_dates = Str_vola.M3D_par_mkt_rates ( : , 1 , 1 );
        start_date = datestr( VecCol_dates(1) , 'dd/mm/yyyy' ) ;
        % num_dates = length( VecCol_dates) ; 

        set( hObject , 'String' , start_date ) ;


       
    function edit_dates_Callback(hObject, eventdata, handles)


        


%   -----------------------------------------------------------------------
%%  5. Slider
%   -----------------------------------------------------------------------
       
% --- Executes during object creation, after setting all properties  ------

    function slider1_CreateFcn(hObject, eventdata, handles)
        % hObject    handle to slider1 (see GCBO)
        % eventdata  reserved - to be defined in a future version of MATLAB
        % handles    empty - handles not created until after all CreateFcns called

        % Hint: slider controls usually have a light gray background.
        if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
            set(hObject,'BackgroundColor',[.6 .6 .6]);
        end
        

% --- Executes on slider movement  ----------------------------------------

    function slider1_Callback(hObject, eventdata, handles)
    % hObject    handle to slider1 (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Hints: get(hObject,'Value') returns position of slider
    %        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

    
        %   5.1. GETTING DATA FROM OTHER ELEMENTS   -----------------------
        %   ---------------------------------------------------------------
        
        curve_selected   = getappdata ( 0 , 'selected_curve' ) ;
        curncy_selected  = getappdata ( 0 , 'selected_curncy' ) ;
        matur_selected   = getappdata ( 0 , 'selected_matur' ) ;
        date_selected    = getappdata ( 0 , 'selected_date' ) ;

        Str_vola         = getappdata( 0 , 'data_Str_vola' ) ;
        RFR_Str_lists    = getappdata( 0 , 'data_Str_lists' ) ;   

        setappdata( 0, 'slider_value' ,  get(hObject , 'Value' ) ) ;
        slide_selected   = getappdata ( 0 , 'slider_value' ) ;       
        if slide_selected == 0
            slide_selected = 1 ;
        end

        
        %   5.2. WRITING EDITS 'DATES' / MATURITIES '   -------------------
        %   ---------------------------------------------------------------       

        if curve_selected == 1  ||  curve_selected == 3  ||  curve_selected == 5  ||  curve_selected == 7         
            date_selected = min( round( slide_selected * 105 ) , 105 ) ;
            date_string  = Str_vola.M3D_par_mkt_rates ( date_selected, 1, 1 );
            date_string  = datestr( date_string , 'dd/mm/yyyy' ) ;
            set( handles.edit_dates , 'String' , date_string )            
        end
        
        if curve_selected == 2  ||  curve_selected == 4  ||  curve_selected == 6  ||  curve_selected == 8  
            matur_selected = min( round( slide_selected * 60  ) , 60 )  ;
            set( handles.edit_maturity , 'Str' , num2str(matur_selected) )          
        end

        [ Str_plot_left , Str_plot_right ] = RFR_04_DVA_screen_vola_charts ...
                              ( curve_selected  , curncy_selected , ...
                                matur_selected  , date_selected ,...
                                Str_vola , RFR_Str_lists ) ;
        
        %   5.3. PLOTTING CHART LEFT SIDE   -------------------------------
        %   ---------------------------------------------------------------   

        if curve_selected == 9
             
            plot( handles.chart_left , ...
                  Str_plot_left.x_axe , Str_plot_left.M2D_plot(:,1) , ...
                  Str_plot_left.x_axe , Str_plot_left.M2D_plot(:,2) , ...
                  '--rs', 'LineWidth', 2   , ...
                  'MarkerEdgeColor'  , 'r' , ...
                  'MarkerFaceColor'  , 'r' , 'MarkerSize', 3 )
        else
             
            plot( handles.chart_left , ...
              Str_plot_left.x_axe , Str_plot_left.M2D_plot , '--rs', ...
                  'LineWidth', 2 , ...
                  'MarkerEdgeColor' , 'b' , ...
                  'MarkerFaceColor' , 'b' , ...
                  'MarkerSize'  , 3 , ...
                  'DisplayName' , 'Prueba' ) 
         end

        set( handles.chart_left , 'FontSize'   , 11 )        
        set( handles.chart_left , 'XMinorGrid' , 'on' )
        set( handles.chart_left , 'YMinorGrid' , 'on' )
        set( handles.chart_left , 'Color'  , [ 1.0  1.0  0.8 ] )
        
        title  ( handles.chart_left , Str_plot_left.title)
        xlabel ( handles.chart_left , Str_plot_left.text_x_axe ) ;        

        set( handles.chart_left , 'XLim' , [ 0   Str_plot_left.x_max ] )
        if curve_selected ~= 9
            set( handles.chart_left , 'YLimMode' , 'manual' , ...
                 'YLim' , [ Str_plot_left.y_min   Str_plot_left.y_max ] )
        end 
        
        

        %   5.3. PLOTTING CHART RIGHT   -------------------------------
        %   ---------------------------------------------------------------   
                      
        plot( handles.chart_right , ...
                  Str_plot_right.x_axe , Str_plot_right.M2D_plot , ...
                  '--rs' , 'LineWidth', 2  , ...
                  'MarkerEdgeColor'  , 'r' ,...
                  'MarkerFaceColor'  , 'r' ,...
                  'MarkerSize', 3 )
         
        set( handles.chart_left , 'FontSize'   , 11 )        
        set( handles.chart_left , 'XMinorGrid' , 'on' )
        set( handles.chart_left , 'YMinorGrid' , 'on' )
        set( handles.chart_left , 'Color'  , [ 1.0  1.0  0.8 ] )
        
        title  ( handles.chart_left , Str_plot_left.title)
        xlabel ( handles.chart_left , Str_plot_left.text_x_axe ) ;  
        
        set( handles.chart_right , 'FontSize'   , 11 ) 
        set( handles.chart_right , 'XMinorGrid' , 'on' )
        set( handles.chart_right , 'YMinorGrid' , 'on' )
        set( handles.chart_right , 'Color'  , [ 1.00  0.97  0.92 ] )
        
        title  ( handles.chart_right , Str_plot_right.title)
        xlabel ( handles.chart_right , Str_plot_right.text_x_axe ) ;
        
        set( handles.chart_right , 'XLim' , [ 0   Str_plot_right.x_max ] )
        if curve_selected ~=9
            set( handles.chart_right , 'YLimMode'   , 'manual' , ...
                'YLim' , [ Str_plot_right.y_min   Str_plot_right.y_max ]  )
        end
     
        
        
% --- Executes on button press in pushbutton_exit.
function pushbutton_exit_Callback(hObject, eventdata, handles)
    % Hint: delete(hObject) closes the figure
    close(handles.figure1);
