function d = bdlloader(f)
%BDLLOADER Bloomberg Data License file loader.

%   Copyright 1999-2014 The MathWorks, Inc.

% Open file and check for valid file handle
[fid,msg] = fopen(f);
if fid < 0
  error(msg)
end

% Read the file
x = textscan(fid,'%s','delimiter','\n');
x = x{:};

% Parse the file header
startHeaderInd = find(strcmp(x,'START-OF-FILE'))+1;     % START-OF-FILE entry + 1
endHeaderInd = find(strcmp(x,'START-OF-FIELDS'))-1;   % START-OF-FIELDS entry - 1
headerData = x(startHeaderInd:endHeaderInd);
for i = 1:length(headerData);
  if ~isempty(headerData{i}) && ~(headerData{i}(1) == '#')
    eqInd = find(headerData{i} == '=');
    fldName = headerData{i}(1:eqInd-1);
    d.Header.(fldName) = headerData{i}(eqInd+1:end);
  end
end

% Parse field list
startFieldInd = endHeaderInd + 2;
endFieldInd = find(strcmp(x,'END-OF-FIELDS'))-1;
fldList = x(startFieldInd:endFieldInd);
numFields = length(fldList);
    
% Parse data
startDataInd = find(strcmp(x,'START-OF-DATA'))+1;
endDataInd = find(strcmp(x,'END-OF-DATA'))-1;
timeStartedInd = startDataInd - 2;
timeStarted = x{timeStartedInd};
eqInd = find(timeStarted == '=');
d.Header.(timeStarted(1:eqInd-1)) = timeStarted(eqInd+1:end);
timeFinishedInd = endDataInd + 2;
timeFinished = x{timeFinishedInd};
eqInd = find(timeFinished == '=');
d.Header.(timeFinished(1:eqInd-1)) = timeFinished(eqInd+1:end);

data = x(startDataInd:endDataInd);
numRecords = length(data);

switch d.Header.PROGRAMNAME
  
  case 'getdata'

    % Check for bulk data return
    bulkDataFlag = (isfield(d.Header,'OUTPUTFORMAT') && strcmp(d.Header.OUTPUTFORMAT,'bulklist'));

    % Preallocate output
    if bulkDataFlag 
        
      tmpRecord = textscan(data{1},'%s','delimiter','|');
      d.(fldList{1}) = cell(numRecords,length(tmpRecord{:}));
    else
      tmpAlloc = cell(numRecords,1);
      for i = 1:numFields
        d.Identifier = tmpAlloc;
        d.Rcode = tmpAlloc;
        d.Nfields = tmpAlloc;
        d.(fldList{i}) = tmpAlloc;
      end
    end

    % Parse records
    for i = 1:numRecords
      if bulkDataFlag
        tmpRecord = textscan(data{i},'%s','delimiter','|');
        tmpRecord = strtrim(tmpRecord{:}');
        d.(fldList{1})(i,:) = tmpRecord;
      else
        tmpRecord = textscan(data{i},'%s','delimiter','|');
        d.Identifier{i} = tmpRecord{:}{1};
        d.Rcode{i} = tmpRecord{:}{2};
        d.Nfields{i} = tmpRecord{:}{3};
        for j = 1:numFields
          d.(fldList{j}){i} = tmpRecord{:}{j+3};  % First three entries are record info
        end
      end
    end
    
  case 'gethistory'

    % d.Data = cell(numRecords,3);   % Each entry has the security id, date, and field value
    j = 1;
    for i = 1:numRecords
      tmpRecord = textscan(data{i},'%s','delimiter','|');
      if isempty(strfind(tmpRecord{:}{1},'END SECURITY')) && ...
              isempty(strfind(tmpRecord{:}{1},'START SECURITY'))
        
          d.Data(j,1:3) = tmpRecord{:}(1:3);
          j = j + 1;
      end
    end
  
end

% Close file handle
fclose(fid);


 