function plan = ModifyMLCRandom(plan, mu, sigma)
% ModifyMLCRandom is a delivery plan modification plugin for the
% TomoTherapy FMEA simulation tool.  This plugin adjusts the sinogram
% randomly such that the random values follow a Gaussian distribution using
% the provided mean and standard deviation. Note, the maximum leaf open
% time is kept constant, as it is assumed that a leaf cannot deliver more
% than 100%.
%
% The following variables are required for proper execution: 
%   plan: a structure containing the TomoTherapy delivery plan. See
%       LoadPlan for more information on the structure format.
%   mu: number indicating the average percent reduction or increase to
%       apply, relative to the maximum LOT
%   sigma: number indicating the standard deviation of the normalized 
%       random distribution, given as a percentage of the maximum LOT
%
% The following variable is returned upon succesful completion:
%   plan: a structure, of the same format as the input delivery plan, with
%       the sinogram modified.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
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

% If the second variable is not already numeric
if ~isnumeric(mu)
    
    % Parse it as a double
    mu = str2double(mu);
    
end

% If the third variable is not already numeric
if ~isnumeric(sigma)
    
    % Parse it as a double
    sigma = str2double(sigma);
    
end

% Log event
Event(sprintf(['Adjusting leaf open times using a normalized random ', ...
    'distribution with mean %0.1f%% and standard deviation %0.1f%%'], ...
    mu, sigma));

% Edit plan sinogram
plan.sinogram = max(min(plan.sinogram + normrnd(max(max(plan.sinogram)) * ...
    mu/100, max(max(plan.sinogram)) * sigma/100, size(plan.sinogram,1), ...
    size(plan.sinogram,2)), max(max(plan.sinogram))), 0) .* ...
    ceil(plan.sinogram/max(max(plan.sinogram)));