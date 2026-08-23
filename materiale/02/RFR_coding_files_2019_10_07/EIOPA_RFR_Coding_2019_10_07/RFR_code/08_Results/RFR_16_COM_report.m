function RFR_16_COM_report(config, ER_no_VA, Str_LTAS, Str_PD_CoD_outputs, ER_with_VA)
    col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country;
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_Currency = config.RFR_Str_lists.Str_numcol_curncy.Currency;
    col_EEA = config.RFR_Str_lists.Str_numcol_curncy.EEA;
    col_AN1_order = config.RFR_Str_lists.Str_numcol_curncy.AN1_order;
    col_AN21_order = config.RFR_Str_lists.Str_numcol_curncy.AN21_order;
    col_AN22_order = config.RFR_Str_lists.Str_numcol_curncy.AN22_order;
    col_AN23_order = config.RFR_Str_lists.Str_numcol_curncy.AN23_order;
    col_AN3_order = config.RFR_Str_lists.Str_numcol_curncy.AN3_order;
    
    FS_percent_LTAS_Govts_EEA = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_EEA;
    FS_percent_LTAS_Govts_non_EEA = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_non_EEA;

    folder_final_curves = config.RFR_Str_config.folders.path_RFR_08_Results;        
    file_output = fullfile(folder_final_curves, ['COM_Report',datestr(now, 'yyyymmdd_HHMM'),'.docx']);
    templatePath = fullfile(folder_final_curves, 'templates', 'COM_Template.dotx');
    
    % Create the report
    import mlreportgen.dom.*;
    d = Document(file_output, 'docx', templatePath);
    open(d);
    moveToNextHole(d);
    
    AN1_COLS = 6;
    AN21_COLS = 7;
    
    
    % Determine the order of the currencies for the AN1 output
    an1Order = [config.RFR_Str_lists.C2D_list_curncy{:,col_AN1_order}];
    an1Idx = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1);
    an1Idx(an1Order == 0) = [];
    [~,perm] = sort(an1Order(an1Order ~= 0));
    an1Idx = an1Idx(perm);
    
    termCol = cellstr('Term to maturity (in years)');
    currencies = config.RFR_Str_lists.C2D_list_curncy(:,col_Currency);
    numAN1Tables = ceil(length(an1Idx)/AN1_COLS);
    
    % Define the number format
    nf = java.text.DecimalFormat('##.###''%''');
    dfs = java.text.DecimalFormatSymbols();
    dfs.setDecimalSeparator(',');
    dfs.setGroupingSeparator('.');
    nf.setDecimalFormatSymbols(dfs);
    nf.setMinimumFractionDigits(3);
    nf.setMaximumFractionDigits(3);
    
    
    for i=1:numAN1Tables
        startIdx = (i-1)*AN1_COLS + 1;
        
        if length(an1Idx) >= i*AN1_COLS
            endIdx = i*AN1_COLS;
        else
            endIdx = length(an1Idx);
        end
        
        an1TableHeader = [termCol,currencies{an1Idx(startIdx:endIdx)}];
        
        rates = ER_no_VA.M2D_SW_spot_rates(an1Idx(startIdx:endIdx),:)';
        rates = round(rates * 100000) / 1000;
        rates = arrayfun(@(x) nf.format(x), rates, 'UniformOutput', false);
        rates = cellstr(string(rates));
        
