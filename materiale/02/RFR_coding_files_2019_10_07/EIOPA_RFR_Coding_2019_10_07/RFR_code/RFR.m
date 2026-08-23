function RFR
% RFR - Main function of the RFR software
    clear
    clc
    
    set(0, 'DefaulttextInterpreter', 'none');
        % to avoid LaTex messages in command window
     
    codeDirectory = pwd; %Currently active directory
    
    % The next dialog introduces the option to select and set the working
    % directory for the run automaticaly.
    % The user can start the RFR.m file without setting the path before.
    % Matlab will ask to add the path were the RFR.m file is located.
    % Click Add
    % Next the working directory dialog appears to choose the working directory
    % Once the working directory has been chosen it will be added to the
    % Matlab path including all subdirectories.
    
    
    dialog_msg = { 'Your current working directory is:';...
                     '';...
                     codeDirectory;...
                     '';...
                     'Please select an action to execute and confirm OK.';...
                     '';...
                     'Note: the selected working directory will be added to the Matlab path automatically.';...
                     ''; };
    
    C1C_actions = [ { '1. Keep current directory as working directory' } ;...
                    { '2. Select new working directory' } ];


    action = listdlg (  'Name'          , 'SELECT WORKING DIRECTORY' , ... 
                        'PromptString'  , dialog_msg ,...
                        'SelectionMode' , 'single'      ,... 
                        'ListString'    , C1C_actions    ,...
                        'ListSize'      , [ 400 100 ] )  ;
                  
    drawnow
    
    if isempty(action) 
        return
    elseif action == 2
        codeDirectory = uigetdir(codeDirectory);
    end
    
    cd(codeDirectory); %Chosen directory becomes active directory
    addpath(genpath(codeDirectory)); %And is added to Matlab path
    
    % Load the Bloomberg DataLicense API
    javaaddpath(fullfile(codeDirectory, '96_extLib', 'bbdlapi.jar'));
    
    % Determine the data directory
    dataDirectory = uigetdir(codeDirectory, 'Select the data directory');
    
    if dataDirectory == 0
        return
    else
        dataDirectory = fullfile(dataDirectory, filesep);
    end
    
    % Add the directory containing the currency specificities in the data
    % directory to the path
    addpath(fullfile(dataDirectory, '04_basic'));
    
    % Show the main menu and prompt for actions until the user quits
    MainMenu(codeDirectory, dataDirectory);

end