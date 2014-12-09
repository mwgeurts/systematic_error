function AutoSystematicError()
% AutoSystematicError scans for patient archives in a preset directory 
% (given by the variable inputDir below) and runs the systematic error 
% workflow (load plan, calc dose, modify plan, calc dose, compute metrics) 
% for each plan found. A line containing the high level results is appended 
% to the .csv file specified in the variable resultsCSV, with the DVHs
% saved to the directory specified in the variable dvhDir below.
% Individual comparison metrics are stored to the directory specified in
% the variable metricDir.
%
% If an entry already exists for the patient archive (determined by SHA1
% signature) and plan (determined by UID), the workflow will be skipped.
% In this manner, AutoSystematicError can be run multiple times to analyze 
% a large directory of archives.
%
% The resultsCSV file contains the following columns:
%   {1}: Full path to patient archive _patient.xml.  However, if 
%       the variable anon is set to TRUE, will be empty.
%   {2}: SHA1 signature of _patient.xml file
%   {3}: Plan UID
%   {4}: Atlas category (HN, Brain, Thorax, Abdomen, Pelvis)
%   {5}: Number of structures loaded (helpful when loading DVH .csv files)
%   {6}: Number of plan modifications computed
%   {7}: Number of plan metrics computed
%   {8}: Time (in seconds) to run entire workflow
%   {9}: Version number of AutoSystematicError when plan was run
%
% The dvhDir contains a .csv file for each reference and modified plan dose
% in the following format. The name for each .csv file follows the
% convention 'planuid_calc.csv', where planuid is the Plan UID and calc is
% either 'reference' or the name of the modification (see below for a full
% list of modifications)
%
% ...
%
% The metricDir contains a .csv file for each metric computed below in the
% following columns, where the first row contains a list of each plan
% modification (see below for a full list of modifications):
%   {1}: Plan UID
%   {2}: Atlas category
%   {3}: Metric for the reference plan dose
%   {3+n}: Metrics for all n plan modifications
%
% Copyright (C) 2014 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

%% Set runtime variables
% Turn off MATLAB warnings
warning('off','all');

% Anonymous flag.  If true, only the archive XML SHA1 signature and MVCT 
% UID will be stored, and no additinal patient identifying information will
% be included in the results
anon = false;

% Set the input directory.  This directory will be scanned for patient
% archives during execution of AutoDIGRT
inputDir = '/media/mgeurts/My Book/Study_Data/';

% Set the .csv file where the results summary will be appended
resultsCSV = '../Study_Results/Results.csv';

% Set the directory where each DVH .csv will be stored
dvhDir = '../Study_Results/DVHs/';

% Set the directory where each metric .csv will be stored
metricDir = '../Study_Results/';

% Set version handle
version = '1.0.0';

%% Initialize Log
% Set version information.  See LoadVersionInfo for more details.
versionInfo = LoadVersionInfo;

% Store program and MATLAB/etc version information as a string cell array
string = {'TomoTherapy Systematic Error Simulation Tool'
    sprintf('Version: %s (%s)', version, versionInfo{6});
    sprintf('Author: Mark Geurts <mark.w.geurts@gmail.com>');
    sprintf('MATLAB Version: %s', versionInfo{2});
    sprintf('MATLAB License Number: %s', versionInfo{3});
    sprintf('Operating System: %s', versionInfo{1});
    sprintf('CUDA: %s', versionInfo{4});
    sprintf('Java Version: %s', versionInfo{5})
};

% Add dashed line separators      
separator = repmat('-', 1,  size(char(string), 2));
string = sprintf('%s\n', separator, string{:}, separator);

% Log information
Event(string, 'INIT');

% Clear temporary variables
clear string separator;

%% Load Results .csv
% Open file handle to current results set
fid = fopen(resultsCSV,'r');

% If a valid file handle was returned
if fid > 0
    % Log loading of existing results
    Event('Found results file');
    
    % Scan results .csv file for the following format of columns (see
    % documentation above for the results file format)
    results = textscan(fid, '%s %s %s %s %s %s %s %s %s', ...
        'Delimiter', {','}, 'commentStyle', '#');
    
    % Close the file handle
    fclose(fid);
    
    % Log completion
    Event(sprintf('%i results loaded from %s', size(results{1}, 1) - 1, ...
        resultsCSV));

