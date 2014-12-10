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
% Each modification is computed by executing an feval call to the function
% name specified in the variable modifications.  The function will be
% called with multiple input arguments, as shown below where str is a
% variable number ('/' delimited) of input arguments stored in 
% modifications{i,3}. The return variable must be the modified delivery 
% plan:
%
%   modPlan = feval(modifications{i,2}, referencePlan, modifications{i,3});
%
% If multiple '/' delimited arguments exist, they will be called as
% separate arguments in feval, as shown below for two arguments:
%
%   str = strsplit(modifications{i,3}, '/');
%   modPlan = feval(modifications{i,2}, referencePlan, str(1), str(2));
%
% Similarly, metrics are computed by executing an feval call to the
% function name specified in the variable metrics:
%
%   metric = feval(metrics{i,2}, image, refDose, modDose, altas, ...
%       metrics{i,3}); 
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
% list of modifications). The first row contains the file name, the second 
% row contains column headers for each structure set (including the volume
% in cc in parentheses), with each subsequent row containing the percent
% volume of each structure at or above the dose specified in the first
% column (in Gy).  The resolution is determined by dividing the maximum
% dose by 1001.
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
% archives during execution of AutoSystematicError
inputDir = '/Volumes/Macintosh HD/Users/Shared/Test_Data/';

% Set the .csv file where the results summary will be appended
resultsCSV = '../Study_Results/Results.csv';

% Set the directory where each DVH .csv will be stored
dvhDir = '../Study_Results/DVHs/';

% Set the directory where each metric .csv will be stored
metricDir = '../Study_Results/';

% Set version handle
version = '1.0.0';

% Determine path of current application
[path, ~, ~] = fileparts(mfilename('fullpath'));

% Set current directory to location of this application
cd(path);

% Clear temporary variable
clear path;

%% Initialize Log
% Set version information.  See LoadVersionInfo for more details.
versionInfo = LoadVersionInfo;

