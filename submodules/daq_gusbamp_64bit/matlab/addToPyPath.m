function addToPyPath(targetFile, varargin)
% adds a folder containing targetFile (on MATLAB search path) to python
% path
%
% Input:
%   targetFile = str, any file in the folder which is to be added to python
%               path

p = inputParser;
p.addRequired('targetFile', @ischar);
p.addParameter('verbose', true, @islogical);
p.parse(targetFile, varargin{:});

% get name of folder to be added to python path
fullPath = which(targetFile);
if isempty(fullPath)
    error([targetFile, ' not found on MATLAB path'])
end
[pathstr, ~, ~] = fileparts(fullPath);

% import sys, check if this folder is already in the python pathsys =
sys =  py.importlib.import_module('sys');
workspace = py.dict(pyargs('path', sys.path, 'pathstr', pathstr));

if ~py.eval('pathstr in path', workspace)
    % if not on path, add it
    sys.path.insert(int32(1), pathstr)
    
elseif p.Results.verbose
    % if already on path throw warning
    warning([pathstr, ' already on python path, will not add']);
    
end


end