% Otherwise, create new results file, saving column headers
else
    % Log generation of new file
    Event(['Generating new results file ', resultsCSV]);
    
    % Open write file handle to current results set
    fid = fopen(resultsCSV, 'w');
    
    % Print version information
    fprintf(fid, '# TomoTherapy Systematic Error Simulation Tool\n');
    fprintf(fid, '# Author: Mark Geurts <mark.w.geurts@gmail.com>\n');
    fprintf(fid, ['# See AutoSystematicError.m and README.md for ', ...
        'more information on the format of this results file\n']);
    
    % Print column headers
    fprintf(fid, 'Archive,');
    fprintf(fid, 'SHA1,');
    fprintf(fid, 'Plan UID,');
    fprintf(fid, 'Plan Type,');
    fprintf(fid, 'Structures,');
    fprintf(fid, 'Modifications,');
    fprintf(fid, 'Metrics,');
    fprintf(fid, 'Time,');
    fprintf(fid, 'Version\n');

    % Close the file handle
    fclose(fid);
end

% Clear file hande
clear fid;

%% Load atlas
atlas = LoadAtlas('atlas.xml');

%% Load plan modifications
Event('Loading plan modification functions');

% Declare modification cell array. The first column is the shorthand
% description of the modification, the second is the function name, and the
% third is an optional argument passed to the function
modifications = {
    'mlc32open'     'ModifyMLCLeafOpen' '32'
    'mlc42open'     'ModifyMLCLeafOpen' '42'
    'mlcrand2pct'   'ModifyMLCRandom'   '2'
    'mlcrand4pct'   'ModifyMLCRandom'   '4'
    'couch+0.5pct'  'ModifyCouchSpeed'  '0.5'
    'couch+1.0pct'  'ModifyCouchSpeed'  '1.0'
};

% Loop through each modification
for i = 1:size(modifications, 1)
    
    % Verify that the function exists
    if exist(modifications{i,2}, 'file') == 0
        Event(sprintf('Plan modification function %s not found', ...
            modifications{i,2}), 'ERROR');
    end
end
  
% Log number of modifications loaded
Event(sprintf('%i functions successfully loaded', size(modifications, 1)));
                
%% Load metrics
Event('Loading plan metric functions');

% Declare metric cell array. The first column is the shorthand
% description of the metric, the second is the function name, the third is 
% an optional arguments passed to the function, and the fourth is a list of 
% atlas categories for which the metric should be calculated.  Multiple
% arguments can be separated by a forward slash (/).
If the atlas
% category is empty, all categories will be calculated
metrics = {
    'gamma2pct1mm'  'CalcGammaMetric'   '2/1'           ''
    'cordmax'       'CalcStructureStat' 'Cord/Max'      'HeadNeck'
    'parotidmean'   'CalcStructureStat' 'Parotid/Mean'  'HeadNeck'
    'targetdx95'    'CalcStructureStat' 'Target/d95'    ''
};

% Loop through each metric
for i = 1:size(metrics, 1)
    
    % Verify that the function exists
    if exist(metrics{i,2}, 'file') == 0
        Event(sprintf('Metric calculation function %s not found', ...
            metrics{i,2}), 'ERROR');
    end
end

% Log number of modifications loaded
Event(sprintf('%i functions successfully loaded', size(metrics, 1)));

%% Start scanning for archives
% Note beginning execution
Event(['AutoSystematicError beginning search of ', inputDir, ...
    ' for patient archives']);

% Retrieve folder contents of input directory
folderList = dir(inputDir);

% Shuffle random number generator seed
rng shuffle;

% Randomize order of folder list
folderList = folderList(randperm(size(folderList, 1)), :);

% Initialize folder counter
i = 0;

% Initialize daily image counter
count = 0;

% Start AutoSystematicError timer
totalTimer = tic;

