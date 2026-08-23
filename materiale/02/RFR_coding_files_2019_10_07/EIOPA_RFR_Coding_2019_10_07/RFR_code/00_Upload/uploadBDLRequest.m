function replyfiles = uploadBDLRequest(config, settings, uploads)
%UPLOADBDLREQUEST Uploads request files to the Bloomberg Data License FTP.
% 
%   This function connects to the Bloomberg Data License FTP server and
%   uploads the given request files. 
%   
%   UPLOADBDLREQUEST(CONFIG)
%
%   Inputs:
%   CONFIG - 
%   
%
%   Outputs:
%   -
%
%   Example:
%       uploadBDLRequest(config);
%
%
    import com.bloomberg.datalic.api.*;
    import com.bloomberg.datalic.util.*;
    import java.io.*;
    import java.lang.*;

    templatesDir = fullfile(config.RFR_Str_config.folders.path_RFR_00_Uploads, ...
        'templates');
    reqFileDir = config.RFR_Str_config.folders.path_RFR_00_Uploads;
    
    startDate = settings.startdate;
    endDate = settings.enddate;
    refDate = settings.refdate;

    info_message = 'Starting upload process...';            
    RFR_log_register('00_Upload', 'uploadBDLRequest', 'INFO',...
        info_message, config);

    c = bdl(settings.user,settings.password,settings.host,settings.port,...
        settings.decrypt);
    s = dir(c);

    if isempty(s)
        info_message = 'Couldn''t connect to the BBL FTP server. Aborting...';            
        RFR_log_register('00_Upload', 'uploadBDLRequest', 'ERROR',...
            info_message, config);

        return
    end

    
	replyfiles = {};
    
    for i = 1:length(uploads)
        switch uploads{i}
            case 'CRA'
                tempFile = config.RFR_Str_lists.connections.BBL.autoCRAReqFile;
                tickers = config.RFR_basic_CRA_Tickers;
            case 'GVT'
                tempFile = config.RFR_Str_lists.connections.BBL.autoGVTReqFile;
                tickers = config.RFR_BBG_GVT_Tickers;
            case 'SWP'
                tempFile = config.RFR_Str_lists.connections.BBL.autoSWPReqFile;
                tickers = config.RFR_BBG_SWP_Tickers;

                % Filter the DLT points (DLT points start at column
                % 11)
                dltPoints = logical(cell2mat(config.RFR_basic_ADLT_SWP(:,11:end)));
                tickers = tickers(dltPoints);

            case 'DKK'
                tempFile = config.RFR_Str_lists.connections.BBL.autoDKKReqFile;
                tickers = [config.RFR_basic_DKK_Ticker,...
                    config.RFR_basic_DKK_Duration_Ticker];
        end

        tickers = unique(tickers);
        % Remove the empty row or the placeholder '[]' in the list 
        % of tickers.
        tickers(strcmp(tickers, '') | strcmp(tickers, '[]')) = [];

        tempFile = fullfile(reqFileDir, tempFile);
        [~,name,ext] = fileparts(tempFile);
        name = strrep(name, 'mmmyyyy', datestr(refDate, 'mmmyyyy'));
        name = strrep(name, '_GEN', '');
        

        reqFile = fullfile(reqFileDir, strcat(name, ext));
        copyfile(tempFile, reqFile);

        reqData = fileread(reqFile);
        reqData = strrep(reqData, '$CALC_DATE$', datestr(refDate, 'mmmyyyy'));
        reqData = strrep(reqData, '$START_DATE$', datestr(startDate, 'yyyymmdd'));
        reqData = strrep(reqData, '$END_DATE$', datestr(endDate, 'yyyymmdd'));

        % Replace the $TICKERS$ template in the generated request files
        reqData = strrep(reqData, '$TICKERS$', strjoin(tickers, '\r\n'));
                        
        % Output file
        fid = fopen(reqFile, 'w');
        fprintf(fid, '%s', reqData);
        fclose(fid);
        
        % Search for the reply filename in the request data and append it
        % to the cell array of the return value.
        replyfilename = regexp(reqData, 'REPLYFILENAME=(.*?)\r\n', 'tokens');
        replyfilename = [replyfilename{:}];
        replyfilename = strcat(replyfilename,'.gz.',datestr(now, 'yyyymmdd'));
        
        % Before the upload happens, check if a reply file with the same name
        % already exists and if so, get the correct reply file name.
        listing = dir(c);
        fileAvailable = checkAvailability(replyfilename, listing);

        if fileAvailable
            ext = 0;

            while fileAvailable
                ext = ext + 1;
                fileAvailable = checkAvailability(strcat(replyfilename,'.',num2str(ext)),...
                    listing);
            end

            replyfilename = strcat(replyfilename,'.',num2str(ext));
        end
        
        replyfiles.(uploads{i}) = replyfilename;
        
        % Upload the file
        c.Connection.put(reqFile);

        info_message = ['Successfully uploaded ' strcat(name,ext) '!'];
        RFR_log_register('00_Upload', 'uploadBDLRequest', 'INFO',...
            info_message, config);

    end

    close(c);

    info_message = 'Finished the upload process...';            
    RFR_log_register('00_Upload', 'uploadBDLRequest', 'INFO',...
        info_message, config);

end