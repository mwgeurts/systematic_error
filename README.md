## TomoTherapy FMEA Simulation Tool

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2014, University of Wisconsin Board of Regents

The TomoTherapy&reg; Failure Modes and Effects Analysis (FMEA) Tool is a console based application written in MATLAB that simulates various delivery failure modes by parsing [TomoTherapy](http://www.accuray.com) patient archives, modifying the delivery plan, and recomputing the plan dose using the Standalone GPU TomoTherapy Dose Calculator.  Each modified plan dose distribution is then compared using various metrics.  Both the failure modes and metrics are customizable through the use of “plugin” functions, as described below.

TomoTherapy is a registered trademark of Accuray Incorporated.

## Contents

* [Installation and Use](README.md#installation-and-use)
* [Compatibility and Requirements](README.md#compatibility-and-requirements)
* [Troubleshooting](README.md#troubleshooting)
* [Failure Modes](README.md#failure-modes)
  * [Current Installed Failure Modes](README.md#current-installed-failure-modes)
  * [Adding New Failure Mode Plugins](README.md#adding-new-failure-mode-plugins)
* [Comparison Metrics](README.md#comparison-metrics)
  * [Current Installed Metrics](README.md#current-installed-metrics)
  * [Adding New Metric Plugins](README.md#adding-new-metric-plugins)
* [Report Files](README.md#report-files)
  * [Results Excel File](README.md#results-excel-file)
  * [DVH Excel Files](README.md#dvh-excel-files)
  * [Metric Excel Files](README.md#metric-excel-files)
* [Gamma Computation Methods](README.md#gamma-computation-methods)

## Installation and Use

To install the TomoTherapy FMEA Simulation Tool, copy all MATLAB .m, .fig files, and submodules ([dicom_tools](https://github.com/mwgeurts/dicom_tools), [tomo_extract](https://github.com/mwgeurts/tomo_extract), [structure_atlas](https://github.com/mwgeurts/structure_atlas), and [gamma](https://github.com/mwgeurts/gamma)) into a directory with read/write access. If using git, execute `git clone --recursive https://github.com/mwgeurts/systematic_error`.

Next, copy the following beam model files in a folder named `GPU` in the same directory.  These files will be copied to the computation server along with the plan files at the time of program execution.  To change the location of this folder, edit the line `modeldir = './GPU';` in the function `AutoSystematicError()`.

* dcom.header
* lft.img
* penumbra.img
* kernel.img
* fat.img

The TomoTherapy FMEA Simulation Tool must be configured to either calculate dose locally or communicate with a dose calculation server.  If using local calculation, `gpusadose` must be installed in an execution path available to MATLAB. If using a remote server, open `CalcDose()`, find the statement `ssh2 = ssh2_config('tomo-research', 'tomo', 'hi-art');`, and enter the IP/DNS address of the dose computation server (tomo-research, for example), a user account on the server (tomo), and password (hi-art).  This user account must have SSH access rights, rights to execute `gpusadose`, and finally read/write acces to the temp directory.  See Accuray Incorporated to see if your research workstation includes this feature.  For additional information, see the [tomo_extract](https://github.com/mwgeurts/tomo_extract) submodule.

When using the 3D [gamma analysis](https://github.com/mwgeurts/gamma) metric, if the Parallel Computing Toolbox is enabled, `CalcGamma()` will attempt to compute the three-dimensional computation using a compatible CUDA device.  To test whether the local system has a GPU compatible device installed, run `gpuDevice(1)` in MATLAB.  All GPU calls in this application are executed in a try-catch statement, and automatically revert to an equivalent (albeit longer) CPU based computation if not available or if the available memory is insufficient.

To run this application, call the function `AutoSystematicError()` from MATLAB with no input arguments.  As described below, the application will find all patient archives (filename appended with "_patient.xml") within a specified input directory and run the FMEA simulation.  To change the search directory, edit the `inputDir` declaration statement in the function `AutoSystematicError()`.  When searching the input directory, the folder lists are intentionally randomized such that the plans are processed by the tool in a random order.

Because this application runs without a user interface, it may also be executed via a terminal, as shown in the following example:

```
/Applications/MATLAB_R2014b.app/bin/matlab -nodesktop -r AutoSystematicError
```

## Compatibility and Requirements

This application has been validated using TomoTherapy version 4.2 and 5.0 patient archives on Macintosh OSX 10.10 (Yosemite) and MATLAB version 8.4 with Parallel Computing Toolbox version 6.4.  As discussed above, the Parallel Computing Toolbox is only required if using the Gamma metric plugin with GPU based computation.  Only helical TomoTherapy plans are currently supported.

## Troubleshooting

This application records key input parameters and results to a log.txt file using the `Event()` function. The log is the most important route to troubleshooting errors encountered by this software.  The author can also be contacted using the information above.  Refer to the license file for a full description of the limitations on liability when using or this software or its components.

## Failure Modes

Failure modes are simulated by adjusting the optimized delivery plan for each optimized TomoTherapy treatment plan using "plugin" functions.  The cell array `modifications` in the function `AutoSystematicError()` specifies the list of plugins that will be executed for each TomoTherapy plan.  Each row in this array specifies the name, function, and optional additional arguments to be passed to the plugin function as three string elements.  In the following example, the plugin "mlcrand2pct" calls the function "ModifyMLCRandom" with the additional argument "2".  Multiple arguments (up to three) can be specified in the argument string, separated by a forward slash (/).  At this time, only static values for optional parameters are currently supported.

```matlab
modifications = {'mlcrand2pct'   'ModifyMLCRandom'   '2'};
```

Each modification plugin is executed using the `feval()` command, with the delivery plan structure as the first argument and any additional arguments as specified in the `modifications` cell array.  A modified delivery plan structure (in the same format as the reference plan) is expected as the return variable.  Given the example above, the execution will be as follows:

```matlab
modPlan = feval('ModifyMLCRandom', referencePlan, '2');
```

For more information on the delivery plan format, refer to the documentation in `LoadPlan()`.

### Current Installed Failure Modes

The following plugins are predefined and represent basic modifications to the delivery plan (couch, jaws, gantry, MLC).  Note that only delivery plan modifications are available; changes that would affect the beam model (energy, output, etc) are not supported at this time.

| Function | Arguments | Description |
|----------|-----------|-------------|
| ModifyMLCLeafOpen | leaf | Modifies the delivery plan assuming that leaf is open for all active projections.  Used to simulate a stuck leaf. |
| ModifyMLCRandom | percent | Modifies the delivery plan by reducing all open leaves by an average percent (range of reduction is between zero and 2*percent). |
| ModifyCouchSpeed | percent | Modifies the delivery plan couch speed uniformly across the entire treatment by percent. Used to simulate a miscalibration of the couch actuator. |
| ModifyGantryAngle | degree | Modifies the delivery plan gantry start angle to systematically offset all beams by degree.  Used to simulate a gantry position miscalibration. |
| ModifyGantryRate | degsec | Modifies the delivery plan to adjust the gantry rate by degsec (in degrees per second).  The gantry start angle is also modified such that the first projection is still delivered at the original angle, even though the gantry period is different. |
| ModifyJawFront | distance | Modifies the delivery plan to adjust the front jaw away from isocenter by distance (in mm), such that positive values increase the effective field width.  For dynamic jaw plans, this distance is applied to all jaw positions.
| ModifyJawBack | distance | Modifies the delivery plan to adjust the back jaw away from isocenter by distance (in mm), such that positive values increase the effective field width.  For dynamic jaw plans, this distance is applied to all jaw positions. |

### Adding New Failure Mode Plugins

To add a new plugin, first write a function that accepts the delivery plan as the first argument, then up to three additional arguments, and returns a modified delivery plan.  The following example illustrates a function declaration with two arguments:

```matlab
modPlan = function NewModificationPlugin(refPlan, arg1, arg2)
% This is an example function to illustate how to write custom plugins
  
     % Set modified plan to reference plan
     modPlan = refPlan;
  
     % Adjust delivery plan somehow

% End of function  
end
```

Next, edit the `modifications` cell array definition in `AutoSystematicError()` to add the new function, giving it the name "newplugin":

```matlab
modifications = {
     'mlcrand2pct'   'ModifyMLCRandom'         '2'
     'newplugin'     'NewModificationPlugin'   '1/2'
};
```

When `NewModificationPlugin` is executed, `arg1` will be passed using a value of 1 and `arg2` will have a value of 2.

## Comparison Metrics

Similar to Failure Modes, the TomoTherapy FMEA Simulation Tool uses "plugin" functions to allow customized metrics to be added.  Each metric is computed for the reference (unmodified) plan dose and each Failure Mode simulated dose.  The cell array `metrics` in the function `AutoSystematicError()` specifies the list of plugins that will be executed for each dose volume.  Each row in this array specifies the name, function, and optional additional arguments to be passed to the plugin function as three string elements.  In the following example, the plugin "gamma2pct1mm" calls the function "CalcGammaMetric" with the additional arguments "2" and "1".  Multiple arguments (up to three) can be specified in the argument string, separated by a forward slash (/).  At this time, only static values for optional parameters are currently supported.

```matlab
metrics = {'gamma2pct1mm'   'CalcGammaMetric'   '2/1'};
```

Each metric plugin is executed using the `feval()` command, with the image structure as the first argument, reference dose structure as the second argument, modified dose as the third argument, atlas cell array as the fourth argument, and any additional arguments as specified in the `metric` cell array.  A numerical metric is expected as the return variable.  Given the example above, the execution will be as follows:

```matlab
metric = feval('CalcGammaMetric', image, refDose, modDose, altas, '2', '1');
```

The image structure contains both the CT data and structure set information (see `LoadReferenceImage()` and `LoadReferenceStructures()` for more information on this format).  For more information on the dose structure format, see `CalcDose()`.  Finally, for information on the atlas cell array format, see `LoadAtlas()`.   

### Current Installed Metrics

The following metrics are included and illustrate how the structures/atlas and dose arguments can be used.  For additional documentation refer to the documentation in the function.

| Function | Arguments | Description |
|----------|-----------|-------------|
| CalcGammaMetric | percent/dta | Computes the 3D Gamma index pass rate percentage between the modified and reference dose volumes using global percent and dta (in mm) criteria. Only voxels greater than 20 percent of the maximum reference dose are included. |
| CalcStructureStat | structure/stat | Computes a specified stat for one or more structures.  The stat can be Mean, Max, Min, Median, Std, Dx, or Vx (case insensitive). If Dx, the maximum dose to x percentage of the structure volume is calculated.  If Vx, the percent volume receiving at least x dose is calculated.  The structure argument can be any structure name within the atlas cell array.  The voxels contained within all structures that match the inclusion/exclusion regexp criteria for that structure name are then determined, and the statistic computed and returned. |

### Adding New Metric Plugins

To add a new plugin, first write a function that accepts the image, refDose, modDose, and atlas as the first four arguments, then up to three additional arguments, that finally returns a metric value.  The following example illustrates a function declaration with one argument:

```matlab
metric = function NewMetricPlugin(image, refDose, modDose, altas, arg1)
% This is an example function to illustate how to write custom plugins
  
     % Compute the metric somehow
     metric = str2double(arg1) * max(max(max(modDose.data)));

% End of function  
end
```

Next, edit the `metrics` cell array definition in `AutoSystematicError()` to add the new function, giving it the name "newmetric":

```matlab
metrics = {
     'gamma2pct1mm'   'CalcGammaMetric'   '2/1'
     'newmetric'      'NewMetricPlugin'   '5'
};
```

When `NewMetricPlugin` is executed, `arg1` will be passed using a value of 5.

## Report Files

The TomoTherapy FMEA Simulation Tool documents all results into a series of Comma Separated Value (.csv) Microsoft&reg; Excel&reg; files. The format of each file is detailed below.

### Results Excel File

The name and path of the Results Excel file is declared in `AutoSystematicError()` in the line `resultsCSV = '../Study_Results/Results.csv';`.  The first few rows are prepended with hash (#) symbols and contain title and version information. The next row contains a list of column headers.  A new line is then written out for each plan simulated by the tool.  The following information is contained in each column:

| Heading | Description |
|---------|-------------|
| Archive | Full path to patient archive _patient.xml.  However, if the variable `anon` is set to TRUE, will be "ANON". |
| SHA1 | SHA1 signature of _patient.xml file |
| Plan UID | UID of the plan |
| Plan Type | Atlas category (HN, Brain, Thorax, Abdomen, Pelvis) |
| Structures | Number of structures loaded (helpful when loading DVH .csv files) |
| Modifications | Number of plan modifications computed |
| Metrics | Number of plan metrics computed |
| Time | Time (in seconds) to run entire workflow |
| Version | Version number of AutoSystematicError when plan was run |

It is important to note that the Results Excel file is also used during archive searching to determine if a given plan has already been computed by the tool.  When each new patient archive is parsed, the tool first checks if an existing matching result exists in the Results file.  If the _patient.xml SHA1, plan UID, number of modifications/metrics, and versions match, the plan will be skipped and the next non-matching plan will be simulated.  

In this manner, `AutoSystematicError()` can be executed repeatedly using the same input directory without duplicating results.  This is helpful when running this application against a large library of archives.  Also, as described above, the folders are searched in random order, so multiple executions will start with different plans.

### DVH Excel Files

A Dose Volume Histogram (DVH) is saved as a .csv file following each reference and modified plan dose calculation.  The path where each DVH is saved is declared in `AutoSystematicError()` in the line `dvhDir = '../Study_Results/DVHs/';`. This directory must exist prior to application execution and the tool must have read/write access.  The name of each DVH file follows the format "planuid_modification.csv", where "modification" is the modification plugin name or "reference".

The first row of the DVH Excel file starts with a hash symbol (#) with the file name written in the second column.  The second row lists each structure, structure number (in parentheses), and structure volume (in cc) in 2 on. For all remaining rows, the normalized cumulative dose histogram is reported, with the first column containing the dose bin (in Gy) and each subsequent column containing the relative volume percentage for that dose.  The tool will always compute 1001 bins equally spaced between zero and the maximum dose.

Finally, it should be noted that this tool currently does not consider partial voxels in volume or DVH calculation, and will therefore differ from the TomoTherapy Treatment Planning System.

### Metric Excel Files

A final Excel file is created for each metric declared in the `metrics` cell array.  The path where each metric file is saved is declared in `AutoSystematicError()` in the line `metricDir = '../Study_Results/';`. Again, this directory must exist prior to application execution and the tool must have read/write access.  The name of each Metric Excel file is the name of specified in the first column of the `metrics` cell array, followed by the .csv extension.

The first row of each Metric Excel file contains the column headers.  A new line is then written out for each plan simulated by the tool. Equivalent to the Results Excel file, the first column contains the Plan UID and the second contains the Plan Type.  The remaining columns are then populated with the metric computed, with the reference metric in the third column followed by each Failure Mode.  The column header is the name of the plugin, specified in the `modifications` cell array.

## Gamma Computation Methods

To compute the 3D gamma analysis metric, a Gamma analysis is performed based on the formalism presented by D. A. Low et. al., [A technique for the quantitative evaluation of dose distributions.](http://www.ncbi.nlm.nih.gov/pubmed/9608475), Med Phys. 1998 May; 25(5): 656-61.  In this formalism, the Gamma quality index *&gamma;* is defined as follows for each point in measured dose/response volume *Rm* given the reference dose/response volume *Rc*:

*&gamma; = min{&Gamma;(Rm,Rc}&forall;{Rc}*

where:

*&Gamma; = &radic; (r^2(Rm,Rc)/&Delta;dM^2 + &delta;^2(Rm,Rc)/&Delta;DM^2)*,

*r(Rm,Rc) = | Rc - Rm |*,

*&delta;(Rm,Rc) = Dc(Rc) - Dm(Rm)*,

*Dc(Rc)* and *Dm(Rm)* represent the reference and measured doses at each *Rc* and *Rm*, respectively, and

*&Delta;dM* and *&Delta;DM* represent the absolute and Distance To Agreement Gamma criterion (by default 3%/3mm), respectively.  

The absolute criterion is typically given in percent and can refer to a percent of the maximum dose (commonly called the global method) or a percentage of the voxel *Rm* being evaluated (commonly called the local method).  The application is capable of computing gamma using either approach, and can be set in `CalcGammaMetric()` by editing the line `local = 0;` from 0 to 1.  By default, the global method (0) is applied.

The computation applied in the TomoTherapy FMEA Simulation Tool is a 3D algorithm, in that the distance to agreement criterion is evaluated in all three dimensions when determining *min{&Gamma;(Rm,Rc}&forall;{Rc}*. To accomplish this, the modified dose volume is shifted along all three dimensions relative to the reference dose using linear 3D interpolation.  For each shift, *&Gamma;(Rm,Rc}* is computed, and the minimum value *&gamma;* is determined.  To improve computation efficiency, the computation space *&forall;{Rc}* is limited to twice the distance to agreement parameter.  Thus, the maximum "real" Gamma index returned by the application is 2.