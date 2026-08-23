function RFR_02C_Downloads_Curves(config, settings)

    % Load the GVT data               
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;      
    file_storage    = 'RFR_basic_curves';     
    load(fullfile(folder_download, file_storage), 'RFR_download_BBL_Mid');

    % If no curves are to be imported, abort
    if size(config.RFR_basic_Curve_Tickers, 1) == 0
        info_message = 'No Curves to import. Aborting...';            

        RFR_log_register('01_Import', '02C_Download', 'WARNING',...
            info_message, config);
        return
    end
    
    % Maximum number of downloads per curve in case of non-DLTness
    RETRIES = 20;
    
    % Currencies (RFR_basic_Curve_Tickers contains currency/ticker pairs)
    CURRENCIES = config.RFR_basic_Curve_Tickers(:,1);
    % Curves
    CURVES = config.RFR_basic_Curve_Tickers(:,2);
    
    DLTCOUNTRIES = config.RFR_Str_lists.C2D_list_curncy(:, ...
        config.RFR_Str_lists.Str_numcol_curncy.ISO3166);
    DLTPOINTS = logical(cell2mat(config.RFR_basic_ADLT_GVT));
    
    %% Preparations
    import com.bloomberg.datalic.api.*;
    import com.bloomberg.datalic.util.*;
    import java.io.*;
    import java.lang.*;

    reqFileDir = config.RFR_Str_config.folders.path_RFR_00_Uploads;
    
    for i=1:length(CURVES)
        success = false;
        
        % startDate is currently unused but in case we are interested in all
        % rates in a certain range in the future, we could use it in the
        % request file generation
        startDate = config.refDate;
        endDate = config.refDate;
        
        if ~isbusday(endDate, NaN)
            startDate = busdate(startDate, 'previous', NaN);
            endDate = busdate(endDate, 'previous', NaN);
        end
    
        for j=1:RETRIES
            % Create the security list request file from the template
            secTemplate = config.RFR_Str_lists.connections.BBL.autoCRVSCSReqFile;
            secTemplate = fullfile(reqFileDir, secTemplate);

            [~,secReq,ext] = fileparts(secTemplate);
            secReq = strrep(secReq, 'mmmyyyy', datestr(endDate, 'mmmyyyy'));
            secReq = strrep(secReq, '_GEN', '');
            secReq = strcat(secReq, ext);
            secReqPath = fullfile(reqFileDir, secReq);

            copyfile(secTemplate, secReqPath);

            % Create the curve components request file from the template
            compTemplate = config.RFR_Str_lists.connections.BBL.autoCRVCMPReqFile;
            compTemplate = fullfile(reqFileDir, compTemplate);

            [~,compReq,ext] = fileparts(compTemplate);
            compReq = strrep(compReq, 'mmmyyyy', datestr(endDate, 'mmmyyyy'));
            compReq = strrep(compReq, '_GEN', '');
            compReq = strcat(compReq, ext);
            compReqPath = fullfile(reqFileDir, compReq);
            copyfile(compTemplate, compReqPath);

            % Fill in the name of the curves for which the constituents should be
            % downloaded.
            reqData = fileread(secReqPath);
            reqData = strrep(reqData, '$CURVES$', CURVES{i});
            reqData = strrep(reqData, '$CALC_DATE$', datestr(endDate, 'yyyymmdd'));

            % Get the reply file name
            secReplyFile = regexp(reqData, 'REPLYFILENAME=(.*?)\r\n', 'tokens');
            secReplyFile = strcat(secReplyFile{1},'.',datestr(now, 'yyyymmdd'));

            fid = fopen(secReqPath, 'w');
            fprintf(fid, '%s', reqData);
            fclose(fid);

            %% Connect to BDL, upload the constituent list request and get the output
            %disp('Connecting to BDL...');
            c = bdl(settings.user, settings.password, settings.host, settings.port, ...
                settings.decrypt);

            % Before the upload happens, check if a reply file with the same name
            % already exists and if so, get the correct reply file name.
            listing = dir(c);
            fileAvailable = checkAvailability(secReplyFile, listing);

            if fileAvailable
                ext = 0;

                while fileAvailable
                    ext = ext + 1;
                    fileAvailable = checkAvailability(strcat(secReplyFile,'.',num2str(ext)),...
                        listing);
                end

                secReplyFile = strcat(secReplyFile,'.',num2str(ext));
            end

            c.Connection.put(secReqPath);

            % Check availability of the new output file
            t = timer('TimerFcn', {@timerCallback,c,secReplyFile}, ...
                'Period', 30, 'StartDelay', 10, 'TasksToExecute', 10, 'ExecutionMode',...
                'FixedSpacing');
            start(t);
            wait(t);

            fileAvailable = get(t, 'UserData');
            delete(t);

            if ~fileAvailable
                info_message = 'Constituent list file not available on the FTP server. Aborting...';            

                RFR_log_register('01_Import', '02C_Download', 'ERROR',...
                    info_message, config);

                return
            end

            % Download the output
            secOutFile = fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads,...
                secReplyFile);

            c.Connection.get(secReplyFile, secOutFile);
            close(c);
            % BBL files are encrypted with DES and UUencoded
            % In principle, the c.Connection object should be able
            % to automatically download and decrypt the data with
            % c.Connection.getDES. However, this method is unstable
            % and not reliable.
            des = BBDES(c.DecryptCode);
            des.setuseCAPoption(true)
            des.setuuencode(true);

            decSecOut = strcat(secOutFile,'.dec');

            des.decryptDES(secOutFile, decSecOut);

            %% Parse constituents list
            bdlOutput = bdlloaderv2(char(decSecOut));
            bdlOutput = bdlOutput.CURVE_MEMBERS;

            curveNames = unique(bdlOutput(:,1));
            validCurveId = strrep(curveNames{i}, ' ', '_');

            % Determine the security tickers
            secs = regexp(bdlOutput(:,2), '^[A-Z]+.*$', 'match');
            secs = [secs{:}]';

            % Determine the terms
            terms = regexp(bdlOutput(:,2), '^(\d?\d)(M|Y)$', 'tokens');
            terms = [terms{:}]';
            terms = vertcat(terms{:});

            yearlyTerms = strcmp(terms(:,2), 'Y');
            curves(i).name = validCurveId;
            curves(i).constituents = secs(yearlyTerms,1);
            curves(i).terms = terms(yearlyTerms,1);


            %% Prepare constituents request file
            % Fill in the name of the constituents that should be downloaded.
            compData = fileread(compReqPath);

            compData = strrep(compData, '$START_DATE$', datestr(startDate, 'yyyymmdd'));
            compData = strrep(compData, '$END_DATE$', datestr(endDate, 'yyyymmdd'));
            compData = strrep(compData, '$CALC_DATE$', datestr(endDate, 'yyyymmdd'));
            compData = strrep(compData, '$COMPONENTS$', ...
                strjoin(vertcat(curves.constituents), '\r\n'));

            % Get the reply file name
            compReplyFile = regexp(compData, 'REPLYFILENAME=(.*?)\r\n', 'tokens');
            compReplyFile = strcat(compReplyFile{1},'.gz.',datestr(now, 'yyyymmdd'));

            fid = fopen(compReqPath, 'w');
            fprintf(fid, '%s', compData);
            fclose(fid);

            %% Connect to BDL, upload the constituents request and get the output
            c = bdl(settings.user, settings.password, settings.host, settings.port, ...
                settings.decrypt);

            listing = dir(c);
            fileAvailable = checkAvailability(compReplyFile, listing);

            if fileAvailable
                ext = 0;

                while fileAvailable
                    ext = ext + 1;
                    fileAvailable = checkAvailability(strcat(compReplyFile,'.',num2str(ext)),...
                        listing);
                end

                compReplyFile = strcat(compReplyFile,'.',num2str(ext));
            end

            c.Connection.put(compReqPath);

            % Check availability of the new output file
            t = timer('TimerFcn', {@timerCallback,c,compReplyFile}, ...
                'Period', 30, 'StartDelay', 10, 'TasksToExecute', 10, 'ExecutionMode',...
                'FixedSpacing');
            start(t);
            wait(t);

            fileAvailable = get(t, 'UserData');
            delete(t);

            if ~fileAvailable
               info_message = 'Component file not available on the FTP server. Aborting...';            

                RFR_log_register('01_Import', '02C_Download', 'ERROR',...
                    info_message, config);

                return
            end

            % Download the output
            compOutFile = fullfile(config.RFR_Str_config.folders.path_RFR_02_Downloads, compReplyFile);

            c.Connection.get(compReplyFile, compOutFile);
            close(c);

            des = BBDES(c.DecryptCode);
            des.setuseCAPoption(true)
            des.setuuencode(true);

            tmpOutput = strcat(compOutFile,'.dec.gz');

            des.decryptDES(compOutFile, tmpOutput);
            decCompOut = gunzip(tmpOutput);

            %% Parse security list
            secData = bdlloaderv2(char(decCompOut));

            % If the file doesn't contain any data, retry with the next
            % date.
            if ~isfield(secData, 'Data')
                info_message = ['Curves: No data available for ',curName,' on ',...
                    datestr(endDate, 'yyyymmdd'),'.'];            

                RFR_log_register('01_Import', '02C_Download', 'WARNING',...
                    info_message, config);
                
                % Reset the start and end date to look at the previous
                % business day
                startDate = busdate(startDate, 'previous', NaN);
                endDate = busdate(endDate, 'previous', NaN);
                continue
            end
            
            % Convert the dates from char to date
            secData.Data(:,2) = num2cell(datenum(secData.Data(:,2), 'dd-mmm-yy'));
            % Convert the price data from char to double
            secData.Data(:,3) = num2cell(str2double(secData.Data(:,3)));

            % Extract the price information into a matrix for each curve

            tickers = curves(i).constituents;
            [im,~] = ismember(secData.Data(:,1), tickers);

            dataTable = table(cell2mat(secData.Data(im,2)), cellstr(secData.Data(im,1)), ...
                cell2mat(secData.Data(im,3)), 'VariableNames', {'Date', 'Ticker', 'Price'});
            dataTable = unstack(dataTable, 'Price', 'Ticker');
            dataTable = sortrows(dataTable);

            % Transform the market data into an array with the standard size
            curves(i).marketData = zeros(size(dataTable, 1), 61);
            % Dates
            curves(i).marketData(:,1) = dataTable.Date;
            % Prices
            % Map the column names to maturities
            bondNames = dataTable.Properties.VariableNames(2:end);
            [~,locb] = ismember(bondNames, strrep(curves(i).constituents, ' ', ''));
            bondMats = str2double(curves(i).terms(locb));
            
            [~,locc] = ismember(strrep(curves(i).name,'_', ' '), CURVES);
            curName = CURRENCIES{locc};
            
            % ISK Maturity 10Y on BBL is actually a 8Y bond
            if strcmp(curName, 'ISK')
                bondMats(bondMats == 10) = 8;                
            end
            
            % Insert the market data
            curves(i).marketData(:,1+bondMats) = table2array(dataTable(:,2:end));

            % Replace NaNs with 0 to be consistent with the previous convention
            [nanRows,nanCols] = find(isnan(curves(i).marketData));

            if ~isempty(nanRows)
                linNanIdx = sub2ind(size(curves(i).marketData), nanRows, nanCols);
                curves(i).marketData(linNanIdx) = 0;
            end
            
            % Check if the at least 80% of the DLT points are available
            idx = find(strcmp(curName, DLTCOUNTRIES), 1);
            dltMats = DLTPOINTS(idx,:);
            
            availMats = false(1,60);
            availMats(bondMats) = true;
            
            % LLP available?
            llp = config.RFR_Str_lists.C2D_list_curncy{idx,...
                config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT};
            llpAvail = availMats(llp);
            
            % More than 80% available?
            dltAvail = sum(availMats & dltMats)/sum(dltMats) >= 0.8;
            
            % Check if the criteria are met and break
            if llpAvail && dltAvail
                success = true;
                break
            else
                info_message = ['Criteria not met for ',curName,' on ',...
                    datestr(endDate, 'yyyymmdd'),'.'];            

                RFR_log_register('01_Import', '02C_Download', 'WARNING',...
                    info_message, config);
                
                % Reset the start and end date to look at the previous
                % business day
                startDate = busdate(startDate, 'previous', NaN);
                endDate = busdate(endDate, 'previous', NaN);
            end
            
        end
        
        if success
            % Save the extracted data in the database
            [~,locc] = ismember(strrep(curves(i).name,'_', ' '), CURVES);
            gvtName = [CURRENCIES{locc},'_RAW_GVT_BBL'];

            % Overwrite existing data
            [ia,locb] = ismember(curves(i).marketData(:,1), RFR_download_BBL_Mid.(gvtName)(:,1));
            RFR_download_BBL_Mid.(gvtName)(locb(ia),2:(size(curves(i).marketData, 2))) = curves(i).marketData(ia,2:end);

            % Extend the array with new data (if there is new data)
            if any(~ia)
                extension = zeros(sum(~ia), size(RFR_download_BBL_Mid.(gvtName), 2));
                extension(:,1:(size(curves(i).marketData, 2))) = curves(i).marketData(~ia,:);
                RFR_download_BBL_Mid.(gvtName) = ...
                    [RFR_download_BBL_Mid.(gvtName);extension];
                RFR_download_BBL_Mid.(gvtName) = sortrows(RFR_download_BBL_Mid.(gvtName));
            end
        else
            info_message = ['Couldn''t get data for ',curName,'.'];         

            RFR_log_register('01_Import', '02C_Download', 'ERROR',...
                    info_message, config);
        end
            
    end

    save(fullfile(folder_download, 'RFR_basic_curves'), 'RFR_download_BBL_Mid',...
             '-append');
    
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