% Store program and MATLAB/etc version information as a string cell array
string = {'TomoTherapy FMEA Simulation Tool'
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
% Open file handle to current results .csv set
fid = fopen(resultsCSV, 'r');

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
    fprintf(fid, '# TomoTherapy FMEA Simulation Tool\n');
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
% third is optional arguments passed to the function. Multiple arguments 
% can be separated by a forward slash (/).
modifications = {
    'mlc32open'     'ModifyMLCLeafOpen' '32'
    'mlc42open'     'ModifyMLCLeafOpen' '42'
    'mlcrand2pct'   'ModifyMLCRandom'   '2'
    'mlcrand4pct'   'ModifyMLCRandom'   '4'
    'couch-5.0pct'  'ModifyCouchSpeed'  '-5.0'
    'couch-4.5pct'  'ModifyCouchSpeed'  '-4.5'
    'couch-4.0pct'  'ModifyCouchSpeed'  '-4.0'
    'couch-3.5pct'  'ModifyCouchSpeed'  '-3.5'
    'couch-3.0pct'  'ModifyCouchSpeed'  '-3.0'
    'couch-2.5pct'  'ModifyCouchSpeed'  '-2.5'
    'couch-2.0pct'  'ModifyCouchSpeed'  '-2.0'
    'couch-1.5pct'  'ModifyCouchSpeed'  '-1.5'
    'couch-1.0pct'  'ModifyCouchSpeed'  '-1.0'
    'couch-0.5pct'  'ModifyCouchSpeed'  '-0.5'
    'couch+0.5pct'  'ModifyCouchSpeed'  '0.5'
    'couch+1.0pct'  'ModifyCouchSpeed'  '1.0'
    'couch+1.5pct'  'ModifyCouchSpeed'  '1.5'
    'couch+2.0pct'  'ModifyCouchSpeed'  '2.0'
    'couch+2.5pct'  'ModifyCouchSpeed'  '2.5'
    'couch+3.0pct'  'ModifyCouchSpeed'  '3.0'
    'couch+3.5pct'  'ModifyCouchSpeed'  '3.5'
    'couch+4.0pct'  'ModifyCouchSpeed'  '4.0'
    'couch+4.5pct'  'ModifyCouchSpeed'  '4.5'
    'gantry-5.0deg' 'ModifyGantryAngle' '-5.0'
    'gantry-4.5deg' 'ModifyGantryAngle' '-4.5'
    'gantry-4.0deg' 'ModifyGantryAngle' '-4.0'
    'gantry-3.5deg' 'ModifyGantryAngle' '-3.5'
    'gantry-3.0deg' 'ModifyGantryAngle' '-3.0'
    'gantry-2.5deg' 'ModifyGantryAngle' '-2.5'
    'gantry-2.0deg' 'ModifyGantryAngle' '-2.0'
    'gantry-1.5deg' 'ModifyGantryAngle' '-1.5'
    'gantry-1.0deg' 'ModifyGantryAngle' '-1.0'
    'gantry-0.5deg' 'ModifyGantryAngle' '-0.5'
    'gantry+0.5deg' 'ModifyGantryAngle' '0.5'
    'gantry+1.0deg' 'ModifyGantryAngle' '1.0'
    'gantry+1.5deg' 'ModifyGantryAngle' '1.5'
    'gantry+2.0deg' 'ModifyGantryAngle' '2.0'
    'gantry+2.5deg' 'ModifyGantryAngle' '2.5'
    'gantry+3.0deg' 'ModifyGantryAngle' '3.0'
    'gantry+3.5deg' 'ModifyGantryAngle' '3.5'
    'gantry+4.0deg' 'ModifyGantryAngle' '4.0'
    'gantry+4.5deg' 'ModifyGantryAngle' '4.5'
    'gantry+5.0deg' 'ModifyGantryAngle' '5.0'
    'gantry-1.0ds'  'ModifyGantryRate'  '-1.0'
    'gantry-0.8ds'  'ModifyGantryRate'  '-0.8'
    'gantry-0.6ds'  'ModifyGantryRate'  '-0.6'
    'gantry-0.4ds'  'ModifyGantryRate'  '-0.4'
    'gantry-0.2ds'  'ModifyGantryRate'  '-0.2'
    'gantry+0.2ds'  'ModifyGantryRate'  '0.2'
    'gantry+0.4ds'  'ModifyGantryRate'  '0.4'
    'gantry+0.6ds'  'ModifyGantryRate'  '0.6'
    'gantry+0.8ds'  'ModifyGantryRate'  '0.8'
    'gantry+1.0ds'  'ModifyGantryRate'  '1.0'
    'jawf-3.0mm'    'ModifyJawFront'    '-3.0'
    'jawf-2.5mm'    'ModifyJawFront'    '-2.5'
    'jawf-2.0mm'    'ModifyJawFront'    '-2.0'
    'jawf-1.5mm'    'ModifyJawFront'    '-1.5'
    'jawf-1.0mm'    'ModifyJawFront'    '-1.0'
    'jawf-0.5mm'    'ModifyJawFront'    '-0.5'
    'jawf+0.5mm'    'ModifyJawFront'    '0.5'
    'jawf+1.0mm'    'ModifyJawFront'    '1.0'
    'jawf+1.5mm'    'ModifyJawFront'    '1.5'
    'jawf+2.0mm'    'ModifyJawFront'    '2.0'
    'jawf+2.5mm'    'ModifyJawFront'    '2.5'
    'jawf+3.0mm'    'ModifyJawFront'    '3.0'
    'jawb-3.0mm'    'ModifyJawBack'    '-3.0'
    'jawb-2.5mm'    'ModifyJawBack'    '-2.5'
    'jawb-2.0mm'    'ModifyJawBack'    '-2.0'
    'jawb-1.5mm'    'ModifyJawBack'    '-1.5'
    'jawb-1.0mm'    'ModifyJawBack'    '-1.0'
    'jawb-0.5mm'    'ModifyJawBack'    '-0.5'
    'jawb+0.5mm'    'ModifyJawBack'    '0.5'
    'jawb+1.0mm'    'ModifyJawBack'    '1.0'
    'jawb+1.5mm'    'ModifyJawBack'    '1.5'
    'jawb+2.0mm'    'ModifyJawBack'    '2.0'
    'jawb+2.5mm'    'ModifyJawBack'    '2.5'
    'jawb+3.0mm'    'ModifyJawBack'    '3.0'
};

% Loop through each modification
for i = 1:size(modifications, 1)
    
    % Verify that the function exists
    if exist(modifications{i,2}, 'file') == 0
        
        % If not, throw an error
        Event(sprintf('Plan modification function %s not found', ...
            modifications{i,2}), 'ERROR');
    end
end

% Clear temporary variable
clear i;
  
% Log number of modifications loaded
Event(sprintf('%i functions successfully loaded', size(modifications, 1)));
                
%% Load metrics
Event('Loading plan metric functions');

% Declare metric cell array. The first column is the shorthand
% description of the metric, the second is the function name, the third is 
% optional arguments passed to the function, and the fourth is a list of 
% atlas categories for which the metric should be calculated.  Multiple
% arguments can be separated by a forward slash (/). If the atlas
% category is empty, all categories will be calculated
metrics = {
    'gamma2pct1mm'  'CalcGammaMetric'   '2/1'           ''
    'cordmax'       'CalcStructureStat' 'Cord/Max'      'HeadNeck'
    'parotidmean'   'CalcStructureStat' 'Parotid/Mean'  'HeadNeck'
    'targetdx95'    'CalcStructureStat' 'PTV/D95'       ''
};

% Loop through each metric
for i = 1:size(metrics, 1)
    
    % Verify that the function exists
    if exist(metrics{i,2}, 'file') == 0
        
        % If not, throw an error
        Event(sprintf('Metric calculation function %s not found', ...
            metrics{i,2}), 'ERROR');
    end
    
    % Open file handle to current metric .csv data
    fid = fopen(fullfile(metricDir, strcat(metrics{i,1}, '.csv')), 'r');
    
    % If a valid file handle was returned
    if fid > 0

        % Log loading of existing results
        Event(sprintf('Found metric file %s.csv', metrics{i,1}));
    
    % Otherwise, create new results file, saving column headers
    else
        % Log generation of new file
        Event(['Generating new results file ', resultsCSV]);

        % Open write file handle to metric .csv
        fid = ...
            fopen(fullfile(metricDir, strcat(metrics{i,1}, '.csv')), 'w');
        
        % Print column headers
        fprintf(fid, 'Plan UID,');
        fprintf(fid, 'Category,');
        fprintf(fid, 'Reference,');
        
        % Loop through each plan modification
        for j = 1:size(modifications, 1)
            fprintf(fid, '%s,', modifications{j,1});
        end
        fprintf(fid, '\n');

        % Close the file handle
        fclose(fid);
    end
    
    % Clear temporary variables
    clear fid;
end

% Clear temporary variables
clear i j;

% Log number of modifications loaded
Event(sprintf('%i functions successfully loaded', size(metrics, 1)));

%% Load SSH/SCP Scripts
% A try/catch statement is used in case Ganymed-SSH2 is not available
try
    
    % Load Ganymed-SSH2 javalib
    Event('Adding Ganymed-SSH2 javalib');
    addpath('../ssh2_v2_m1_r6/'); 
    Event('Ganymed-SSH2 javalib added successfully');
    
    % Establish connection to computation server.  The ssh2_config
    % parameters below should be set to the DNS/IP address of the
    % computation server, user name, and password with SSH/SCP and
    % read/write access, respectively.  See the README for more infomation
    Event('Connecting to tomo-research via SSH2');
    ssh2 = ssh2_config('tomo-research', 'tomo', 'hi-art');
    
    % Test the SSH2 connection.  If this fails, catch the error below.
    [ssh2, ~] = ssh2_command(ssh2, 'ls');
    Event('SSH2 connection successfully established');

% addpath, ssh2_config, or ssh2_command may all fail if ganymed is not
% available or if the remote server is not responding
catch err
    
    % Log failure
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
  
end

%% Add CalcGamma submodule
% Add gamma submodule to search path
addpath('./gamma');

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

% Initialize plan counter
count = 0;

% Start AutoSystematicError timer
totalTimer = tic;

% Start recursive loop through each folder, subfolder
while i < size(folderList, 1)
    
    % Increment current folder being analyzed
    i = i + 1;
    
    % If the folder content is . or .., skip to next folder in list
    if strcmp(folderList(i).name, '.') || strcmp(folderList(i).name, '..')
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
        name = strcat(name, ext);
        
        % Clear temporary variable
        clear ext;
        
        % Search for and load all approvedPlans in the archive
        approvedPlans = FindPlans(path, name);
        
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
                            strcmp(results{3}{k}, approvedPlans{j}) && ...
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
                    % Log start
                    Event(sprintf(['Executing systematic error workflow', ...
                        ' on plan UID %s'], approvedPlans{j}));
                    
                    % Start plan timer
                    planTimer = tic;
                    
                    % Load delivery plan
                    planData = LoadPlan(path, name, approvedPlans{j});
                    
                    % Load reference image
                    referenceImage = ...
                        LoadReferenceImage(path, name, approvedPlans{j});
                    
                    % Load structures
                    referenceImage.structures = LoadReferenceStructures(...
                        path, name, referenceImage, atlas);
                    
                    % Find structure category
                    category = FindCategory(referenceImage.structures, ...
                        atlas);
                    
                    % Execute CalcDose on reference plan
                    referenceDose = CalcDose(referenceImage, planData, ...
                        [0 0 0 0 0 0], ssh2);
                    
                    % Write reference DVH to .csv file
                    WriteDVH(referenceImage, referenceDose, fullfile(...
                        dvhDir, strcat(approvedPlans{j}, ...
                        '_reference.csv')));
                    
                    % Initialize 2D plan metrics storage array (initialize
                    % with -1)
                    planMetrics = zeros(size(metrics,1), ...
                        size(modifications,1)+1) - 1;
                    
                    % Loop through plan metrics, computing reference value
                    for k = 1:size(metrics, 1)
                       
                        % If category is empty, or if it exists in the
                        % metric's category list
                        if isempty(metrics{k,4}) || ...
                                regexp(category, metrics{k,4}) > 0
                            
                            % If no additional arguments are included
                            if isempty(metrics{k,3})
                                
                                % Execute metric with no additional args
                                planMetrics(k, 1) = feval(metrics{k,2}, ...
                                    referenceImage, referenceDose, ...
                                    referenceDose, atlas);
                            else
                                % Split metric arguments using / delimiter
                                str = strsplit(metrics{k,3}, '/');
                                
                                % Switch on number of input arguments
                                switch length(str)
                                case 1
                                    % Execute metric with 1 additional arg
                                    planMetrics(k, 1) = feval(metrics{k,2}, ...
                                        referenceImage, referenceDose, ...
                                        referenceDose, atlas, str(1));
                                case 2
                                    % Execute metric with 2 additional args
                                    planMetrics(k, 1) = feval(metrics{k,2}, ...
                                        referenceImage, referenceDose, ...
                                        referenceDose, atlas, str(1), ...
                                        str(2));
                                case 3
                                    % Execute metric with 3 additional args
                                    planMetrics(k, 1) = feval(metrics{k,2}, ...
                                        referenceImage, referenceDose, ...
                                        referenceDose, atlas, str(1), ...
                                        str(2), str(3));
                                otherwise
                                    % Otherwise throw an error
                                    Event('Too many arguments for feval', ...
                                        'ERROR');
                                end
                                
                                % Clear temporary variable
                                clear str;
                            end
                        end    
                    end
                    
                    % Clear temporary variable
                    clear k;
                    
                    % Loop through plan modifications
                    for k = 1:size(modifications, 1)
                        
                        % If no additional arguments are included
                        if isempty(modifications{k,3})
                            
                            % Execute modifications with no additional args
                            modPlan = feval(modifications{k,2}, planData);
                            
                        else
                            % Split modifications arguments using / 
                            % delimiter
                            str = strsplit(modifications{k,3}, '/');
                            
                            % Switch on number of input arguments
                            switch length(str)
                            case 1
                                % Execute metric with 1 additional arg
                                modPlan = feval(modifications{k,2}, ...
                                    planData, str(1));
                            case 2
                                % Execute metric with 2 additional args
                                modPlan = feval(modifications{k,2}, ...
                                    planData, str(1), str(2));
                            case 3
                                % Execute metric with 3 additional args
                                modPlan = feval(modifications{k,2}, ...
                                    planData, str(1), str(2), str(3));
                            otherwise
                                % Otherwise throw an error
                                Event('Too many arguments for feval', ...
                                    'ERROR');
                            end

                            % Clear temporary variable
                            clear str;
                        end
                        
                        % Calculate modified plan dose
                        modDose = CalcDose(referenceImage, modPlan, ...
                            [0 0 0 0 0 0], ssh2);
                        
                        % Write modified DVH to .csv file
                        WriteDVH(referenceImage, modDose, fullfile(dvhDir, ...
                            strcat(approvedPlans{j}, '_', ...
                            modifications{k,1}, '.csv')));
                        
                        % Loop through plan metrics, computing modified 
                        % value
                        for n = 1:size(metrics, 1)

                            % If category is empty, or if it exists in the
                            % metric's category list
                            if isempty(metrics{n,4}) || ...
                                    regexp(category, metrics{n,4}) > 0

                                % If no additional arguments are included
                                if isempty(metrics{n,3})

                                    % Execute metric with no additional 
                                    % args
                                    planMetrics(n, k+1) = feval(...
                                        metrics{n,2}, referenceImage, ...
                                        modDose, referenceDose, atlas);
                                else
                                    % Split metric arguments using / 
                                    % delimiter
                                    str = strsplit(metrics{n,3}, '/');

                                    % Switch on number of input arguments
                                    switch length(str)
                                    case 1
                                        % Execute metric with 1 additional 
                                        % arg
                                        planMetrics(n, k+1) = feval(...
                                            metrics{n,2}, referenceImage, ...
                                            modDose, referenceDose, ...
                                            atlas, str(1));
                                    case 2
                                        % Execute metric with 2 additional 
                                        % args
                                        planMetrics(n, k+1) = feval(...
                                            metrics{n,2}, referenceImage, ...
                                            modDose, referenceDose, ...
                                            atlas, str(1), str(2));
                                    case 3
                                        % Execute metric with 3 additional 
                                        % args
                                        planMetrics(n, k+1) = feval(...
                                            metrics{n,2}, referenceImage, ...
                                            modDose, referenceDose, ...
                                            atlas, str(1), str(2), str(3));
                                    otherwise
                                        % Otherwise throw an error
                                        Event(['Too many arguments for ', ...
                                            feval'], 'ERROR');
                                    end

                                    % Clear temporary variable
                                    clear str;
                                end
                            end    
                        end

                        % Clear temporary variable
                        clear k;
                    end
                
                    % Loop thorugh each metric, writing results
                    for k = 1:size(metrics, 1)
                        
                        % Open append file handle to metric result
                        fid = fopen(fullfile(metricDir, ...
                            strcat(metrics{k, 1}, '.csv')), 'a');
                        
                        % Write metric results
                        fprintf(fid, '%s,', approvedPlans{j});
                        fprintf(fid, '%s,', category);
                        fprintf(fid, '%f,', planMetrics(k, :));
                        fprintf(fid, '\n');
                        
                        % Close file handle
                        fclose(fid);
                    end
                    
                    % Open append file handle to results .csv
                    fid = fopen(resultsCSV, 'a');

                    % If anon is TRUE, do not store the XML name and 
                    % location in column 1
                    if anon
                        % Instead, replace with 'ANON'
                        fprintf(fid,'ANON,'); %#ok<*UNRCH>
                    else
                        % Otherwise, write relative path location 
                        fprintf(fid, '%s,', ...
                            strrep(folderList(i).name, ',', ''));
                    end
                    
                    % Write XML SHA1 signature in column 2
                    fprintf(fid, '%s,', sha);
                    
                    % Write plan UID in column 3
                    fprintf(fid, '%s,', approvedPlans{j});
                    
                    % Write plan category in column 4.  See FindCategory
                    fprintf(fid, '%s,', category);
                    
                    % Write the number of structures in column 5
                    fprintf(fid, '%i,', ...
                        size(referenceImage.structures, 2));
                    
                    % Write the number of plan modifications in column 6
                    fprintf(fid, '%i,', size(modifications, 1));
                    
                    % Write the number of metrics in column 7
                    fprintf(fid, '%i,', size(metrics, 1));
                    
                    % Write the plan run time in column 8
                    fprintf(fid, '%f,', toc(planTimer));
                    
                    % Write the version number in column 9
                    fprintf(fid, '%s\n', version);
                    
                    % Close file handle
                    fclose(fid);
                    
                    % Clear temporary variables
                    clear fid k planTimer planMetrics category;
                    
                    % Increment the count of processed images
                    count = count + 1;
                    
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
                Event(['UID ', approvedPlans{j}, ...
                    ' skipped as results were found in ', resultsCSV]);
            end
        end
        
        % Clear temporary variables
        clear path name approvedPlans;
    end 
end

% Log completion of script
Event(sprintf(['AutoSystematicError completed in %0.0f minutes, ', ...
    'processing %i plans'], toc(totalTimer)/60, count));

% Clear temporary variables
clear i j totalTimer count;

