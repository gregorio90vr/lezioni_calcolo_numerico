function [M3D_rates_download] = ...
                    RFR_02B_Downloads_SWP_GVT_reading_excel_files...
                          (name_excel_file, RFR_Str_lists, ...
                              num_maturities, curves, range_to_read, ...
                              RFR_config_mat_file)
                          
%   -----------------------------------------------------------------------
%       GENERAL INTRODUCTION
%   -----------------------------------------------------------------------
            
    %   Each excel file containing interest rates downloaded
    %   from Bloomberg, has as many sheets as currencies / countries
    % (either govts, swaps or OIS)
    
    %   All sheets have the same design 
    % (range to read is the same)
    
    %   All sheets are automatic(only formulas)
    %   being the sheet 'Master' the one governing
    %   the sheets of currencies / countries

%   -----------------------------------------------------------------------
    col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO3166;

    %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO3166 
        %   for each of the currencies / countries considered
 

%   ======================================================================     
%   1. Opening excel file and listing available sheets   
%   ======================================================================
    % Opening Excel Office with the following instruction
    Excel = actxserver('excel.application'); 

    
    % Opening the concrete Excel file
    ExcelWorkbook = Excel.workbooks.Open(name_excel_file); 
    
    total_currencies = size(RFR_Str_lists.C2D_list_curncy, 1);
    
    [~,C1R_names_sheets_excel_download] = xlsfinfo(name_excel_file);
        %   Instruction 'xlsinfo'  returns a cell array with the names 
        %   of all sheets in the excel file currently opened
    
        
    switch curves
        case 'GVT'
            name_instrument = 'Government bonds curves';
        case 'SWP'
            name_instrument = 'Swaps fixing ibor curves';
        case 'OIS'
            name_instrument = 'Swaps fixing OIS curves';
    end
    
    
    info_bar = waitbar(0, ['Please wait, reading excel file: ', name_excel_file], ...
        'Name', name_instrument);

    

%   ======================================================================     
%   2. Loop passing data each sheet excel file to MatLab structure   
%   ======================================================================
 
    firstImport = true;
    
    for i = 1:total_currencies
        %   name of the sheet containing data to read   =================== 
    
        name_sheet_excel = RFR_Str_lists.C2D_list_curncy(i, col_ISO3166);
            

        %  updating the message of the waitbar  =========================== 
     
        waitbar(i / total_currencies, info_bar, ...
          ['Reading data downloaded for: ', name_sheet_excel]);

        %   control to verify whether the currency of the run(e.g. EUR)
        %   has a sheet with the same id in excel file  ===================               
        if ~any(strcmp(name_sheet_excel,C1R_names_sheets_excel_download))    
            %   the currency of the census of currencies that is running
            % (census = column 3 of the cell array 'C2D_list_curncy') 
            %   is not found in the list of sheets of the excel file
            %   where market data are downloaded 

            id_curncy = RFR_Str_lists.C2D_list_curncy{i, col_ISO3166};            
            info_message = [name_instrument '.' id_curncy ...
                ': Currency not in inventory of currencies. NO DATA IMPORTED'];           
                                         
            RFR_log_register('01_Import', '02B_Download', 'WARNING',...
                info_message, RFR_config_mat_file);
            
            %   no message pop-up because there migth be a lot of them
            
            continue  % rest of the loop ignored and next iteration started        
        end
              

       %   Activating sheet, identifying range to read and reading
       %   Important, name of the sheet should be a character NOT a cell

        activate_sheet(Excel, char(name_sheet_excel));    

        range_data = Excel.ActiveSheet.Range(range_to_read);       
        
        data = range_data.Value;  
       
        [M2D_rates,C2D_texts] = parse_data(data);
        
            %   'M2D_rates' = 2-D matrix with the downloaded rates in excel
            %   'C2D_texts' = 2-D cell array with dates in the first column
            %           as 'dd/mm/yyyy'(rest of columns have no sense)
            
          
            
       %   Control whether no numerical data has been read  ===============
        
        if isempty(M2D_rates)
            
            id_curncy = RFR_Str_lists.C2D_list_curncy{i, col_ISO3166};
            info_message = [name_instrument '.' id_curncy ...
                ': No numerical data read for this case. NO DATA TO IMPORT'];            
                             
            RFR_log_register('01_Import', '02B_Download', 'WARNING',...
                info_message, RFR_config_mat_file);
            
            continue
        end

        M2D_rates = M2D_rates(2:end,:);
            %   the first raw read is disregarded because it usually
            %   has NaN in all columns
        M2D_rates(isnan(M2D_rates)) = 0;


        
        %   setting the vector of downloaded dates in excel
        %   and creating the empty  3-D  matrix to receive the curves
        %   the first run should always be for the 'euro'  ================

        if firstImport
            V1C_dates_ref = datenum(C2D_texts(2:end, 1), 'dd/mm/yyyy');            
            M3D_rates_download = zeros(length(V1C_dates_ref), ...
                                        num_maturities + 1, ...
                                        total_currencies);
            firstImport = false;
        end
       
        

       %    Adding columns when not all maturities has been captured
       %    as columns in 2-D matrix  'M2D_rates'   =======================
        
        if size(M2D_rates, 2) < num_maturities 
            num_cols_add = num_maturities - size(M2D_rates, 2);
            M2D_rates = [M2D_rates,zeros(size(M2D_rates, 1),num_cols_add)]; 
        end
            %   After this 'if',  2-D matrix  'M2D_rates'  has the same
            %   size for all currencies

            

       %    Adding rows when not all dates has been captured
       %    as rows in 2-D matrix  'M2D_rates'   =======================
       
       %    This only can happen when the most recents dates at the end
       %    of the excel file have no rates downloaded
       %    Therefore the solution is to add such dates at the end 
       %    of 2-D marix  'M2D_rates'
        
        if size(M2D_rates, 1) <  length(V1C_dates_ref)
            num_rows_add = length(V1C_dates_ref) - size(M2D_rates, 1);
            M2D_rates = [M2D_rates;zeros(num_rows_add, size(M2D_rates, 2))];   
        end
            %   After this 'if',  2-D matrix  'M2D_rates'  has the same
            %   rows for all currencies

        %   NOTE: In previous instructions above
        %   number of columns 2-D matrix  'M2D_rates'  is set always at 'num_maturities'
        %   and number of rows is set always at  length  'V1C_dates_ref'
        
        M2D_rates(isnan(M2D_rates)) = 0;
        
        M3D_rates_download(:,1,i) = V1C_dates_ref;
        M3D_rates_download(:,2:num_maturities + 1,i) = M2D_rates; 
    end

    close(info_bar); 
% ------------- Closing excel file         --------------------------------

    ExcelWorkbook.Close(false); 
    Quit(Excel);
end