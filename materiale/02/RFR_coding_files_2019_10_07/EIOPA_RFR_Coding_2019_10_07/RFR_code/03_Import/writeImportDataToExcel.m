function writeImportDataToExcel(config, startDate, endDate, type)
%WRITEIMPORTDATATOEXCEL writes the imported market data to an Excel file.
%
% TODO Write doc


%  ------------------------------------------------------------------------
%%  1. Preparation of the workspace
%   -----------------------------------------------------------------------
        info_message = 'Exporting market data to Excel...';                                   
        RFR_log_register('03_Import', 'writeImportDataToExcel', 'INFO',...
            info_message, config);

    %   1.A. Loading variables common to following steps in this function
    %   -------------------------------------------------------------------
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;

    %   1.C.    Reading the excel file with new data to store   -----------
    %   -------------------------------------------------------------------
    switch type
        case 'CRA'
            xlsFile = 'Download_CRA.xlsx';
            template = fullfile(folder_download, 'templates', xlsFile);
            exportFile = fullfile(folder_download, xlsFile);
            copyfile(template, exportFile); 
            
            load(fullfile(folder_download, 'RFR_CRA'), 'M3D_CRA_BBL');
            writeCRADataToExcel(M3D_CRA_BBL, exportFile, startDate, endDate,...
                config.RFR_Str_lists);
        case 'GVT'
            % Prepare output file
            xlsFile = 'Download_basic_Govts.xlsx';
            template = fullfile(folder_download, 'templates', xlsFile);
            exportFile = fullfile(folder_download, xlsFile);
            copyfile(template, exportFile);
            
             % Prepare data structure
            load(fullfile(folder_download, 'RFR_basic_curves'), 'RFR_download_BBL_Mid');
            fn = fieldnames(RFR_download_BBL_Mid);
            rmIdx = cellfun(@(x) isempty(x), strfind(fn, 'GVT'));
            data = rmfield(RFR_download_BBL_Mid, fn(rmIdx));
            
            writeMarketDataToExcel(data, exportFile, startDate, endDate);
        case 'SWP'
            % Prepare output file
            xlsFile = 'Download_basic_Swaps.xlsx';
            template = fullfile(folder_download, 'templates', xlsFile);
            exportFile = fullfile(folder_download, xlsFile);
            copyfile(template, exportFile);
            
            % Prepare data structure
            load(fullfile(folder_download, 'RFR_basic_curves'), 'RFR_download_BBL_Mid');
            fn = fieldnames(RFR_download_BBL_Mid);
            rmIdx = cellfun(@(x) isempty(x), strfind(fn, 'SWP'));
            data = rmfield(RFR_download_BBL_Mid, fn(rmIdx));
            
            writeMarketDataToExcel(data, exportFile, startDate, endDate);
        case 'DKK'
            xlsFile = 'DKK_Nykredits_index.xlsx';
            template = fullfile(folder_download, 'templates', xlsFile);
            exportFile = fullfile(folder_download, xlsFile);
            copyfile(template, exportFile);
            
            % Prepare data structure
            load(fullfile(folder_download, 'Str_Corporates'), 'DKK_Nykredit');
            data = DKK_Nykredit.M2D_DKK_Nykredit;
            
            writeDKKDataToExcel(data, exportFile, startDate, endDate);
        case 'ECB'
            % Prepare output file
            xlsFile = 'ECB_data.xlsx';
            template = fullfile(folder_download, 'templates', xlsFile);
            exportFile = fullfile(folder_download, xlsFile);
            copyfile(template, exportFile);
            
            % Prepare data structure
            load(fullfile(folder_download, 'RFR_basic_curves'), 'RFR_download_BBL_Mid');
            
            data = RFR_download_BBL_Mid.EUR_RAW_GVT_BBL;
            
            writeECBDataToExcel(data, exportFile);    
        case 'OIS'
            error('OIS export not implemented yet!');
    end

    
end

function writeCRADataToExcel(data, xlsFile, startDate, endDate, RFR_Str_lists)
        
    col_ISO4217      = RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_CRA_IBOR_rate = RFR_Str_lists.Str_numcol_curncy.CRA_IBOR_rate;
    col_CRA_OIS_rate = RFR_Str_lists.Str_numcol_curncy.CRA_OIS_rate;
    
    xls_CRA_col = 2;
    xls_CRA_row = 12;
    
    nCountries  = size(RFR_Str_lists.C2D_list_curncy, 1);
    
    % TODO check if firstIdx == lastIdx
    firstIdx = find(data(:,1,1) <= startDate, 1, 'last');
    lastIdx = find(data(:,1,1) <= endDate, 1, 'last');
    
    xlswrite(xlsFile, m2xdate(data(firstIdx:lastIdx,1,1)),...
        'CRA_PXLAST', calcexcelrange(xls_CRA_row, xls_CRA_col,...
        length(firstIdx:lastIdx), 1));

    %   Reading the names of the indexes downloaded   ---------------------
    range_indexes = calcexcelrange(9, 3, 1, nCountries * 2);
    
        %   The instruction above envisages ' nCountries * 2 '  columns
        %   because each country will have two columns 
        %   in the excel file with downloaded data for CRA 
        %   ( first column for ibor reference of the swap instrument
        %     and second column for overnight index)
        
        %   The instruction above allows to have two columns 
        %   for all currencies/countries considered in the process, 
        %   although this will not be the case.
        %   Then, the following instruction will not read 
        %   the empty columns in the rigth side of the range       

        
    [~,CRA_xls_indexes] = xlsread(xlsFile, 'CRA_PXLAST', range_indexes);

                                       
        
