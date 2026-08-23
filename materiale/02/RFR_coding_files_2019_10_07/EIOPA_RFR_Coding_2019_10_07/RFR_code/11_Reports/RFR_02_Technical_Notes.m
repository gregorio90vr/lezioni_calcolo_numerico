function RFR_02_Technical_Notes(config, quarterly)   

    % CONSTANTS
    CURRENCIES = {'EUR','GBP','USD','CHF'};
    
    % Colours
    % 3
    C1 = [133,203,207;...
        57,132,182;...
        29,46,129]/255;
    
    % 4
    C2 = [158,213,205;...
        68,167,203;...
        46,98,161;...
        25,37,116]/255;
    
    % 5
    C3 = [183,223,203;...
        90,186,209;...
        57,132,182;...
        38,73,146;...
        22,31,99]/255;
    
    
    colISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    colISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    colVAcalc = config.RFR_Str_lists.Str_numcol_curncy.VA_calculation;
    
    currencyPeer = config.RFR_Str_lists.C2D_list_curncy(:,colISO4217);
    countryNames = config.RFR_Str_lists.C2D_list_curncy(:,colISO3166);
    
    eurCountries = ~strcmp(countryNames, 'EUR') & strcmp(currencyPeer, 'EUR');
    
    % Prepare the report
    folder_final_curves = config.RFR_Str_config.folders.path_RFR_10_Documents;
    
    if quarterly
        file_output = fullfile(folder_final_curves, ['Technical_Notes_quarterly',datestr(now, 'yyyymmdd_HHMM'),'.docx']);
        templatePath = fullfile(folder_final_curves, 'templates', 'TN_Template_quarterly.dotx');
    else
        file_output = fullfile(folder_final_curves, ['Technical_Notes_monthly',datestr(now, 'yyyymmdd_HHMM'),'.docx']);
        templatePath = fullfile(folder_final_curves, 'templates', 'TN_Template_monthly.dotx');
    end
    
    folder_download = config.RFR_Str_config.folders.path_RFR_09_Publication;    
    file_download = 'RFR_publication_data.mat'; 
       
    pData = load(fullfile(folder_download, file_download));
    
    % For non-quarterly processes, compare with the previous month.
    % Otherwise, compare with the previous quarter.
    curDate = datetime(config.refDate, 'ConvertFrom', 'datenum', 'Format', 'MMMM d yyyy');
    
    if quarterly
        prevDate = eomdate(curDate - calmonths(3));       
    else
        prevDate = eomdate(curDate - calmonths(1));
    end
    
    idx = 0;
    prevIdx = 0;
    
    for i=1:length(pData.publicationData)
        if pData.publicationData(i).date == curDate
            idx = i;
        end
        
        if pData.publicationData(i).date == prevDate
            prevIdx = i;
        end
    end
    
    if idx == 0 || prevIdx == 0
        warning('Couldn''t find the reference date in RFR_publication_data.mat');
        return
    end
    
    % Create the report
    import mlreportgen.dom.*;
    import mlreportgen.report.*;
    
    d = Document(file_output, 'docx', templatePath);
    open(d);
    moveToNextHole(d);

    % Fill in the dates
    append(d, Text(char(curDate), 'Title'));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'mmmm yyyy')));
    moveToNextHole(d);
    append(d, Text(char(curDate)));
    moveToNextHole(d);
    
    % Allocate
    curLLP = zeros(length(CURRENCIES));
    curRates = zeros(length(CURRENCIES),...
        length(pData.publicationData(idx).RFRnoVA.rates{:,CURRENCIES{1}}));
    prevRates = zeros(size(curRates));
    chgRates = zeros(size(curRates));
    avgChgRates = zeros(length(CURRENCIES),1);
    
    rateComparison = figure('rend','painters','pos',[10 10 800 600]);
    
    % Currently, the subplot size is fixed. Maybe adapt to be dynamic if
    % the number of currencies shown in the report should change.
    for i=1:length(CURRENCIES)
        ax = subplot(2,2,i);
        ax.XLabel.String = 'Maturity [Y]';
        ax.YLabel.String = 'RFR [%]';

        title(CURRENCIES{i});
        
        curLLP(i) = pData.publicationData(idx).RFRnoVA.parameters{'LLP',CURRENCIES{i}};
        
        curRates(i,:) = pData.publicationData(idx).RFRnoVA.rates{:,CURRENCIES{i}};
        prevRates(i,:) = pData.publicationData(prevIdx).RFRnoVA.rates{:,CURRENCIES{i}};
        
        hold on
        plot(100*curRates(i,1:60), 'LineWidth', 2);
        plot(100*prevRates(i,1:60), 'LineWidth', 2);
        
        xlim([1,60]);
        
        legend({datestr(curDate, 'dd/mm/yyyy'),datestr(prevDate, 'dd/mm/yyyy')}, 'Location', 'South', 'Orientation',...
            'horizontal');
        legend('boxoff');
        
        chgRates(i,:) =  curRates(i,:) - prevRates(i,:);
        avgChgRates(i) = 100*mean(chgRates(i,1:curLLP(i)));
    end
    
    saveas(rateComparison, 'rateComparison.png');
    plotimage = Image('rateComparison.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(rateComparison);
    
    moveToNextHole(d);
    
    % Describe the RFR changes
    for i=1:length(CURRENCIES)
        append(d, Text(CURRENCIES{i}));
        moveToNextHole(d);
        
        if avgChgRates(i) >= 0
            append(d, Text('increased'));
        else
            append(d, Text('decreased'));
        end
        moveToNextHole(d);
        
        append(d, Text(sprintf('%.3f%%', abs(avgChgRates(i)))));
        moveToNextHole(d);
        
        append(d, Text(curLLP(i)));
        moveToNextHole(d);
        
    end
    
    % 1 Month period
    append(d, Text(datestr(prevDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    % RFR variation chart
    rfrVariation = figure('rend','painters','pos',[10 10 800 600]);
    hold on
    ax = gca;
    ax.XLabel.String = 'Maturity [Y]';
    ax.YLabel.String = 'Rate difference [pp]';
    
    plot(100*chgRates(:,1:60)', 'LineWidth', 2);
    legend(CURRENCIES, 'Location', 'South', 'Orientation',...
            'horizontal');
    legend('boxoff');
    xlim([1,60]);
    
    saveas(rfrVariation, 'rfrVariation.png');
    plotimage = Image('rfrVariation.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(rfrVariation);
    
    moveToNextHole(d);

    moveToNextHole(d);
    
    
    % VA bar chart
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    c = pData.publicationData(idx).RFRwithVA.parameters.Properties.VariableNames;
    va = pData.publicationData(idx).RFRwithVA.parameters{'VA',:};
    
    
    hasVA = logical(cell2mat(config.RFR_Str_lists.C2D_list_curncy(:,colVAcalc)));
    va(~hasVA) = [];
    c = categorical(c(hasVA));
    
    f = figure('rend','painters','pos',[10 10 900 300]);
    b = bar(c,va, 0.8, ...
        'FaceColor', [162/255,212/255,236/255], 'EdgeColor', 'none');

    ax = gca;
    ax.Box = 'off';
    ax.TickDir = 'out';
    
    yl = ylim;
    ylim([yl(1)-5,yl(2)+5]);
    
    labels = arrayfun(@num2str,va,'uniform',false);
    hText = text(c, va, labels);
    set(hText, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    ylabel('VA [bp]');
    saveas(f, 'vaComparison.png');
    plotimage = Image('vaComparison.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(f);
    moveToNextHole(d);
    
    % VA change
    % Fill in the dates
    append(d, Text(datestr(prevDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    c = pData.publicationData(idx).RFRwithVA.parameters.Properties.VariableNames;
    curVA = pData.publicationData(idx).RFRwithVA.parameters{'VA',:};
    prevVA = pData.publicationData(prevIdx).RFRwithVA.parameters{'VA',:};
    chgVA = curVA - prevVA;
    
    
    hasVA = logical(cell2mat(config.RFR_Str_lists.C2D_list_curncy(:,colVAcalc)));
    chgVA(~hasVA) = [];
    c = categorical(c(hasVA));
    
    f = figure('rend','painters','pos',[10 10 900 300]);
    b = bar(c,chgVA, 0.8, ...
        'FaceColor', [162/255,212/255,236/255], 'EdgeColor', 'none');
  
    ax = gca;
    ax.Box = 'off';
    ax.TickDir = 'out';
    
    yl = ylim;
    ylim([yl(1)-5,yl(2)+5]);
    
    labels = arrayfun(@num2str,chgVA,'uniform',false);
    hText = text(c, chgVA, labels);
    set(hText, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    ylabel('Change of the VA [bp]');
    saveas(f, 'vaChange.png');
    plotimage = Image('vaChange.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(f);
    moveToNextHole(d);
    
    % VA Yield changes
    % Govt
    
    % Fill in the dates
    append(d, Text(datestr(prevDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    c = pData.publicationData(idx).RFRwithVA.parameters.Properties.VariableNames;
    curGovtIER = pData.publicationData(idx).VA.Currency.Govts.M2D_govts_IER;
    prevGovtIER = pData.publicationData(prevIdx).VA.Currency.Govts.M2D_govts_IER;
    
    nonZeroIdx = curGovtIER(:,1) ~= 0 & ~eurCountries;
    c = categorical(c(nonZeroIdx));
    chgGovtIER = curGovtIER(nonZeroIdx,:) - prevGovtIER(nonZeroIdx,:);
    chgGovtSpread = chgGovtIER(:,1) - chgGovtIER(:,2);
    chgGovtRC = chgGovtIER(:,1) - chgGovtIER(:,3);
    
    f = figure('rend','painters','pos',[10 10 900 400]);
    b = bar(c,[chgGovtIER,chgGovtSpread,chgGovtRC], 1, 'FaceColor', 'flat', ...
        'EdgeColor', 'none');
    
    for i=1:length(b)
        b(i).CData = C3(i,:);
    end
    
    ax = gca;
    ax.Box = 'off';
    ax.TickDir = 'out';

    legend({'Market Yields','Basic RFR','Risk-Corrected Yields','Spreads','RC'}, 'Location', 'SouthOutside', 'Orientation',...
            'horizontal');
    legend('boxoff');
    
    ylabel('Difference [pp]');
    
    saveas(f, 'vaYieldChangesGovt.png');
    plotimage = Image('vaYieldChangesGovt.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(f);
    moveToNextHole(d);
    
    % VA Yield changes
    % Corp
    
    % Fill in the dates
    append(d, Text(datestr(prevDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    c = pData.publicationData(idx).RFRwithVA.parameters.Properties.VariableNames;
    curCorpIER = pData.publicationData(idx).VA.Currency.Corps.M2D_corps_IER;
    prevCorpIER = pData.publicationData(prevIdx).VA.Currency.Corps.M2D_corps_IER;
    
    nonZeroIdx = curCorpIER(:,1) ~= 0 & ~eurCountries;
    c = categorical(c(nonZeroIdx));
    chgCorpIER = curCorpIER(nonZeroIdx,1:3) - prevCorpIER(nonZeroIdx,1:3);
    chgCorpSpread = chgCorpIER(:,1) - chgCorpIER(:,2);
    chgCorpRC = chgGovtIER(:,1) - chgGovtIER(:,3);
    
    f = figure('rend','painters','pos',[10 10 900 400]);
    b = bar(c,[chgCorpIER,chgCorpSpread,chgCorpRC], 1, 'FaceColor', 'flat',...
        'EdgeColor', 'none');
    
    for i=1:length(b)
        b(i).CData = C3(i,:);
    end
    
    ax = gca;
    ax.Box = 'off';
    ax.TickDir = 'out';

    legend({'Market Yields','Basic RFR','Risk-Corrected Yields','Spreads','RC'}, 'Location', 'SouthOutside', 'Orientation',...
            'horizontal');
    legend('boxoff');
    ylabel('Difference [pp]');
    
    saveas(f, 'vaYieldChangesCorp.png');
    plotimage = Image('vaYieldChangesCorp.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(f);

    moveToNextHole(d);
    
    % NATIONAL INCREASE
    % VA Yield changes
    % Govt
    
    % Fill in the dates
    append(d, Text(datestr(prevDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    c = pData.publicationData(idx).RFRwithVA.parameters.Properties.VariableNames;
    curGovtIER = pData.publicationData(idx).VA.National.Govts.M2D_govts_IER;
    prevGovtIER = pData.publicationData(prevIdx).VA.National.Govts.M2D_govts_IER;
    
    nonZeroIdx = curGovtIER(:,1) ~= 0;
    c = categorical(c(nonZeroIdx));
    chgGovtIER = curGovtIER(nonZeroIdx,:) - prevGovtIER(nonZeroIdx,:);
    chgGovtSpread = chgGovtIER(:,1) - chgGovtIER(:,2);
    chgGovtRC = chgGovtIER(:,1) - chgGovtIER(:,3);
    
    f = figure('rend','painters','pos',[10 10 900 400]);
    b = bar(c,[chgGovtIER,chgGovtSpread,chgGovtRC], 1, 'FaceColor', 'flat', ...
        'EdgeColor', 'none');
    
    for i=1:length(b)
        b(i).CData = C3(i,:);
    end
    
    ax = gca;
    ax.Box = 'off';
    ax.TickDir = 'out';

    legend({'Market Yields','Basic RFR','Risk-Corrected Yields','Spreads','RC'}, 'Location', 'SouthOutside', 'Orientation',...
            'horizontal');
    legend('boxoff');
    
    ylabel('Difference [pp]');
    
    saveas(f, 'vaNationalYieldChangesGovt.png');
    plotimage = Image('vaNationalYieldChangesGovt.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(f);
    moveToNextHole(d);
    
    % VA Yield changes
    % Corp
    
    % Fill in the dates
    append(d, Text(datestr(prevDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    append(d, Text(datestr(curDate, 'dd/mm/yyyy')));
    moveToNextHole(d);
    
    c = pData.publicationData(idx).RFRwithVA.parameters.Properties.VariableNames;
    curCorpIER = pData.publicationData(idx).VA.National.Corps.M2D_corps_IER;
    prevCorpIER = pData.publicationData(prevIdx).VA.National.Corps.M2D_corps_IER;
    
    nonZeroIdx = curCorpIER(:,1) ~= 0;
    c = categorical(c(nonZeroIdx));
    chgCorpIER = curCorpIER(nonZeroIdx,1:3) - prevCorpIER(nonZeroIdx,1:3);
    chgCorpSpread = chgCorpIER(:,1) - chgCorpIER(:,2);
    chgCorpRC = chgGovtIER(:,1) - chgGovtIER(:,3);
    
    f = figure('rend','painters','pos',[10 10 900 400]);
    b = bar(c,[chgCorpIER,chgCorpSpread,chgCorpRC], 1, 'FaceColor', 'flat',...
        'EdgeColor', 'none');
    
    for i=1:length(b)
        b(i).CData = C3(i,:);
    end
    
    ax = gca;
    ax.Box = 'off';
    ax.TickDir = 'out';

    legend({'Market Yields','Basic RFR','Risk-Corrected Yields','Spreads','RC'}, 'Location', 'SouthOutside', 'Orientation',...
            'horizontal');
    legend('boxoff');
    ylabel('Difference [pp]');
    
    saveas(f, 'vaNationalYieldChangesCorp.png');
    plotimage = Image('vaNationalYieldChangesCorp.png');
    plotimage.Style = {ScaleToFit};
    
    append(d,plotimage);
    close(f);
    
    close(d);
    delete('rateComparison.png');
    delete('vaComparison.png');
    delete('rfrVariation.png');
    delete('vaChange.png');
    delete('vaYieldChangesGovt.png');
    delete('vaYieldChangesCorp.png');
    delete('vaNationalYieldChangesGovt.png');
    delete('vaNationalYieldChangesCorp.png');
    
end