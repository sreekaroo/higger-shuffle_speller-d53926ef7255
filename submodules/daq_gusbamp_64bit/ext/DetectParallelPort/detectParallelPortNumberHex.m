%% parallelPortNumber = detectParallelPortNumberHex()
%This function detects the parallel port IO address and returns the first
% IO address found in Hex format. This function needs administrator
% permissions, so to be able to use this function seamlessly you have
% to run your matlab session with administrator permissions otherwise,
% at each run of the function windows will ask weather to execute the
% application or not, WHICH CAUSES MAL-FUNCTION. You can also decrease the
% windows User Account Control setting to the lowest.
%
%   inputs:
%       beepOn - (optional) input to select to have beep sound on the
%           occurrence of errors detecting the parallel port IO address.
%           The default value is 1;
%
%   returns:
%       parallelPortNumber - The first IO address of the parallel port
%           adaptor in hex. It will be returned empty if no parallel port
%           is detected or in case of errors.
%
% Note1: You should start matlab with administrator permissions. (Read the
% above description for more help)
%
% Note2: This function is for x86 based machines not for IA64 bit machines.
% For IA64 bit machine you can use devconeIA64.exe and use this function
% with some minor modifications.
%
% Created by: Hooman Nezamfar 9-17-2012
% Tested with Matlab 2012a (32bit and 64 bit) & Matlab 2012b(64bit)
%


function parallelPortNumber = detectParallelPortNumberHex(beepOn)

try
    % parallelPortAdaptor = 'OX12PCI840';
    % Since the adaptor name doesn't show up on some computers the adaptor
    % name check has been removed.
    
    if ~nargin
        beepOn = 1; % Controls beep sound on errors.
    end
    
    SHIFT_INDEX = 5;% Number of characters to move after finding IO to
    % find the port number. The first port number found gets selected.
    
    pcType = computer;
    
    %% Check OS Type
    if strcmpi(pcType,'PCWIN') || strcmpi(pcType,'PCWIN64')
        devcon32Path = which('devcon32.exe');
        devcon32Path = devcon32Path(1:regexpi(devcon32Path,'\\devcon32.exe'));
        if strcmpi(devcon32Path,pwd)
            [failed, result] = system('devcon32 resources =ports');
            devconVersion = 32;
        elseif ~isempty(devcon32Path)
            currentPath = pwd;
            cd(devcon32Path);
            [failed, result] = system('devcon32 resources =ports');
            devconVersion = 32;
            cd(currentPath);            
        end
    else
        disp('Not a windows machine!')
        if beepOn, beep; end
        disp('This function is for windows machines only.')
        parallelPortNumber = [];
        return;
    end
    
    %% Detect port number of Windows machines
    if ~failed
        %% Look for parallel port adaptor
        parallelStrIndex = regexpi(result,'Parallel Port');
        if parallelStrIndex
            disp('Parallel Port Adaptor found.')
            portStrIndex = regexpi(result(parallelStrIndex:end),'IO');
            
            IOrange = textscan(result(parallelStrIndex + ...
                portStrIndex+SHIFT_INDEX :end),'%s',1,'Delimiter','-');
            parallelPortNumber = char(IOrange{1});
            disp(strcat('Parallel Port Hex Address : ',...
                parallelPortNumber))
            
        else
            disp('No parallel port adaptor(s) found!!!')
            if beepOn, beep; end
            parallelPortNumber = [];            
            
            %% Look for printer port adaptors
            printerStrIndex = regexpi(result,'Printer Port');
            if ~isempty(printerStrIndex) && isempty(parallelPortNumber)
                %             disp('Printer Port Adaptor found.')
                portStrIndex = regexpi(result(printerStrIndex:end),'IO');
                
                IOrange = textscan(result(printerStrIndex + ...
                    portStrIndex+SHIFT_INDEX :end),'%s',1,'Delimiter','-');
                parallelPortNumber = char(IOrange{1});
                disp(strcat('Printer port adaptor found with IO address: ',...
                    parallelPortNumber))
                if beepOn, beep; end
                usePrinterPort = ...
                    input('Do you want to use it instead? (y/n):','s');
                if strcmpi(usePrinterPort,'y')
                    disp(['Parallel Port Hex Address : ',...
                        parallelPortNumber])
                else
                    if beepOn, beep; end
                    parallelPortNumber = [];
                    disp('No parallel port number assigned!!!')
                end
                
            else
                disp('No printer port adaptor(s) found either!!!')
                disp(['Matlab might have been started without '...
                    ,'administrator permissions.'])
                if beepOn, beep; end
                parallelPortNumber = [];
            end
        end
        
    else
        if beepOn, beep; end
        switch devconVersion
            case 32
                disp('devcon32.exe is not found or it is corrupted.')
            otherwise
                disp('devconXX.exe is not found or it is corrupted.')
        end
        disp(['Please put the correct file along side with ',...
            'detectParallelPortNumber function.'])
        parallelPortNumber = [];
    end
    
catch ME
    if beepOn, beep; end
    parallelPortNumber = [];
    disp('Error(s) happened while trying to detect parallel port.')
    disp(['Error:',ME.message])
    disp(ME.stack)
end

end