%  ------------------------------------------------------------------------
%%  2. Loop for each country/currency
%  ------------------------------------------------------------------------

    for i = 1:nCountries 
            
        % Countries of the euro zone
        % TODO change from numerical index to country/currency name
        % i.e. if country/currency != 'Euro' then continue
        if (i > 1) && ...
                strcmp(RFR_Str_lists.C2D_list_curncy(i, col_ISO4217), 'EUR')                    
            continue
        end

        %   Control of whether the index IBOR for the currency of the run
        %   has been downloaded in the excel file

        CRA_swap_id = RFR_Str_lists.C2D_list_curncy{i,col_CRA_IBOR_rate};
        
        if i == 1
            CRA_swap_id = 'EUR003M Index';
            %  special case for the euro
        end
         
        num_col_swp = find(strcmp(CRA_xls_indexes, CRA_swap_id));
        
        if num_col_swp > 0
           % Data starts at C12 (row 12, col 3)
           range = calcexcelrange(xls_CRA_row, xls_CRA_col + num_col_swp, length(firstIdx:lastIdx), 1);
           xlswrite(xlsFile, data(firstIdx:lastIdx,i+1,1),...
                'CRA_PXLAST', range);
        end                       
 
    
        %   Control of whether the index overnight for currency of the run
        %   has been downloaded
        
        CRA_overnight_id = RFR_Str_lists.C2D_list_curncy{i,col_CRA_OIS_rate};     
        num_col_ois = find(strcmp(CRA_xls_indexes, CRA_overnight_id));
        
        if num_col_ois > 0
            % Data starts at C12 (row 11, col 3)
           range = calcexcelrange(xls_CRA_row, xls_CRA_col + num_col_ois, length(firstIdx:lastIdx), 1);
           xlswrite(xlsFile, data(firstIdx:lastIdx,i+1,2),...
                'CRA_PXLAST', range);
        end
    end
end

function writeMarketDataToExcel(data, xlsFile, startDate, endDate)
    
    [~,sheets] = xlsfinfo(xlsFile);
    
    excel = actxserver('excel.application'); 
    excelWorkbook = excel.workbooks.Open(xlsFile);
    excel.DisplayAlerts = false; 
    
    fn = fieldnames(data);
    
    nCurrencies = length(fn);
    
    
    for i = 1:nCurrencies
        worksheet = strtok(fn{i}, '_');
        
        if ~any(strcmp(worksheet, sheets))
            continue
        end
        
        firstIdx = find(data.(fn{i})(:,1) <= startDate, 1, 'last');
        lastIdx = find(data.(fn{i})(:,1) <= endDate, 1, 'last');
        
        if isempty(firstIdx) || isempty(lastIdx)
            continue
        end
        
        
        
        dateRange = calcexcelrange(12, 2, length(firstIdx:lastIdx), 1);
        range = calcexcelrange(12, 3, length(firstIdx:lastIdx), ...
            size(data.(fn{i}),2));
        
        targetSheet = get(excel.sheets,'item',worksheet);
        targetSheet.Activate;
        
        eActivesheetRange = get(excel.Activesheet,'Range', dateRange);
        eActivesheetRange.Value = m2xdate(data.(fn{i})(firstIdx:lastIdx,1));

        eActivesheetRange = get(excel.Activesheet,'Range', range);
        eActivesheetRange.Value = data.(fn{i})(firstIdx:lastIdx,2:end);
    end
    
    SaveAs(excelWorkbook, xlsFile);
    excelWorkbook.Saved = 1;
    excelWorkbook.Close(false); 
    Quit(excel);
end

function writeDKKDataToExcel(data, xlsFile, startDate, endDate)
    worksheet = 'RFR';
    
    firstIdx = find(data(:,1) <= startDate, 1, 'last');
    lastIdx = find(data(:,1) <= endDate, 1, 'last');
        
    dateRange = calcexcelrange(11, 11, length(firstIdx:lastIdx), 1);
    range = calcexcelrange(11, 12, length(firstIdx:lastIdx), 1);
        
     xlswrite(xlsFile, m2xdate(data(firstIdx:lastIdx,1)),...
                worksheet, dateRange);
     xlswrite(xlsFile, data(firstIdx:lastIdx,2:end),...
                worksheet, range);
            
end

function writeECBDataToExcel(data, xlsFile)
    excel = actxserver('excel.application'); 
    excelWorkbook = excel.workbooks.Open(xlsFile);
    excel.DisplayAlerts = false;

    dateRange = calcexcelrange(5, 2, size(data, 1), 1);
    range = calcexcelrange(5, 3, size(data, 1), ...
        size(data,2)-1);
    
    eActivesheetRange = get(excel.Activesheet,'Range', dateRange);
    eActivesheetRange.Value = m2xdate(data(:,1));

    eActivesheetRange = get(excel.Activesheet,'Range', range);
    eActivesheetRange.Value = data(:,2:end);

    
    SaveAs(excelWorkbook, xlsFile);
    excelWorkbook.Saved = 1;
    excelWorkbook.Close(false); 
    Quit(excel);
end