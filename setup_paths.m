%SETUP_PATHS Add the project folders to the MATLAB path.
%   Run once per MATLAB session, from any folder:
%       run('path/to/repo/setup_paths.m')

project_root = fileparts(mfilename('fullpath'));

project_dirs = [ ...
    strsplit(genpath(fullfile(project_root, 'matlab')),   pathsep), ...
    strsplit(genpath(fullfile(project_root, 'simulink')), pathsep)];

% Never put build artifacts on the path
is_build_dir = contains(project_dirs, {'slprj', '_ert_rtw', '_grt_rtw', 'codegen'});
project_dirs = project_dirs(~cellfun(@isempty, project_dirs) & ~is_build_dir);

addpath(project_root);       % config.m
addpath(project_dirs{:});

fprintf('Four-bar project paths added (root: %s)\n', project_root);
clear project_root project_dirs is_build_dir
