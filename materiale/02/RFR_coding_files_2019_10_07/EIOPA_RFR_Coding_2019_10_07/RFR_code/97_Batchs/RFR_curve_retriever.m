
function  RFR_curve_retriever(main_folder)


%%  EXPLANANTION     ------------------------------------------------------
%
%   This is an internal function.
%   It writes in excel the curve the user selects

%%   1.1. Loading to workspace the configuration data
%   ------------------------------------------------    

    RFR_config_mat_file = RFR_01_basic_setting_config(main_folder);
    
    load(RFR_config_mat_file)
        
 
    
%%   1.2. User slects the financial instrument
%    ----------------------------------------------------------------------    

    input_msg = 'Select the instrument whose curve should be retrieved';

    C1C_list_instruments = ...
                {  'Swaps (Mid rates)' ; ...
                   'Government bonds'  ; ...
                   'Overnight index swaps'; ...
                   'Corporate bonds'   ; ...
                   'History basic RFR' ; ...
                   'Swaps (Ask rates)' ; ...
                   'Swaps (Bid rates)'     }  ;
 
               
    selected_instrument = ...
               listdlg( 'PromptString'   ,  'Select the instrument',...
                        'SelectionMode'  ,  'single',...
                        'ListString'     ,  C1C_list_instruments) ;
          
     if isempty(selected_instrument)
         return
     end
     
      
     
     
 %%   1.2. User selects the relevant curve
 %   ----------------------------------------------------------------------    

    
    switch selected_instrument

        case 1
            folder_download = RFR_Str_config.folders.path_RFR_02_Downloads;        
            file_download = 'RFR_basic_curves';       
            load(fullfile(folder_download, file_download));
        
            selected_struct = RFR_download_BBL_Mid;
            C1C_curves = fieldnames(RFR_download_BBL_Mid);
            
            rows_to_show = zeros(length(C1C_curves), 1);
            
            for k_row = 1:length(C1C_curves)
                
                if regexp(C1C_curves{k_row}, 'SWP') > 0
                   rows_to_show(k_row) = 1;
                end
                
            end
                        
            C1C_curves_to_show = C1C_curves(logical(rows_to_show));
                            
                       
        case 2
        
            folder_download = RFR_Str_config.folders.path_RFR_02_Downloads;        
            file_download = 'RFR_basic_curves';       
            load(fullfile(folder_download, file_download));
        
            selected_struct = RFR_download_BBL_Mid;
            C1C_curves = fieldnames(RFR_download_BBL_Mid);
            
            rows_to_show = zeros(length(C1C_curves), 1);
            
            for k_row = 1:length(C1C_curves)
                
                if regexp(C1C_curves{k_row}, 'GVT') > 0
                   rows_to_show(k_row) = 1;
                end
                
            end
                        
            C1C_curves_to_show = C1C_curves(logical(rows_to_show));
                           
                  
        case 3
         
            folder_download = RFR_Str_config.folders.path_RFR_02_Downloads;        
            file_download = 'RFR_basic_curves';       
            load(fullfile(folder_download, file_download));
        
            selected_struct = RFR_download_BBL_Mid;
            C1C_curves = fieldnames(RFR_download_BBL_Mid);
            
            rows_to_show = zeros(length(C1C_curves), 1);
            
            for k_row = 1:length( C1C_curves)
                
                if regexp(C1C_curves{k_row}, 'OIS') > 0
                   rows_to_show(k_row) = 1;
                end
                
            end
                        
            C1C_curves_to_show = C1C_curves(logical(rows_to_show));
           
        case 4      
            folder_download = RFR_Str_config.folders.path_RFR_02_Downloads;        
            file_download = 'Str_Corporates';             
            load(fullfile(folder_download, file_download));
        
            selected_struct = Str_Corporates_iBoxx_Bid;
            C1C_curves = fieldnames(Str_Corporates_iBoxx_Bid);
                        
            C1C_curves_to_show = C1C_curves;
               
        case 5
            folder_download = RFR_Str_config.folders.path_RFR_05_LTAS;        
            file_download = 'Str_History_basic_RFR';
            load(fullfile(folder_download, file_download))
            
            selected_struct = Str_History_basic_RFR;
            C1C_curves = fieldnames(Str_History_basic_RFR);

            C1C_curves_to_show = C1C_curves;
         
        case 6     
            folder_download = RFR_Str_config.folders.path_RFR_02_Downloads;        
            file_download = 'RFR_basic_curves_Bid_Ask';             
            load(fullfile(folder_download, file_download))
        
            selected_struct = RFR_basic_curves_Ask;
            C1C_curves = fieldnames( RFR_basic_curves_Ask);
                        
            C1C_curves_to_show = C1C_curves;
            
            
        case 7        
            folder_download = RFR_Str_config.folders.path_RFR_02_Downloads;        
            file_download = 'RFR_basic_curves_Bid_Ask';             
            load(fullfile(folder_download, file_download));
        
            selected_struct = RFR_basic_curves_Bid;
            C1C_curves = fieldnames(RFR_basic_curves_Bid);
                        
            C1C_curves_to_show = C1C_curves;
                            
    end

    C1C_curves_to_show = sortrows(C1C_curves_to_show);
    
    selected_curve = ...
           listdlg('PromptString',  'Select the curve',...
                    'SelectionMode',  'single',...
                    'ListString',  C1C_curves_to_show);

     if isempty(selected_curve)
         return
     end
             
    
         
     
