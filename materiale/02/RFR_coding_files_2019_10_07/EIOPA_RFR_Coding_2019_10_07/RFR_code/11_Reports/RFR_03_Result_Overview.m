function RFR_03_Result_Overview(config)   

% Prepare a report showing the development of the RFR, the CRA and the VA
% (with CORP and GOVT components) for each country going back one year from
% the current reference date.

    % CONSTANTS    
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
    
    colISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    colISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    colVAcalc = config.RFR_Str_lists.Str_numcol_curncy.VA_calculation;
    
    currencyPeer = config.RFR_Str_lists.C2D_list_curncy(:,colISO4217);
    countryNames = config.RFR_Str_lists.C2D_list_curncy(:,colISO3166);
    vaCalculated = logical(cell2mat(config.RFR_Str_lists.C2D_list_curncy(:,colVAcalc)));
    
    % Prepare the report
    folder_final_curves = config.RFR_Str_config.folders.path_RFR_10_Documents;        
    file_output = fullfile(folder_final_curves, ['ResultOverview_',datestr(now, 'yyyymmdd_HHMM'),'.docx']);
    templatePath = fullfile(folder_final_curves, 'templates', 'RO_Template.dotx');
    
    folder_download = config.RFR_Str_config.folders.path_RFR_09_Publication;    
    file_download = 'RFR_publication_data.mat'; 
       
    pData = load(fullfile(folder_download, file_download));
    
    currencies = pData.publicationData(end).RFRnoVA.rates.Properties.VariableNames;
    
    curDate = datetime(config.refDate, 'ConvertFrom', 'datenum');
    prevDates = eomdate(curDate - calmonths(1:11));
    
    [~,idx] = ismember([curDate,prevDates], [pData.publicationData.date]);
    
    if any(idx == 0)
        warning('Couldn''t find the reference date or previous dates in RFR_publication_data.mat');
        return
    end
    
    % Create the report
    import mlreportgen.dom.*;
    import mlreportgen.report.*;
    
    d = Document(file_output, 'docx', templatePath);
    open(d);
    moveToNextHole(d);

    % Fill in the dates
    append(d, Text(datestr(curDate, 'dd/mm/yyyy'), 'Title'));
    moveToNextHole(d);
        
    

    for i=1:length(currencies)
        
        % RFR
        coRFR = figure('rend','painters','pos',[10 10 800 600]);
        ax = gca;
        ax.XLabel.String = 'Maturity [Y]';
        ax.YLabel.String = 'RFR [%]';

        title([currencies{i} ' - RFR ']);
                
        rates = arrayfun(@(x) x.RFRnoVA.rates{:,currencies{i}}', ...
            pData.publicationData(idx(1:6)), 'UniformOutput', false);
        rates = cell2mat(rates');
        
        hold on
        plot(100*rates(:,1:60)', 'LineWidth', 1);
        
        xlim([1,60]);
        ylim([min(min(100*rates(:,1:60)'))-0.5,max(max(100*rates(:,1:60)'))+0.5]);
        
        legend(datestr([curDate,prevDates(1:5)], 'dd/mm/yyyy'), 'Location', 'southoutside', 'Orientation',...
            'horizontal');
        legend('boxoff');
        
        saveas(coRFR, [currencies{i} '_RFR.png']);
        plotimage = Image([currencies{i} '_RFR.png']);
        plotimage.Style = {ScaleToFit};

        append(d,plotimage);
        close(coRFR);

        % CRA
        coCRA = figure('rend','painters','pos',[10 10 800 600]);
        ax = gca;
        ax.XLabel.String = 'Date';
        ax.YLabel.String = 'CRA [bp]';

        title([currencies{i} ' - CRA']);
                
        cra = arrayfun(@(x) x.RFRnoVA.parameters{'CRA',currencies{i}}', ...
            pData.publicationData(idx), 'UniformOutput', false);
        cra = flip(cell2mat(cra'));
        
        hold on
        bar(cra, 0.8, 'FaceColor', C1(1,:), 'EdgeColor', 'none');
        
        ylim([0,38]);
        xlim([0.5,length(cra)+0.5]);
        
        ax.XTick = 1:length(cra);
        ax.XTickLabel = cellstr(datestr(flip([curDate,prevDates]), 'dd/mm/yyyy'));
        ax.XTickLabelRotation = 45;
        
        saveas(coCRA, [currencies{i} '_CRA.png']);
        plotimage = Image([currencies{i} '_CRA.png']);
        plotimage.Style = {ScaleToFit};

        append(d,plotimage);
        close(coCRA);
        
        % VA
        % Don't output a graph if no VA is calculated for the given country
        if ~vaCalculated(i)
            continue
        end
        
        coVA = figure('rend','painters','pos',[10 10 800 600]);
        ax = gca;
        hold on
        ax.XLabel.String = 'Date';
        ax.YLabel.String = 'VA [bp]';

        title([currencies{i} ' - VA']);
        
        % Components
        for j = 1:length(idx)
            
            if isempty(pData.publicationData(idx(j)).VA)
                finalVAGov(j) = nan;
                finalVACorp(j) = nan;
                finalVANat(j) = nan;
                
                continue
            end
            
            iersGovC = pData.publicationData(idx(j)).VA.Currency.Govts.M2D_govts_IER;
            iersCorpC = pData.publicationData(idx(j)).VA.Currency.Corps.M2D_corps_IER;

            if strcmp(currencyPeer{i}, 'EUR')
                ierIdx = find(strcmp(currencies, 'EUR'));
            else
                ierIdx = i;
            end
            
            sgov = max(0, iersGovC(ierIdx,1) - iersGovC(ierIdx,2));
            rcgov = max(0, iersGovC(ierIdx,1) - iersGovC(ierIdx,3));
            vaGov = sgov - rcgov;
            
            scorp = max(0, iersCorpC(ierIdx,1) - iersCorpC(ierIdx,2));
            rccorp = max(0, iersCorpC(ierIdx,1) - iersCorpC(ierIdx,3));
            vaCorp = scorp - rccorp;

            weights = pData.publicationData(idx(j)).VA.Currency.M2D_weights;

            finalVAGov(j) = 100 * 0.65 * weights(ierIdx,1)*vaGov;
            finalVACorp(j) = 100 * 0.65 * weights(ierIdx,2)*vaCorp;
            SRCcur = weights(ierIdx,1) * vaGov + weights(ierIdx,2)*vaCorp;
            
            % National VA
            iersGovN = pData.publicationData(idx(j)).VA.National.Govts.M2D_govts_IER;
            iersCorpN = pData.publicationData(idx(j)).VA.National.Corps.M2D_corps_IER;

            sgov = max(0, iersGovN(i,1) - iersGovN(i,2));
            rcgov = max(0, iersGovN(i,1) - iersGovN(i,3));
            vaGovN = sgov - rcgov;
            
            scorp = max(0, iersCorpN(i,1) - iersCorpN(i,2));
            rccorp = max(0, iersCorpN(i,1) - iersCorpN(i,3));
            vaCorpN = scorp - rccorp;

            weights = pData.publicationData(idx(j)).VA.National.M2D_weights;

            
            finalVANat(j) = (weights(i,1)*vaGovN + weights(i,2) * vaCorpN);
            
            if finalVANat(j) <= 1 || finalVANat(j) <= 2*SRCcur
                finalVANat(j) = nan;
            else
                finalVANat(j) = 100 * 0.65 * (finalVANat(j) - 2*SRCcur);
            end
            
        end
        
         b = bar([curDate,prevDates], [finalVAGov',finalVACorp', finalVANat'], 1, 'FaceColor', 'flat', ...
                'EdgeColor', 'none');
        
        ax.XTick = flip([curDate,prevDates]);
        ax.XTickLabelRotation = 45;
        
        for k=1:length(b)
            b(k).CData = C2(k,:);
        end
        
        % Total VA
        va = arrayfun(@(x) x.RFRwithVA.parameters{'VA',currencies{i}}, ...
            pData.publicationData(idx), 'UniformOutput', false);
        va = cell2mat(va);
        
        stem([curDate,prevDates], va, 'LineWidth', 1, 'Color', C2(4,:));

        ax.Box = 'off';
        ax.TickDir = 'out';

        legend({'Gov Part','Corp Part','National Inc.','VA'}, 'Location', 'southoutside', 'Orientation',...
            'horizontal');
        legend('boxoff');
        
        saveas(coVA, [currencies{i} '_VA.png']);
        plotimage = Image([currencies{i} '_VA.png']);
        plotimage.Style = {ScaleToFit};

        append(d, plotimage);
        close(coVA);

    end
    

      close(d);

    for i=1:length(currencies)
       delete([currencies{i} '_RFR.png']); 
       delete([currencies{i} '_VA.png']); 
       delete([currencies{i} '_CRA.png']); 
    end
end

