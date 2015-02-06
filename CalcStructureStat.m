function metric = CalcStructureStat(image, ~, newDose, atlas, structure, stat)
% CalcStructureStat is a metric plugin for the TomoTherapy FMEA simulation 
% tool and computes a specified dose statistic for a given structure or
% structures.  
%
% The statistic is specified by the input variable stat and must be one of 
% the following strings:
%   Mean: computes the mean dose
%   Max: computes the max dose
%   Min: computes the min dose
%   Median: computes the median dose 
%   Std: computes the standard deviation
%   DXX: computes the dose to XX percent of the structure volume
%   VXX: computes the percent volume with dose greater than XX
%
% To compute the statistic, each plan structure name contained in image is
% compared to the atlas, and if the matching structure name matches the
% input variable structure, is included in the calculation.  For example,
% if the stat is "Max" then the maximum of all matching structures is
% returned.  Note, if the structures overlap, overlapping voxels are only 
% counted once.
%
% The following variables are required for proper execution: 
%   image: structure containing the CT image data and structure set 
%       data. See LoadReferenceImage and LoadReferenceStructures for more
%       information on the format of this object.
%   refDose: structure containing the calculated reference dose. See 
%       CalcDose for more information on the format of this object. This 
%       variable is not currently used but the placeholder exists for 
%       future use.
%   newDose: structure containing the calculated new/modified dose. See 
%       CalcDose for more information on the format of this object.
%   atlas: cell array of atlas structures with the following fields: name,
%       include, exclude, load, dx, and category. See LoadAtlas for more
%       information on the structure of this array.
%   structure: string containing the atlas structure name to match plan 
%       structures to when computing statistic
%   stat: string containing the statistic
% 
% The following variable is returned upon succesful completion:
%   metric: structure statistic, or -1 if no matching structure was found
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

% Reformat structure and stat inputs
structure = char(structure);
stat = char(stat);

% Execute in try/catch statement
try  
    
% Log start of metric computation and start timer
Event(sprintf('Computing %s %s metric', structure, stat));
tic;

% Initialize -1 array of masked dose voxels
mask = zeros(size(image.data));

% Initialize return variable
metric = -1;

