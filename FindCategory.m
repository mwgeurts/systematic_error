function category = FindCategory(structures, atlas)
% FindCategory compared a list of plan structures to an atlas and returns
% the most likely plan category (Brain, HN, Thorax, Abdomen, Pelvis, etc).
%
% The following variables are required for proper execution: 
%   structures: cell array of structure names. See LoadReferenceStructures
%       for more information.
%   atlas: cell array of atlas names, include/exclude regex statements,
%       and categories.  See LoadAtlas for more information.
%
% The following variables are returned upon succesful completion:
%   category: string representing the category which matched the most
%       structures.  If the algorithm cannot find any matches, 'Other' will
%       be returned.
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

% Log start of search, and start timer
Event('Searching for plan category using structure names');
tic;

% Initialize cell array for category candidates
matches = cell(0);

% Loop through all provided structures
for i = 1:size(structures,2)
    
    % Loop through each atlas structure
    for j = 1:size(atlas,2)
        
        % If the atlas structure is associated with a plan category
        if isfield(atlas{j}, 'category')
            
            % Run atlas include REGEXP against structure name
            in = regexpi(structures{i}.name,atlas{j}.include);
            
            % If the atlas structure has an exclude statement as well
            if isfield(atlas{j}, 'exclude') 
                
                % Run atlas exclude REGEXP against structure name
                ex = regexpi(structures{i}.name,atlas{j}.exclude);
            else
                
                % Otherwise, return zero matches (empty array)
                ex = [];
            end
            
            % If the include matched at least once and the exclude didn't
            if size(in,1) > 0 && size(ex,1) == 0
                
                % Loop through atlas categories
                for k = 1:size(atlas{j}.category,2)
                    
                    % Add the category to the list of matched categories
                    matches{size(matches,2)+1} = atlas{j}.category{k};
                end
                
                % Break the atlas search loop, since an atlas value
                % matched with the structure
                break;
            end
        end
    end
    
    % Clear temporary variables
    clear in ex;
end

% Clear temporary variables
clear i j k;

% If at least one matching atlas structure with a category was found
if size(matches,2) > 0
    
    % Determine frequency of unique values in matches cell array
    [C,~,ic] = unique(matches);
    
    % Return the most frequency category matched
    category = char(C(mode(ic)));
    
    % Clear temporary variables
    clear C ic;
else
    % Otherwise, return "Other"
    category = 'Other';
end

% Clear temporary variables
clear matches;