classdef Trigger < handle
    % Base class for trigger classes
    
    properties
    end
    
    methods (Abstract)
        
        % Creates marker on trigger channel (could be timestamps)
        SendTrigger(value)
        
    end
    
end

