function plan = ModifyGantryRate(plan, degsec)
% ModifyGantryRate is a delivery plan modification plugin for the
% TomoTherapy FMEA simulation tool.  This plugin adjusts the gantry rate by
% a given rate, while attempting to maintain the same gantry start angle
% at the first projection.
%
% The following variables are required for proper execution: 
%   plan: a structure containing the TomoTherapy delivery plan. See
%       LoadPlan for more information on the structure format.
%   degsec: a number (or string) indicating the deviation in gantry rate
%       in degrees per second.
%
% The following variable is returned upon succesful completion:
%   plan: a structure, of the same format as the input delivery plan, with
%       the modified gantry rate and angle.
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
if ~isnumeric(degsec)
    
    % Parse it as a double
    degsec = str2double(degsec);
    
end

% Log event
Event(sprintf('Adjusting gantry rate by %0.2f%%', degsec));

% Loop through delivery plan events
for i = 1:size(plan.events, 1)
    
    % If the event specifies gantry rate
    if strcmp(plan.events{i,2}, 'gantryRate') 
    
        % Modify the event value
        plan.events{i,3} = plan.events{i,3} + ...
            degsec / plan.scale / plan.numFractions;
    
    % If the event specifies gantry angle
    elseif strcmp(plan.events{i,2}, 'gantryAngle') 
    
        % Modify the event value
        plan.events{i,3} = mod(plan.events{i,3} - ...
            degsec / plan.scale / plan.numFractions * plan.startTrim, 360);
            
    end
end