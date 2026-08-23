function [outputFile] = downloadBDLOutput(settings, dataFile, outputPath, trials)
%DOWNLOADBDLOUTPUT Downloads output files from Bloomberg Data License FTP.
% 
%   This function connects to the Bloomberg Data License FTP server and
%   downloads the given request output file. Additionally, it decodes the
%   DES and UUEncoded files.
%   
%   OUTPUTFILE = DOWNLOADBDLOUTPUT(SETTINGS, DATAFILE, OUTPUTPATH)
%
%   Inputs:
%   SETTINGS   - structure containing the char array fields
%                 * user - BBL DL user name
%                 * password - BBL DL password
%                 * host - BBL DL hostname
%                 * port - BBL DL port
%                 * decrypt - BBL DL DES decryption phrase
%   DATAFILE   - name of the file to download
%   OUTPUTPATH - char array path where the downloaded and decrypted files
%                should be stored.
%
%   Outputs:
%   OUTPUTFILE - Path to the decrypted BBL DL output file.
%
    import com.bloomberg.datalic.api.*;
    import com.bloomberg.datalic.util.*;
    import java.io.*;
    import java.lang.*;
    
    if nargin < 4 || trials <= 0
        trials = 1;
    end
    
    outputFile = fullfile(outputPath, dataFile);
    
    c = bdl(settings.user,settings.password,settings.host,settings.port,...
        settings.decrypt);                     
    
    % Check availability of the new output file
    t = timer('TimerFcn', {@timerCallback,c,dataFile}, ...
        'Period', 30, 'StartDelay', 10, 'TasksToExecute', trials, 'ExecutionMode',...
        'FixedSpacing');
    start(t);
    wait(t);

    fileAvailable = get(t, 'UserData');
    delete(t);

    if ~fileAvailable
       info_message = 'Component file not available on the FTP server. Aborting...';            

        RFR_log_register('01_Import', 'downloadBDLOutput', 'ERROR',...
            info_message, config);

        return
    end
            
    c.Connection.get(dataFile, outputFile);

    % BBL files are encrypted with DES and UUencoded
    % In principle, the c.Connection object should be able
    % to automatically download and decrypt the data with
    % c.Connection.getDES. However, this method is unstable
    % and not reliable.
    des = BBDES(c.DecryptCode);
    des.setuseCAPoption(true)
    des.setuuencode(true);

    % Determine if file is gzipped
    % Assume encryption is always used.
    gzipped = ~isempty(strfind(outputFile,'.gz'));

    tmpOutput = strcat(outputFile,'.dec');

    if gzipped
        des.decryptDES(outputFile, tmpOutput);
        newOutputFile = gunzip(tmpOutput);
        outputFile = newOutputFile;
    else
        des.decryptDES(outputFile, tmpOutput);
        outputFile = tmpOutput;
    end
        
    close(c);
end

% Timer callback for checking if a file is available on the BBL FTP server
function timerCallback(timer, event, connection, filename)
    fileAvailable = checkAvailability(filename, dir(connection));
    
    if fileAvailable
        set(timer, 'UserData', true);
        stop(timer);
    else
        set(timer, 'UserData', false);
    end
end
