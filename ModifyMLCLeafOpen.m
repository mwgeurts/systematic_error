function plan = ModifyMLCLeafOpen(plan, leaf)
% ModifyMLCLeafOpen is a delivery plan modification plugin for the
% TomoTherapy FMEA simulation tool.  This plugin adjusts the sinogram
% assuming a leaf is "stuck" open.
%
% The following variables are required for proper execution: 
%   plan: a structure containing the TomoTherapy delivery plan. See
%       LoadPlan for more information on the structure format.
%   leaf: an integer indicating the leaf (1-64) that is stuck open.
%
% The following variable is returned upon succesful completion:
%   plan: a structure, of the same format as the input delivery plan, with
%       the sinogram modified.
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

% If the second variable is not already numeric
if ~isnumeric(leaf)
    
    % Parse it as a double
    leaf = str2double(leaf);
    
end

% Log event
Event(sprintf('Setting leaf %i to all open', leaf));

% Edit plan sinogram
plan.sinogram(leaf, :) = 1;