function [avail,timestamp] = isavailable(filename, listing)
%ISAVAILABLE Checks if a file is listed in a BBL dir(c) output.
% 
%   The output of the Datafeed-Toolbox' dir function is a cell array with
%   cells containing output of a FTP directory listing, e.g.
%   '-rw-r--r--  6468 op       general   6608867 Sep 24 03:05 fields.csv'.
%   
%   AVAIL = ISAVAILABLE(FILENAME,LISTING) checks if filename is listed in
%   the cell array listing which is the output of the dir(c) function.
%
%   [AVAIL,TIMESTAMP] = ISAVAILABLE(FILENAME,LISTING) in addition returns
%   the timestamp of the file from the directory listing.
%
%   Inputs:
%   FILENAME - String of the output file name that should be searched for.
%   LISTING - A cell array of the size Nx1. It is expected to be the output
%       of the 'dir'-method of the bdl class and contains each line of a
%       FTP directory listing.
%
%   Outputs:
%   AVAIL - Boolean indicating if FILENAME was found in the directory
%       LISTING.
%   TIMESTAMP - String in the format 'MMM d HH:mm' corresponding to the
%       timestamp of the file found in the directory listing.

    % Only the availability of a file and not the corresponding timestamp
    % is requested
    if nargout < 2
        % Extract the filenames from the directory listing (%* ignores the
        % field, thus only the filename is requested)
        list = cellfun(@(x)textscan(x,'%*s %*d %*s %*s %*d %*s %*s %*s %s'),...
            listing,'UniformOutput',false);

        % Flatten cell array output
        files = [list{:}];
        files = [files{:}];

        if sum(strcmp(filename,files))
            avail = true;
        else
            avail = false;
        end
    % Availability and timestamp    
    else
        % Extract the filenames from the directory listing (extract the
        % date/time and the filename)
        list = cellfun(@(x)textscan(x,'%*s %*d %*s %*s %*d %s %s %s %s'),...
            listing,'UniformOutput',false);

        % Flatten cell array output
        list = vertcat(list{:});
        files = [list{:,4}];
        stamps = reshape([list{:,1:3}],length(files),[]);
        
        pos = strcmp(filename,files);
        
        if sum(strcmp(filename,files))
            avail = true;
            timestamp = strjoin(stamps(pos,1:end),' ');
        else
            avail = false;
            timestamp = '';
        end
    end

end

