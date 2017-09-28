function name = getComputerName()
% GETCOMPUTERNAME returns the name of the computer (hostname)
% name = getComputerName()
%
% WARN: output string is converted to lower case
%
%
% See also SYSTEM, GETENV, ISPC, ISUNIX
%
% m j m a r i n j (AT) y a h o o (DOT) e s
% (c) MJMJ/2007
% MOD: MJMJ/2013

[ret, name] = system('hostname');   

if ret ~= 0,
   if ispc
      name = getenv('COMPUTERNAME');
   else      
      name = getenv('HOSTNAME');      
   end
else
    % exclude the extension 
    dot_ind = strfind(name,'.');
    if ~isempty(dot_ind)
        name = name(1:dot_ind(1)-1);
    end
end
name = strtrim(lower(name));

