function plan = ModifyIso(plan, distance, direction)
% ModifyIso is a delivery plan modification plugin for the TomoTherapy FMEA 
% simulation tool.  This plugin adjusts the isocenter position by a given 
% absolute distance, in mm, along the direction (X, Y, or Z), where X,Y,Z 
% refer to the dose calculation coordinate system.
%
% The following variables are required for proper execution: 
%   plan: a structure containing the TomoTherapy delivery plan. See
%       LoadPlan for more information on the structure format.
%   distance: a number (or string) indicating the deviation in isocenter
%       position, in mm.
%   direction: 'X', 'Y', or 'Z' indicating the direction to apply the
%       adjustment.
%
% The following variable is returned upon succesful completion:
%   plan: a structure, of the same format as the input delivery plan, with
%       the modified isocenter position.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2015 University of Wisconsin Board of Regents
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
if ~isnumeric(distance)
    
    % Parse it as a double
    distance = str2double(distance);
    
end

% Log event
Event(sprintf('Adjusting iso%s %0.2f mm', direction, distance));

% Loop through delivery plan events
for i = 1:size(plan.events, 1)
    
    % If the event specifies front jaw
    if strcmp(plan.events{i,2}, ['iso', direction]) 
    
        % Modify the event value
        plan.events{i,3} = plan.events{i,3} + distance / 10;
        
    end
end