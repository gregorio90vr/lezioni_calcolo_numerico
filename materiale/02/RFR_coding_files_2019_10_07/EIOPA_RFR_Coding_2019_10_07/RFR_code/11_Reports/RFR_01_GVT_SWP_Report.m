function [RptgenML_CReport1] = RFR_01_GVT_SWP_Report(config)
%RFR_01_GVT_SWP_REPORT
 

configFile = fullfile(config.RFR_Str_config.folders.path_RFR_01_Config, ...
    'EIOPA_RFR_config.mat');
marketData = fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads, ...
    'RFR_basic_curves.mat');
docDir = config.RFR_Str_config.folders.path_RFR_10_Documents;
 
% Create RptgenML.CReport
RptgenML_CReport1 = RptgenML.CReport('Description','','Format','dom-docx',...
'Stylesheet','default-rg-docx',...
'FilenameName','GVT_SWP_Comparison',...
'FilenameType','other',...
'DirectoryName',docDir,...
'DirectoryType','other');
% setedit(RptgenML_CReport1);
 
% Create rptgen.cfr_titlepage
rptgen_cfr_titlepage1 = rptgen.cfr_titlepage('Include_Date',false,...
'Title','Comparison of IRS and Government Bonds per currency for the last 6 months');
rptgen_cfr_text1 = rptgen.cfr_text;
set(rptgen_cfr_titlepage1,'AbstractComp',rptgen_cfr_text1);
rptgen_cfr_text2 = rptgen.cfr_text;
set(rptgen_cfr_titlepage1,'LegalNoticeComp',rptgen_cfr_text2);
rptgen_cfr_image1 = rptgen.cfr_image('FileName','','MaxViewportSize',[7 9]);
set(rptgen_cfr_titlepage1,'ImageComp',rptgen_cfr_image1);
setParent(rptgen_cfr_titlepage1,RptgenML_CReport1);
 
% Create rptgen.cfr_section
rptgen_cfr_section1 = rptgen.cfr_section('StyleName','rgChapterTitle',...
'SectionTitle','Graphs');
setParent(rptgen_cfr_section1,RptgenML_CReport1);

