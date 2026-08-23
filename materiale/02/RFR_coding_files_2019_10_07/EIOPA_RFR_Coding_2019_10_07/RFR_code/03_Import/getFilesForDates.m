function [fileList,rem] = getFilesForDates(listing, dates, pattern)
%GETFILESFORDATES extracts files from a FTP DIR listing matching a pattern
% FILELIST = GETFILESFORDATES(LISTING, DATES, PATTERN) returns a cell array
% containing all filenames which match a pattern and contain the supplied
% dates. LISTING is the cell array output of the DIR(FTPOBJ) function.
% DATES is a cell array or character vector of the required dates in a
% format suitable of the supplied dateformat in the regexp PATTERN
% argument.
%
% [FILELIST,REM] = GETFILESFORDATES(LISTING, DATES, PATTERN) extracts 
% filenames corresponding to supplied dates from a directory
% listing and returns the filenames as well as the dates which couldn't be
% found in the listing.
%
    [dataFiles,fileDates] = regexp(listing, ...
            pattern, 'match', 'tokens');

    sel = cellfun(@(x) ~isempty(x), dataFiles);
    dataFiles = [dataFiles{sel}];
    fileDates = [fileDates{sel}];
    fileDates = [fileDates{:}]';

    [lia,locb] = ismember(dates, fileDates);
    
    fileList = dataFiles(locb(lia));
    rem = dates(~lia);
end