% Start recursive loop through each folder, subfolder
while i < size(folderList, 1)
    
    % Increment current folder being analyzed
    i = i + 1;
    
    % If the folder content is . or .., skip to next folder in list
    if strcmp(folderList(i).name,'.') || strcmp(folderList(i).name,'..')
        continue
        
    % Otherwise, if the folder content is a subfolder    
    elseif folderList(i).isdir == 1
        % Retrieve the subfolder contents
        subFolderList = dir(fullfile(inputDir, folderList(i).name));
        
        % Randomize order of subfolder list
        subFolderList = subFolderList(randperm(size(subFolderList, 1)), :);
        
        % Look through the subfolder contents
        for j = 1:size(subFolderList, 1)
            
            % If the subfolder content is . or .., skip to next subfolder 
            if strcmp(subFolderList(j).name, '.') || ...
                    strcmp(subFolderList(j).name, '..')
                continue
            else
                % Otherwise, replace the subfolder name with its full
                % reference
                subFolderList(j).name = fullfile(folderList(i).name, ...
                    subFolderList(j).name);
            end
        end
        
        % Append the subfolder contents to the main folder list
        folderList = vertcat(folderList, subFolderList); %#ok<AGROW>
        
        % Clear temporary variable
        clear subFolderList;
        
    % Otherwise, if the folder content is a patient archive
    elseif size(strfind(folderList(i).name, '_patient.xml'), 1) > 0
        
        % Generate a SHA1 signature for the archive patient XML file using
        % the shasum system command
        [~, cmdout] = system(['shasum "', ...
            fullfile(inputDir, folderList(i).name), '"']);
        
        % Save just the 40-character signature
        sha = cmdout(1:40);
        
        % Log patient XML and SHA1 signature
        Event(['Found patient archive ', folderList(i).name, ...
            ' with SHA1 signature ', sha]);
        
        % Clear temporary variable
        clear cmdout;

        % Generate separate path and names for XML
        [path, name, ext] = ...
            fileparts(fullfile(inputDir, folderList(i).name));
        
        % Search for and load all approvedPlans in the archive
        approvedPlans = FindPlans(path, strcat(name, ext));
        
        % Loop through each registered daily image
        Event('Looping through each approved plan');
        for j = 1:size(approvedPlans, 2)
            
            % Initialize flag to indicate whether the current daily image
            % already contains contents in resultsCSV
            found = false;
            
            % If the results .csv exists and was loaded above
            if exist('results', 'var')
                
                % Loop through each result
                for k = 2:size(results{1},1)
                    
                    % If the XML SHA1 signature, plan UID, number of 
                    % modifications/metrics match
                    if strcmp(results{2}{k}, sha) && ...
                            strcmp(results{3}{k}, approvedPlans{j}.UID) && ...
                            str2double(results{6}{k}) == ...
                            size(modifications,1) && ...
                            str2double(results{7}{k}) == size(metrics,1)
                        
                        % Set the flag to true, since a match was found
                        found = true;
                        
                        % Break the loop to stop searching
                        break;
                    end
                end
                
                % Clear temporary variable
                clear k;
            end
            
            % If results do not exist for this daily image
            if ~found
                
                % Attempt to run Systematic Error workflow
                try 
                    
                %%%%%%%%%%%
                %
                % Add code here
                %
                %%%%%%%%%%%
                     
                % If an error is thrown, catch
                catch exception
                    
                    % Report exception to error log
                    Event(getReport(exception, 'extended', 'hyperlinks', ...
                        'off'), 'CATCH');
                   
                    % Continue to next image set
                    continue;
                end
            else
                % Otherwise, matching data was found in resultsCSV
                Event(['UID ', approvedPlans{j}.UID, ...
                    ' skipped as results were found in ', resultsCSV]);
            end
        end
        
        % Clear temporary variables
        clear path name ext;
    end 
end

% Log completion of script
Event(sprintf(['AutoSystematicError completed in %0.0f minutes, ', ...
    'processing %i plans'], toc(totalTimer)/60, count));

% Clear temporary variables
clear i j totalTimer count;

