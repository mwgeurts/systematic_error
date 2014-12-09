function metric = CalcGammaMetric(~, refDose, newDose, ~, percent, dta)
% CalcGammaMetric is a metric plugin for the TomoTherapy FMEA simulation 
% tool and computes the Gamma Index between the new and reference dose
% using the CalcGamma submodule.  For more information on the methods used
% to compute Gamma, see CalcGamma.m or the README.
%
% The following variables are required for proper execution: 
%   image: structure containing the CT image data and structure set 
%       data. See LoadReferenceImage and LoadReferenceStructures for more
%       information on the format of this object.  This variable is not
%       currently used but the placeholder exists for future use.
%   refDose: structure containing the calculated reference dose. See 
%       CalcDose for more information on the format of this object.
%   newDose: structure containing the calculated new/modified dose. See 
%       CalcDose for more information on the format of this object.
%   atlas: cell array of atlas structures with the following fields: name,
%       include, exclude, load, dx, and category. See LoadAtlas for more
%       information on the structure of this array. This variable is not
%       currently used but the placeholder exists for future use.
%   percent: a number (or string) indicating the Gamma absolute criterion 
%       percentage
%   dta: a number (or string) indicating the Gamma Distance To Agreement 
%       (DTA) criterion, in the same units as the reference and target 
%       width structure fields  
%
% The following variable is returned upon succesful completion:
%   metric: Gamma index pass rate, or percent of voxels less than 1 that
%       are greater than 20% of the maximum reference dose.
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

% Start timer
tic;

% Declare gamma local/global flag. Set to 1 to calculate local gamma
local = 0;

% Declare restricted search flag. See CalcGamma for more information.
restrictSearch = 1;

% Declare threshold setting. Only voxels where the dose is greater than
% this relative value of the maximum dose are included in the metric
threshold = 0.2;

% If the percent variable is not already numeric
if ~isnumeric(percent)
    
    % Parse it as a double
    percent = str2double(percent);
    
end

% If the dta variable is not already numeric
if ~isnumeric(dta)
    
    % Parse it as a double
    dta = str2double(dta);
    
end

% Log event
Event(sprintf('Calculating %0.1f%%/%0.1fmm Gamma pass rate metric', ...
    percent, dta));

% Compute maximum dose in reference image
maxdose = max(max(max(refDose.data)));

% Execute CalcGamma
gamma = CalcGamma(refDose, newDose, percent, dta, local, maxdose, ...
    restrictSearch);

% Remove voxels where dose is less than threshold
gamma = gamma .* ceil(refDose.data/maxdose - threshold);

% Initialize the gammahist temporary variable to compute the gamma pass 
% rate, by reshaping gamma to a 1D vector
gammahist = reshape(gamma, 1, []);

% Remove values less than or equal to zero (due to threshold)
gammahist = gammahist(gammahist > 0); 

% Compute pass rate
metric = length(gammahist(gammahist <= 1)) / length(gammahist) * 100;

% Log result
Event(sprintf(['%0.1f%%/%0.1fmm Gamma pass rate metric = %e%% ', ...
    '(%0.3f seconds)'], percent, dta, metric, toc));

% Clear temporary variables
clear local restrictSearch threshold maxdose gamma gammahist;