function [hash] = getHashOfFile(filename)
%GETHASHOFFILE Calculates the MD5 hash of a file
% GETHASHOFFILE(FILENAME) calculates the MD5 hash of a file referenced by
% FILENAME (absolute or relative path).
%
% HASH = GETHASHOFFILE(FILENAME) returns the MD5 hash as a character array.

    mddigest   = java.security.MessageDigest.getInstance('MD5'); 
    
    bufsize = 8192;

    fid = fopen(filename);

    while ~feof(fid)
        [currData,len] = fread(fid, bufsize, '*uint8');       
        if ~isempty(currData)
            mddigest.update(currData, 0, len);
        end
    end

    fclose(fid);

    hash = reshape(dec2hex(typecast(mddigest.digest(),'uint8'))',1,[]);

end