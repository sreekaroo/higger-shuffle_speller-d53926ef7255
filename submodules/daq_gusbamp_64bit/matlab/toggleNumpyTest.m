clear classes;
clear;
clc;
close all;

% you should have python installed
pyversion;

% adds current folder to MATLAB's python search path (kludge: current
% folder must contain langModelMod)
if count(py.sys.path,'') == 0
    insert(py.sys.path,int32(0),'');
end

% Reload python module

mod = py.importlib.import_module('toggleNumpyTest');

if strcmp(pyversion, '2.7')
    py.reload(mod);    
elseif strcmp(pyversion, '3.5')
    py.importlib.reload(mod);
end

% Generate dummy data
Y(:,:,1) = [1:4; 5:8];
Y(:,:,2) = Y(:,:,1)+8;
Y(:,:,3) = Y(:,:,1)+16;

X = Y;

% Transfer data. Python function prints so we get a sense that the output
% is laid out the same
outputCell = py.toggleNumpyTest.testTransfer(toggleNumpy(X));
Xpy = toggleNumpy(outputCell{1});
Ypy = toggleNumpy(outputCell{2});

% Compare
assert(all(Xpy(:) == X(:)), 'X is not the same')
assert(all(Ypy(:) == Y(:)), 'Y is not the same')