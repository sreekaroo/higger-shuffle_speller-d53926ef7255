classdef TriggerParallel < Trigger
    % TriggerParallel class for parallel port triggering scheme
    
    properties
        
        % Parallel port number
        decParallelPortNumber
        
        % Flag for 64 bit vs 32 bit
        is64bitComputer
        
    end
    
    methods 
        
        function self = TriggerParallel()
            
            self = self@Trigger();
            
            % Initialize the parallel port for sending the trigger signal
            % Add stuff to path
            mfilepath=fileparts(which('TriggerParallel.m'));
            addpath(genpath(fullfile(mfilepath,'../ext')));

            % Get parallel port number
            self.decParallelPortNumber = hex2dec(detectParallelPortNumberHex());

            if isempty(self.decParallelPortNumber)
                warning('No parallel port is detected.');
            end
            
            [~,maxArraySize] = computer; 
            self.is64bitComputer = maxArraySize> 2^31;

            % Load inpout library
            if self.is64bitComputer
                loadlibrary('inpoutx64','inpout32.h');
            else
                loadlibrary('inpout32','inpout32.h');
            end
            
            self.SendTrigger(0);
        
        end
        
        function SendTrigger(self, value)
            % Sends marker to trigger channels
            
            if ~isempty(self.decParallelPortNumber)
                if self.is64bitComputer    
                    calllib('inpoutx64','Out32',self.decParallelPortNumber, value);
                else
                    calllib('inpout32','Out32',self.decParallelPortNumber, value);
                end
            end
        end
        
        function delete(self)
            if self.is64bitComputer
                % unloadlibrary('inpoutx64');
            else
                % unloadlibrary('inpout32');
            end
        end
        
    end

end