% Create rptgen.cml_eval
rptgen_cml_eval1 = rptgen.cml_eval('isInsertString',false,...
'EvalString',['load(''',configFile , ''')',sprintf('\n'), 'load(''',marketData,''')',sprintf('\n'),'',sprintf('\n'),'    curves = RFR_download_BBL_Mid;',sprintf('\n'),'    ',sprintf('\n'),'    % Remove OIS data',sprintf('\n'),'    oisNames = regexp(fieldnames(curves), ''.+OIS.+'', ''match'');',sprintf('\n'),'    oisNames(cellfun(@isempty,oisNames)) = [];',sprintf('\n'),'    oisNames = [oisNames{:,:}];',sprintf('\n'),'    curves = rmfield(curves, oisNames);',sprintf('\n'),'    ',sprintf('\n'),'    curs = unique(strtok(fieldnames(curves),''_'')); %vector of currency identifiers: "EUR",...',sprintf('\n'),'    mid = struct2table(curves);',sprintf('\n'),'    [nrofdates nrofcurs] = size(mid);',sprintf('\n'),'    mid = table2array(mid);',sprintf('\n'),'    nrofterms = size(mid,2)/nrofcurs; %including first column being date',sprintf('\n'),'    mid =  permute(reshape(mid,[nrofdates, nrofterms, nrofcurs]),[3 1 2]); %dimensions: nrofcurs x nrofdates x nrofterms',sprintf('\n'),'    mid(find(mid==0))=NaN;',sprintf('\n'),'    ',sprintf('\n'),'    numdates = squeeze(mid(1,:,1));',sprintf('\n'),'',sprintf('\n'),'    months = month(numdates);',sprintf('\n'),'    ix = find(months(1:end-1)~=months(2:end)); %find indices for which month changes',sprintf('\n'),'    monthdates = datestr(numdates([1 ix+1]),''mmm-yyyy'');',sprintf('\n'),'    ix=cat(1,[1 ix+1],[ix size(numdates,2)])''; %ix: nrofmonths x 2 => ix(i,:) = begin + end index of i-th month',sprintf('\n'),'    dates = datestr(numdates); %vector containing the dates of the quotes',sprintf('\n'),'    ',sprintf('\n'),'    date6MIdx = addtodate(numdates(end), -6, ''month'');',sprintf('\n'),'    date6MIdx = find(numdates <= date6MIdx, 1, ''last'');',sprintf('\n'),'    ',sprintf('\n'),'    startDate = numdates(date6MIdx);',sprintf('\n'),'    endDate = numdates(end);',sprintf('\n'),'    ',sprintf('\n'),'    mid = mid(:,:,2:end); %remove date column from data as they are now stored in seperate dates-vector',sprintf('\n'),'    ',sprintf('\n'),'    nrofterms = nrofterms-1; %adapt nrofterms due to removement of date column',sprintf('\n'),'',sprintf('\n'),'    nrofmonths = size(ix,1);',sprintf('\n'),'    selectedMats = [1 5 10];',sprintf('\n'),'    ',sprintf('\n'),'    colCountry = 3;',sprintf('\n'),'    colCurrency = 5;']);
setParent(rptgen_cml_eval1,rptgen_cfr_section1);
 
% Create rptgen_lo.clo_for
rptgen_lo_clo_for1 = rptgen_lo.clo_for('VariableName','i',...
'EndNumber','length(curs)');
setParent(rptgen_lo_clo_for1,rptgen_cfr_section1);
 
% Create rptgen.cml_eval
rptgen_cml_eval2 = rptgen.cml_eval('isInsertString',false,...
'EvalString',['actcur = curs{i};',sprintf('\n'),'        legendLabels = {};',sprintf('\n'),'        ',sprintf('\n'),'        countryIdx = find(strcmp(actcur, RFR_Str_lists.C2D_list_curncy(:,colCountry)));',sprintf('\n'),'        ',sprintf('\n'),'        ',sprintf('\n'),'        ixactcurGVT = regexp(fieldnames(curves), strcat(actcur, ''.*GVT''));',sprintf('\n'),'        ixactcurGVT = find(~cellfun(@isempty, ixactcurGVT));',sprintf('\n'),'        ',sprintf('\n'),'        if strcmp(RFR_Str_lists.C2D_list_curncy(countryIdx,colCurrency), ''EUR'')',sprintf('\n'),'            ixactcurSWP = regexp(fieldnames(curves), ''EUR.*SWP'');',sprintf('\n'),'            ixactcurSWP = find(~cellfun(@isempty, ixactcurSWP));',sprintf('\n'),'        else',sprintf('\n'),'            ixactcurSWP = regexp(fieldnames(curves), strcat(actcur, ''.*SWP''));',sprintf('\n'),'            ixactcurSWP = find(~cellfun(@isempty, ixactcurSWP));',sprintf('\n'),'        end',sprintf('\n'),'',sprintf('\n'),'        ',sprintf('\n'),'',sprintf('\n'),'',sprintf('\n'),'',sprintf('\n'),'        % GRAPH 1',sprintf('\n'),'        % Plot SWP',sprintf('\n'),'         fig = figure;',sprintf('\n'),'        fig.Units = ''centimeters'';',sprintf('\n'),'        fig.Position = [0 0 32 24];',sprintf('\n'),'',sprintf('\n'),'        xdata = numdates(date6MIdx:end);',sprintf('\n'),'        linewidth = 1.5;',sprintf('\n'),'    ',sprintf('\n'),'        if ~isempty(ixactcurSWP)',sprintf('\n'),'            plot(xdata, squeeze(mid(ixactcurSWP,date6MIdx:end,selectedMats)),...',sprintf('\n'),'                ''LineWidth'', linewidth);',sprintf('\n'),'            legendLabels = [legendLabels, {''SWP 1Y'', ''SWP 5Y'', ''SWP 10Y''}];',sprintf('\n'),'        end',sprintf('\n'),'        ',sprintf('\n'),'        hold on',sprintf('\n'),'        ',sprintf('\n'),'        % Plot GVT',sprintf('\n'),'        if ~isempty(ixactcurGVT)',sprintf('\n'),'            plot(xdata, squeeze(mid(ixactcurGVT,date6MIdx:end,selectedMats)),...',sprintf('\n'),'                '':'', ''LineWidth'', linewidth);',sprintf('\n'),'            legendLabels = [legendLabels, {''GVT 1Y'', ''GVT 5Y'', ''GVT 10Y''}];',sprintf('\n'),'        end',sprintf('\n'),'        ',sprintf('\n'),'        title([actcur '' - SWP/GVT Comparison'']);',sprintf('\n'),'',sprintf('\n'),'        xlabel(''Date'');',sprintf('\n'),'        ylabel(''Rate [%]'');',sprintf('\n'),'        % xlim([1 (nrofdates - date6MIdx)]);',sprintf('\n'),'        ys = ylim;',sprintf('\n'),'        ylim([ys(1) min(ys(2)+(ys(2)-ys(1))/20,35)]);',sprintf('\n'),'',sprintf('\n'),'        ax = gca;',sprintf('\n'),'',sprintf('\n'),'        ax.XTick = numdates(round((0:6)*(nrofdates-date6MIdx)/6) + date6MIdx);',sprintf('\n'),'        datetick(''x'', ''dd/mm/yyyy'', ''keepticks'');',sprintf('\n'),'',sprintf('\n'),'        ax.XTickLabelRotation = 45;',sprintf('\n'),'        ax.TickDir = ''out'';',sprintf('\n'),'        ',sprintf('\n'),'        ax.YGrid = ''on'';',sprintf('\n'),'',sprintf('\n'),'        legend(legendLabels, ...',sprintf('\n'),'            ''Location'', ''North'', ''Orientation'', ''horizontal'')',sprintf('\n'),'',sprintf('\n'),'print(gcf,''-dpng'',''-r300'',''',fullfile(docDir, 'tempimageeval.png'),''')']);
setParent(rptgen_cml_eval2,rptgen_lo_clo_for1);
 
% Create rptgen.cfr_image
rptgen_cfr_image2 = rptgen.cfr_image('FileName',fullfile(docDir, 'tempimageeval.png'),...
'MaxViewportSize',[15 15],...
'ViewportUnits','centimeters',...
'ViewportSize',[15 15],...
'DocHorizAlign','center');
setParent(rptgen_cfr_image2,rptgen_lo_clo_for1);
 
RptgenML_CReport1.execute;
RptgenML_CReport1.doClose;