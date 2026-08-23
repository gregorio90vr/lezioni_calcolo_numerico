function [V1C_new_yields,V1C_new_dates,V1C_new_durations] = ...
                    RFR_05_DKK_covered_bonds_BBL(source, settings)
                          
    % Download / import the BBL DL data
    
    % In case of 'BDL', download and decrypt the files
    if strcmp(source, 'BDL')
       settings = downloadBDLOutput(settings, settings.outputfiles.DKK, ...
           settings.dlPath, 10); 
       settings = char(settings);
    end
    
    bblData = parseBDLHistory(bdlloader(settings), 'weekdays');
    
    V1C_new_dates = datenum(bblData.Date);
    V1C_new_yields = bblData{:,'NYKROYTM_Index'};
    V1C_new_durations = bblData{:,'NYKRRYTM_Index'};
        
end