function [RptgenML_CReport1] = RFR_00_TermStructure_Report(config)
%BUILDRFR


histFile = fullfile(config.RFR_Str_config.folders.path_RFR_05_LTAS, ...
    'Str_History_basic_RFR.mat');
load(histFile);

% Determine the dates of the past 4 months
dates = Str_History_basic_RFR.EUR_RFR_basic_spot(:,1);
lastDate = dates(end);

qdates = repmat(lastDate, 4, 1);
for i=1:3
   qdates(i) = addtodate(qdates(4), -(4-i), 'month');
   qdates(i) = dates(find(qdates(i) <= dates, 1, 'first'));
end

docDir = config.RFR_Str_config.folders.path_RFR_10_Documents;

% Create RptgenML.CReport
RptgenML_CReport1 = RptgenML.CReport('Description','DLT Assessment',...
'Format','dom-docx',...
'Stylesheet','default-rg-docx',...
'FilenameName','TermStructure_Report',...
'FilenameType','other',...
'DirectoryName',docDir,...
'DirectoryType','other');

 
% Create rptgen.cfr_titlepage
rptgen_cfr_titlepage1 = rptgen.cfr_titlepage('Include_Date',false,...
'Title','RFR Term Structures of the past 4 months');
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
'EvalString',['opengl hardware',sprintf('\n'),'load(''',histFile,''');',sprintf('\n'),'',sprintf('\n'),'    qdates = [', num2str(qdates(1)), ' ', num2str(qdates(2)), ' ', num2str(qdates(3)), ' ', num2str(qdates(4)), '];',sprintf('\n'),'    ',sprintf('\n'),'    qdateLegend = cellstr(datestr(qdates,''dd/mm/yyyy''));',sprintf('\n'),'    curves = Str_History_basic_RFR;',sprintf('\n'),'  ',sprintf('\n'),'    curs = unique(strtok(fieldnames(curves),''_''), ''stable''); %vector of currency identifiers: "EUR",...',sprintf('\n'),'    mid = struct2table(curves);',sprintf('\n'),'    [nrofdates nrofcurs] = size(mid);',sprintf('\n'),'    mid = table2array(mid);',sprintf('\n'),'    nrofterms = size(mid,2)/nrofcurs; %including first column being date',sprintf('\n'),'    mid =  permute(reshape(mid,[nrofdates, nrofterms, nrofcurs]),[3 1 2]); %dimensions: nrofcurs x nrofdates x nrofterms',sprintf('\n'),'    mid(find(mid==0))=NaN;',sprintf('\n'),'    ',sprintf('\n'),'    numdates = squeeze(mid(1,:,1));',sprintf('\n'),'',sprintf('\n'),'    months = month(numdates);',sprintf('\n'),'    ix = find(months(1:end-1)~=months(2:end)); %find indices for which month changes',sprintf('\n'),'    monthdates = datestr(numdates([1 ix+1]),''mmm-yyyy'');',sprintf('\n'),'    ix=cat(1,[1 ix+1],[ix size(numdates,2)])''; %ix: nrofmonths x 2 => ix(i,:) = begin + end index of i-th month',sprintf('\n'),'    dates = datestr(numdates); %vector containing the dates of the quotes',sprintf('\n'),'    ',sprintf('\n'),'    date6MIdx = addtodate(numdates(end), -12, ''month'');',sprintf('\n'),'    date6MIdx = find(numdates <= date6MIdx, 1, ''last'');',sprintf('\n'),'    ',sprintf('\n'),'    startDate = numdates(date6MIdx);',sprintf('\n'),'    endDate = numdates(end);',sprintf('\n'),'    ',sprintf('\n'),'    [~,plotEntries] = ismember(qdates,numdates);',sprintf('\n'),'    ',sprintf('\n'),'    mid = mid(:,:,2:end); %remove date column from data as they are now stored in seperate dates-vector',sprintf('\n'),'    ',sprintf('\n'),'    nrofterms = nrofterms-1; %adapt nrofterms due to removement of date column',sprintf('\n'),'',sprintf('\n'),'    nrofmonths = size(ix,1);',sprintf('\n'),'       ',sprintf('\n'),'    colCountry = 3;',sprintf('\n'),'    colCurrency = 5;']);
setParent(rptgen_cml_eval1,rptgen_cfr_section1);
 
% Create rptgen_lo.clo_for
rptgen_lo_clo_for1 = rptgen_lo.clo_for('VariableName','i',...
'EndNumber','length(curs)');
setParent(rptgen_lo_clo_for1,rptgen_cfr_section1);
 
% Create rptgen.cml_eval
rptgen_cml_eval2 = rptgen.cml_eval('isInsertString',false,...
'EvalString',['actcur = curs{i};',sprintf('\n'),'        legendLabels = {};',sprintf('\n'),'        ',sprintf('\n'),'        % GRAPH 1',sprintf('\n'),'        % Plot SWP',sprintf('\n'),'        fig = figure;',sprintf('\n'),'        fig.Units = ''centimeters'';',sprintf('\n'),'        fig.Position = [0 0 32 24];',sprintf('\n'),'        ',sprintf('\n'),'        xdata = 1:60;',sprintf('\n'),'        linewidth = 1;',sprintf('\n'),'    ',sprintf('\n'),'',sprintf('\n'),'        plot(xdata, squeeze(mid(i,plotEntries,:)), ''o-'',...',sprintf('\n'),'            ''LineWidth'', linewidth);',sprintf('\n'),'%             legendLabels = [legendLabels, {''SWP 1Y'', ''SWP 5Y'', ''SWP 10Y''}];',sprintf('\n'),'',sprintf('\n'),'        title([actcur '' - RFR Term Structures''], ''Fontsize'', 16);',sprintf('\n'),'',sprintf('\n'),'        xlabel(''Maturity [Years]'', ''Fontsize'', 16);',sprintf('\n'),'        ylabel(''Rate [%]'', ''Fontsize'', 16);',sprintf('\n'),'        % xlim([1 (nrofdates - date6MIdx)]);',sprintf('\n'),'        ys = ylim;',sprintf('\n'),'        ylim([min(0,ys(1)) min(ys(2)+1, 25)]);',sprintf('\n'),'',sprintf('\n'),'        ax = gca;',sprintf('\n'),'',sprintf('\n'),'%         ax.XTick = numdates(round((0:12)*(nrofdates-date6MIdx)/12) + date6MIdx);',sprintf('\n'),'%         datetick(''x'', ''dd/mm/yyyy'', ''keepticks'');',sprintf('\n'),'',sprintf('\n'),'%         ax.XTickLabelRotation = 45;',sprintf('\n'),'        ax.TickDir = ''out'';',sprintf('\n'),'        ',sprintf('\n'),'        ax.YGrid = ''on'';',sprintf('\n'),'        ',sprintf('\n'),'        legend(qdateLegend, ...',sprintf('\n'),'            ''Location'', ''North'', ''Orientation'', ''horizontal'', ''Fontsize'', 13)',sprintf('\n'),'print(gcf,''-dpng'',''-r300'',''',fullfile(docDir,'tempimageeval'),''')']);
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
