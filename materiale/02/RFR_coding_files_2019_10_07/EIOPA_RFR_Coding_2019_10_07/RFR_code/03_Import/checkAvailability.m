function avail = checkAvailability(filename, listing)
%CHECKAVAILABILITY Checks if a file is listed in a BBL dir(c) output.
% 
%   The output of the Datafeed-Toolbox' dir function is a cell array with
%   cells containing output of a FTP directory listing, e.g.
%   '-rw-r--r--  6468 op       general   6608867 Sep 24 03:05 fields.csv'.
%   
%   AVAIL = CHECKAVAILABILITY(FILENAME,LISTING) checks if filename is 
%   listed in the cell array listing which is the output of the dir(c) 
%   function.
%
%   Inputs:
%   FILENAME - String of the output file name that should be searched for.
%   LISTING - A cell array of the size Nx1. It is expected to be the output
%       of the 'dir'-method of the bdl class and contains each line of a
%       FTP directory listing.
%   Outputs:
%   AVAIL - Boolean indicating if FILENAME was found in the directory
%       LISTING.

    
    % Extract the filenames from the directory listing
    list = cellfun(@(x)textscan(x,'%*s %*d %*s %*s %*d %*s %*s %*s %s'),...
        listing,'UniformOutput',false);

    % Flatten cell array output
    files = [list{:}];
    files = [files{:}];

    avail = any(strcmp(filename,files));

end