%         rates = num2cell(round(rates * 100000) / 1000);
%         rates = cellfun(@(x) sprintf('%.3f%%', x), rates, ...
%             'UniformOutput', false);
%         rates = cellfun(@(x) nf.format(x), rates, ...
%             'UniformOutput', false);
        
        an1TableBody = [num2cell(1:150)',rates];

        t = FormalTable(an1TableHeader, an1TableBody);
        t.Border = 'solid';
        t.BorderWidth = '1px';
        t.ColSep = 'solid';
        t.ColSepWidth = '1';
        t.RowSep = 'solid';
        t.RowSepWidth = '1';

        % Set this property first to prevent overwriting alignment properties
        t.Header.TableEntriesStyle = {FontFamily('Times New Roman'),InnerMargin('0cm'),FontSize('11pt'),Width('2.33cm'),RowHeight('0.45cm', 'atleast'),Color('black'), Bold};
        t.Body.TableEntriesStyle = {FontFamily('Times New Roman'),InnerMargin('0cm'),FontSize('11pt'),Width('2.33cm'),RowHeight('0.45cm', 'atleast'),Color('black')};
        t.Body.Style = {RowHeight('0.45cm', 'atleast')};
        t.TableEntriesHAlign = 'center';
        t.TableEntriesVAlign = 'middle';

        append(d,t);
        
        if i ~= numAN1Tables
            append(d, Paragraph(''));
            append(d, Paragraph(''));
            append(d, Paragraph(''));
        end
    end
    
    
    moveToNextHole(d);
    
    % ANNEX 2
    % ANNEX 2.1
    
    durCol = cellstr('Duration (in years)');
    
    % Calculation of FS_Govts
    C1C_Currency_Markets_id = config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166);
    FS_Govts = cell(size(Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(:,1:10)));
    
    for i = 1:length(C1C_Currency_Markets_id)       
        if strcmp(config.RFR_Str_lists.C2D_list_curncy(i,col_EEA), 'EEA')
            FS_Govts(i,:) = num2cell(abs(max(0,round(100 * FS_percent_LTAS_Govts_EEA * Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(i,1:10)))));
        else
            FS_Govts(i,:) = num2cell(abs(max(0,round(100 * FS_percent_LTAS_Govts_non_EEA * Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(i,1:10)))));
        end
    end
    
    % Determine the order of the currencies for the AN21 output
    an21Order = [config.RFR_Str_lists.C2D_list_curncy{:,col_AN21_order}];
    an21Idx = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1);
    an21Idx(an21Order == 0) = [];
    [~,perm] = sort(an21Order(an21Order ~= 0));
    an21Idx = an21Idx(perm);
    
    countries = config.RFR_Str_lists.C2D_list_curncy(:,col_name_country);
    
    % Create the tables
    numAN21Tables = ceil(length(an21Idx)/AN21_COLS);
    
        
    for i=1:numAN21Tables
        startIdx = (i-1)*AN21_COLS + 1;
        
        if length(an21Idx) >= i*AN21_COLS
            endIdx = i*AN21_COLS;
        else
            endIdx = length(an21Idx);
        end
        
        an21TableHeader = [durCol,countries{an21Idx(startIdx:endIdx)}];   
        an21TableBody = [num2cell(1:10)',FS_Govts(an21Idx(startIdx:endIdx),:)'];

        t = FormalTable(an21TableHeader, an21TableBody);
        t.Border = 'solid';
        t.BorderWidth = '1px';
        t.ColSep = 'solid';
        t.ColSepWidth = '1';
        t.RowSep = 'solid';
        t.RowSepWidth = '1';

        % Set this property first to prevent overwriting alignment properties
        t.Header.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Width('2.04cm'),RowHeight('0.45cm', 'atleast'),Color('black'), Bold};
        t.Body.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Width('2.04cm'),RowHeight('0.45cm', 'atleast'),Color('black')};
        t.Body.Style = {RowHeight('0.45cm', 'atleast')};
        t.TableEntriesHAlign = 'center';
        t.TableEntriesVAlign = 'middle';

        append(d,t);
        append(d, Paragraph(''));

    end
    
    
    moveToNextHole(d);
    
    % Annex 2.2
    an22TableHeader = {'Duration (in years)','Credit quality step 0',...
        'Credit quality step 1','Credit quality step 2','Credit quality step 3',...
        'Credit quality step 4','Credit quality step 5','Credit quality step 6'};
    
    % Determine the order of the currencies for the AN22 output
    an22Order = [config.RFR_Str_lists.C2D_list_curncy{:,col_AN22_order}];
    an22Idx = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1);
    an22Idx(an22Order == 0) = [];
    [~,perm] = sort(an22Order(an22Order ~= 0));
    an22Idx = an22Idx(perm);
    
    counter = 1;
    
    for k = 1:length(an22Idx)         
        id_country = config.RFR_Str_lists.C2D_list_curncy{an22Idx(k),col_ISO3166};
        countryName = config.RFR_Str_lists.C2D_list_curncy{an22Idx(k),col_name_country};
        currencyName = currencies{an22Idx(k)};
        
        if strcmp(id_country, 'ISK')
            continue
        end
        
        if strcmp(config.RFR_Str_lists.C2D_list_curncy{an22Idx(k),col_ISO4217}, 'EUR') && ...
                ~strcmp(countryName, 'Euro')
            continue
        end
        
        curHeader = Paragraph(['2.', num2str(counter), ' ', char(9), currencyName]);
        curHeader.Bold = true;
        curHeader.FontFamilyName = 'Times New Roman';
        curHeader.FontSize = '11pt';
        
        append(d, curHeader);
        
        FS_bp = num2cell(100*Str_PD_CoD_outputs.(id_country).Finan.FS_bp(1:7,1:30)');
        FS_bp = cellfun(@(x) sprintf('%.0f', x), FS_bp, 'UniformOutput', false);
        
           
        an22TableBody = [num2cell(1:30)',FS_bp];

        t = FormalTable(an22TableHeader, an22TableBody);
        t.Border = 'solid';
        t.BorderWidth = '1px';
        t.ColSep = 'solid';
        t.ColSepWidth = '1';
        t.RowSep = 'solid';
        t.RowSepWidth = '1';

        % Set this property first to prevent overwriting alignment properties
        t.Header.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Width('2.04cm'),RowHeight('0.45cm', 'atleast'),Color('black'), Bold};
        t.Body.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Width('2.04cm'),RowHeight('0.45cm', 'atleast'),Color('black')};
        t.Body.Style = {RowHeight('0.45cm', 'atleast')};
        t.TableEntriesHAlign = 'center';
        t.TableEntriesVAlign = 'middle';

        append(d,t);
        append(d, Paragraph(''));
        
        counter = counter + 1;
    end
    
    % Annex 2.3
    moveToNextHole(d);
    an23TableHeader = {'Duration (in years)','Credit quality step 0',...
        'Credit quality step 1','Credit quality step 2','Credit quality step 3',...
        'Credit quality step 4','Credit quality step 5','Credit quality step 6'};
    
    % Determine the order of the currencies for the AN23 output
    an23Order = [config.RFR_Str_lists.C2D_list_curncy{:,col_AN23_order}];
    an23Idx = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1);
    an23Idx(an23Order == 0) = [];
    [~,perm] = sort(an23Order(an23Order ~= 0));
    an23Idx = an23Idx(perm);
    
    counter = 1;
    
    for k = 1:length(an23Idx)  
        id_country = config.RFR_Str_lists.C2D_list_curncy{an23Idx(k),col_ISO3166};
        countryName = config.RFR_Str_lists.C2D_list_curncy{an23Idx(k),col_name_country};
        currencyName = currencies{an23Idx(k)};
        
        if strcmp(id_country, 'ISK')
            continue
        end
        
        if strcmp(config.RFR_Str_lists.C2D_list_curncy{an23Idx(k),col_ISO4217}, 'EUR') && ...
                ~strcmp(countryName, 'Euro')
            continue
        end
        
        curHeader = Paragraph(['3.', num2str(counter), ' ', char(9), currencyName]);
        curHeader.Bold = true;
        curHeader.FontFamilyName = 'Times New Roman';
        curHeader.FontSize = '11pt';
        
        append(d, curHeader);
        
        FS_bp = num2cell(100*Str_PD_CoD_outputs.(id_country).Nonfinan.FS_bp(1:7,1:30)');
        FS_bp = cellfun(@(x) sprintf('%.0f', x), FS_bp, 'UniformOutput', false);
        
           
        an23TableBody = [num2cell(1:30)',FS_bp];

        t = FormalTable(an23TableHeader, an23TableBody);
        t.Border = 'solid';
        t.BorderWidth = '1px';
        t.ColSep = 'solid';
        t.ColSepWidth = '1';
        t.RowSep = 'solid';
        t.RowSepWidth = '1';

        % Set this property first to prevent overwriting alignment properties
        t.Header.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Width('2.04cm'),RowHeight('0.45cm', 'atleast'),Color('black'), Bold};
        t.Body.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Width('2.04cm'),RowHeight('0.45cm', 'atleast'),Color('black')};
        t.Body.Style = {RowHeight('0.45cm', 'atleast')};
        t.TableEntriesHAlign = 'center';
        t.TableEntriesVAlign = 'middle';

        append(d,t);
        append(d, Paragraph(''));
        
        counter = counter + 1;
    end
    
    % ANNEX 3
    moveToNextHole(d);
    
    % Determine the order of the currencies for the AN3 output
    an3Order = [config.RFR_Str_lists.C2D_list_curncy{:,col_AN3_order}];
    an3Idx = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1);
    an3Idx(an3Order == 0) = [];
    [~,perm] = sort(an3Order(an3Order ~= 0));
    an3Idx = an3Idx(perm);
    
    vaData = num2cell(100 * ER_with_VA.VecRow_VA_total(an3Idx))';
    vaData = cellfun(@(x) sprintf('%.0f', x), vaData, 'UniformOutput', false);
    
    vaCurrencies = currencies(an3Idx);
    vaMarkets = countries(an3Idx);
    
    an3TableHeader = {'Currency','National insurance market','Volatility adjustment (in bps)'};
    an3TableBody = [vaCurrencies,vaMarkets,vaData];

    t = FormalTable(an3TableHeader, an3TableBody);
    t.Border = 'solid';
    t.BorderWidth = '1px';
    t.ColSep = 'solid';
    t.ColSepWidth = '1';
    t.RowSep = 'solid';
    t.RowSepWidth = '1';

    % Set this property first to prevent overwriting alignment properties
    t.Header.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),RowHeight('0.45cm', 'atleast'),Color('black'), Bold};
    t.Body.TableEntriesStyle = {FontFamily('Times New Roman'),FontSize('11pt'),Color('black')};
    t.Body.Style = {RowHeight('0.45cm', 'atleast')};
    t.TableEntriesHAlign = 'center';
    t.TableEntriesVAlign = 'middle';
    
    append(d,t);
    
    close(d);
end

