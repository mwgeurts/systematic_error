function deliveryPlans = FindPlans(path, name)
% FindPlans loads all delivery plan trial UIDs from a specified TomoTherapy 
% patient archive. Only Helical, non-DQA plans are returned. This function 
% has currently been validated for version 4.X and 5.X patient archives.
%
% The following variables are required for proper execution: 
%   path: path to the patient archive XML file
%   name: name of patient XML file in path
%
% The following variable is returned upon succesful completion:
%   deliveryPlans: cell array of approved plan UIDs
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

% Execute in try/catch statement
try  
   
% Log start of matching and start timer
Event(sprintf('Searching %s for approved plans', name));
tic;
    
% The patient XML is parsed using xpath class
import javax.xml.xpath.*

% Read in the patient XML and store the Document Object Model node
Event('Loading file contents data using xmlread');
doc = xmlread(fullfile(path, name));

% Initialize a new xpath instance to the variable factory
factory = XPathFactory.newInstance;

% Initialize a new xpath to the variable xpath
xpath = factory.newXPath;

% Declare a new xpath search expression.  Search for all fullPlanDataArrays
expression = ...
    xpath.compile('//fullPlanDataArray/fullPlanDataArray/plan/briefPlan');

% Retrieve the results
nodeList = expression.evaluate(doc, XPathConstants.NODESET);

% Preallocate cell arrrays
deliveryPlans = cell(1, nodeList.getLength);

% Log number of delivery plans found
Event(sprintf('%i plans found', nodeList.getLength));

% Loop through the deliveryPlanDataArrays
for i = 1:nodeList.getLength
    % Retrieve a handle to this delivery plan
    node = nodeList.item(i-1);

    % Search for approved plan trial UID
    subexpression = xpath.compile('approvedPlanTrialUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no approved plan trial UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if approved plan trial UID is empty, continue
    if strcmp(char(subnode.getFirstChild.getNodeValue), '')
        continue
    end
    
    % Search for plan delivery type
    subexpression = xpath.compile('planDeliveryType');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If plan delivery type was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if approved plan delivery type is not Helical, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'Helical')
        continue
    end
    
    % Search for plan type
    subexpression = xpath.compile('typeOfPlan');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If plan type was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Otherwise, if plan type is not PATIENT, continue
    if ~strcmp(char(subnode.getFirstChild.getNodeValue), 'PATIENT')
        continue
    end
    
    % Search for plan database UID
    subexpression = xpath.compile('dbInfo/databaseUID');

    % Evaluate xpath expression and retrieve the results
    subnodeList = subexpression.evaluate(node, XPathConstants.NODESET);

    % If no database UID was found, continue to next result
    if subnodeList.getLength == 0
        continue
    end
    
    % Otherwise, retrieve a handle to the results
    subnode = subnodeList.item(0);
    
    % Store the plan UID
    deliveryPlans{i} = char(subnode.getFirstChild.getNodeValue);
end

% Clear temporary variables
clear doc factory xpath i node subnode nodeList subnodeList expression ...
    subexpression;

% Remove empty cells due invalid plans
deliveryPlans = deliveryPlans(~cellfun('isempty', deliveryPlans));

% If no valid delivery plans were found
if size(deliveryPlans, 2) == 0
    
    % Throw a warning
    Event(sprintf('No approved plans found in %s', name), 'WARN'); 
    
% Otherwise the execution was successful
else
    
    % Log completion
    Event(sprintf(['%i approved plans successfully identified in ', ...
        '%0.3f seconds'], size(deliveryPlans, 2), toc));
    
end

% Catch errors, log, and rethrow
catch err  
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end