%%  1.3. User selects the relevant dates
%   ---------------------------------------------------------------------- 
    M2D_curve_to_retrieve = selected_struct.(C1C_curves_to_show{selected_curve});

    max_date_available = max( M2D_curve_to_retrieve ( : , 1));
    
    def = { datestr( max_date_available - 90        , 'dd/mm/yyyy') ,  ...
            datestr( max_date_available     , 'dd/mm/yyyy') };

    C1C_dates = ...
               inputdlg( { 'Start date ' , ...
                           'End date, should be more recent than start date, otherwise process will be cancelled ' } , ...
                           'Dates Curve Retriever' , 1 , def);

    drawnow 
   
    % XXX: Useless -> Define errors
    if isempty(C1C_dates)
    end
  
    if C1C_dates{1}  >=  C1C_dates{2} 
        return
    end
         
    
    start_date = datenum( C1C_dates(1) , 'dd/mm/yyyy');
    end_date   = datenum( C1C_dates(2) , 'dd/mm/yyyy');
    
    rows_to_retrieve = ( M2D_curve_to_retrieve ( : , 1) >= start_date) & ...
                       ( M2D_curve_to_retrieve ( : , 1) <= end_date);
    
    M2D_curve_to_retrieve = M2D_curve_to_retrieve ( rows_to_retrieve , :);
    
    
 
    
    
%%   1.4. The curve is retrieved in excel
%    -------------------------------------------------------------------
          
    [ folder_to_write ] = ...
            uigetdir( 'C:\' , ...
                      'Select the folder where the excel file with the curve retireved should be saved.');

                %   variable  'folder_to_write'  stores 
                %       the complete path of the selected folder, or...
                %       0 if the user pressed 'Cancel' or closed the box

        drawnow

    if isempty(folder_to_write)
        return
    end
    
    
    name_curve = strcat ( C1C_curves_to_show { selected_curve } , ...
                       '_from_' , datestr( start_date , 'yyyymmdd') , ...
                       '_to_'   , datestr( end_date   , 'yyyymmdd'));
                   
    name_excel_file_user = fullfile(folder_to_write, strcat(name_curve, '.xlsx'));
    name_excel_file_original = fullfile(RFR_Str_config.folders.path_RFR_98_Batchs, 'RFR_curve_retriever.xlsx');

    copyfile(name_excel_file_original, name_excel_file_user, 'f')
    
     
    %   cleaning the sheet to write
    
    range_to_write = calcexcelrange(10, 4, 10000, 100);                         

    xlswrite(name_excel_file_user, cell(10000,100), 'Curve_RFR_database', range_to_write);

    
    %   writing the curve
    range_to_write = calcexcelrange(11, 4, size(M2D_curve_to_retrieve, 1), size(M2D_curve_to_retrieve, 2));
      
    xlswrite(name_excel_file_user, M2D_curve_to_retrieve, 'Curve_RFR_database', range_to_write);
        

    info = [name_curve, ' Retrieved ', datestr(now)];
    range_to_write = calcexcelrange(2, 2, 1, 1);        
    xlswrite(name_excel_file_user, {info}, 'Charts', range_to_write);
        

   %   Final message  ---------------------------------------------------
   process_msg = { 'The following curve has been retrieved';...
                ''; ...
                name_curve; ...
                ''; ...
                'in an excel file with that name in folder'; ...
                ''; ...
                folder_to_write };

   user_action = questdlg( process_msg , 'End of the curve retrieving', ...
                           'Open the file' , 'Close' , 'Open the file');  

   drawnow
   
   if strcmp(user_action, 'Open the file')
       winopen(name_excel_file_user)
   else
       return
   end

   drawnow
  
end