% If the dose variable contains a valid data array
if isfield(newDose, 'data') && size(newDose.data, 1) > 0
    
    % If the image size, pixel size, or start differs between datasets
    if size(newDose.data,1) ~= size(image.data,1) ...
            || size(newDose.data,2) ~= size(image.data,2) ...
            || size(newDose.data,3) ~= size(image.data,3) ...
            || isequal(newDose.width, image.width) == 0 ...
            || isequal(newDose.start, image.start) == 0

        % Create 3D mesh for reference image
        [refX, refY, refZ] = meshgrid(image.start(2):...
            image.width(2):image.start(2) + ...
            image.width(2) * size(image.data, 2), ...
            image.start(1):image.width(1):...
            image.start(1) + image.width(1) * ...
            size(image.data,1), image.start(3):...
            image.width(3):image.start(3) + ...
            image.width(3) * size(image.data, 3));

        % Create GPU 3D mesh for secondary dataset
        [secX, secY, secZ] = meshgrid(newDose.start(2):...
            newDose.width(2):newDose.start(2) + ...
            newDose.width(2) * size(newDose.data, 2), ...
            newDose.start(1):newDose.width(1):...
            newDose.start(1) + newDose.width(1) * ...
            size(newDose.data, 1), newDose.start(3):...
            newDose.width(3):newDose.start(3) + ...
            newDose.width(3) * size(newDose.data, 3));

        % Attempt to use GPU to interpolate dose to image/structure
        % coordinate system.  If a GPU compatible device is not
        % available, any errors will be caught and CPU interpolation
        % will be used instead.
        try
            % Initialize and clear GPU memory
            gpuDevice(1);

            % Interpolate the dose to the reference coordinates using
            % GPU linear interpolation, and store back to 
            % newDose.data
            newDose.data = gather(interp3(gpuArray(secX), ...
                gpuArray(secY), gpuArray(secZ), ...
                gpuArray(newDose.data), gpuArray(refX), ...
                gpuArray(refY), gpuArray(refZ), 'linear', 0));

            % Clear GPU memory
            gpuDevice(1);

        % Catch any errors that occured and attempt CPU interpolation
        % instead
        catch
            % Interpolate the dose to the reference coordinates using
            % linear interpolation, and store back to newDose.data
            newDose.data = interp3(secX, secY, secZ, ...
                newDose.data, refX, refY, refZ, '*linear', 0);
        end

        % Clear temporary variables
        clear refX refY refZ secX secY secZ;
    end

    % Loop through each image structure
    for i = 1:size(image.structures, 2)
        
        % Compare name to atlas
        % Loop through each atlas structure
        for j = 1:size(atlas,2)

            % Compute the number of include atlas REGEXP matches
            in = regexpi(image.structures{i}.name, atlas{j}.include);

            % If the atlas structure also contains an exclude REGEXP
            if isfield(atlas{j}, 'exclude') 
                % Compute the number of exclude atlas REGEXP matches
                ex = regexpi(image.structures{i}.name, atlas{j}.exclude);
            else
                % Otherwise, return 0 exclusion matches
                ex = [];
            end

            % If the structure matched the include REGEXP and not the
            % exclude REGEXP (if it exists)
            if size(in,1) > 0 && size(ex,1) == 0
                    
                % If the structure name matches the structure input var
                if strcmp(atlas{j}.name, structure)
                    
                    % Add to mask array
                    mask = mask + image.structures{i}.mask;
                    
                end

                % Stop the atlas for loop, as the structure was matched
                break;
            end
        end

        % Clear temporary variables
        clear in ex;
    end

% Otherwise, the dose array is invalid
else
    % Throw an error
    Event('The dose array is invalid', 'ERROR');
end

% Multiply mask by dose array and permute to 1D vector
mask = reshape(min(mask, 1) .* newDose.data, 1, []);

% Remove values less than or equal to zero (due to masking)
mask = mask(mask > 0); 

% If the mask is not empty
if ~isempty(mask)
    % Compute mean dose
    if strcmpi(stat, 'Mean')
        metric = mean(mask);

    % Compute max
    elseif strcmpi(stat, 'Max')
        metric = max(mask);

    % Compute min
    elseif strcmpi(stat, 'Min')
        metric = min(mask);

    % Compute std
    elseif strcmpi(stat, 'Std')
        metric = std(mask);

    % Compute DX
    elseif regexpi(stat, 'D[0-9\.]+') > 0

        % Extract Dx value as a fraction
        dx = str2double(stat(2:length(stat))) / 100;

        % Sort voxel array
        mask = sort(mask);

        % Compute lower and upper interpolation bounds
        lower = floor(length(mask) * dx);
        upper = ceil(length(mask) * dx);

        % Interpolate to find Dx
        metric = interp1([lower upper], [mask(lower) mask(upper)], ...
            length(mask) * dx, 'linear');

        % Clear temporary variables
        clear lower upper dx;

    % Compute VX
    elseif regexpi(stat, 'V[0-9\.]+') > 0

        % Extract Vx value
        vx = str2double(stat(2:length(stat)));

        % Store percentage of voxels greater than Vx dose
        metric = length(mask(mask > vx)) / length(mask) * 100;

        % Clear temporary variables
        clear vx;

    % Otherwise, statistic is incorrect
    else
        Event(sprintf('%s is not a valid statistic for CalcStructureStat', ...
            stat), 'ERROR');
    end
else
    % Otherwise, warn user
    Event('No structures matched the statistic', 'WARN');
end

% Log result
Event(sprintf('%s %s metric = %e (%0.3f seconds)', structure, ...
    stat, metric, toc));

% Clear temporary variable
clear mask;

% Catch errors, log, and rethrow
catch err
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end

