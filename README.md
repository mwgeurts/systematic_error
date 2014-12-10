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
* [Third Party Statements](README.md#third-party-statements)

## Installation and Use

To install the TomoTherapy FMEA Simulation Tool, copy all MATLAB .m and .fig and DICOM .dcm files into a directory with read/write access and then copy the [CalcGamma.m submodule from the gamma repository](https://github.com/mwgeurts/gamma) into the `gamma` subfolder.  If using git, execute `git clone --recursive https://github.com/mwgeurts/systematic_error`.

Next, the TomoTherapy FMEA Simulation Tool must be configured to communicate with a dose calculation server.  Open `AutoSystematicError()` and find the following lines (note each line is separated by several lines of comments and `Event()` calls in the actual file):

```
addpath('../ssh2_v2_m1_r6/');
ssh2 = ssh2_config('tomo-research','tomo','hi-art');
```

This application uses the [SSH/SFTP/SCP for Matlab (v2)] (http://www.mathworks.com/matlabcentral/fileexchange/35409-sshsftpscp-for-matlab-v2) interface based on the Ganymed-SSH2 javalib for communication with the dose calculation server.  If performing dose calculation, this interface must be downloaded/extracted and the `AutoSystematicError()` statement `addpath('../ssh2_v2_m1_r6/')` modified to reflect its location.  If this interface is not available, use of the TomoTherapy Exit Detector Analysis application is still available for sinogram comparison, but all dose and Gamma computation and evaluation functionality will be automatically disabled.

Next, edit `ssh2_config()` with the the IP/DNS address of the dose computation server (tomo-research, for example), a user account on the server (tomo), and password (hi-art).  This user account must have SSH access rights, rights to execute `gpusadose`, and finally read/write acces to the temp directory.  See Accuray Incorporated to see if your research workstation includes this feature.

Finally, for dose calculation copy the following beam model files in a folder named `GPU` in the MATLAB directory.  These files will be copied to the computation server along with the plan files at the time of program execution.  To change this directory, edit the line `[status, cmdout] = system(['cp GPU/*.* ', folder, '/']);` in `CalcDose()`.

* dcom.header
* lft.img
* penumbra.img
* kernel.img
* fat.img

When using the 3D [gamma analysis](http://www.ncbi.nlm.nih.gov/pubmed/9608475) metric, if the Parallel Computing Toolbox is enabled, `CalcGamma()` will attempt to compute the three-dimensional computation using a compatible CUDA device.  To test whether the local system has a GPU compatible device installed, run `gpuDevice(1)` in MATLAB.  All GPU calls in this application are executed in a try-catch statement, and automatically revert to an equivalent (albeit longer) CPU based computation if not available or if the available memory is insufficient.

To run this application, call the function `AutoSystematicError()` from MATLAB with no input arguments.  As described below, the application will find all patient archives (filename appended with "_patient.xml") within a specified input directory and run the FMEA simulation.  To change the search directory, edit the `inputDir` declaration statement in the function `AutoSystematicError()`.  Similarly, the report files and directories can be modified by adjusting the `resultsCSV`, `dvhDir`, and `metricDir` statements.  For more information on the report files, see [Report Files](README.md#report-files).

Because this application runs without a user interface, it may also be executed via a terminal, as shown in the following example:

`/Applications/MATLAB_R2014b.app/bin/matlab -nodesktop -r AutoSystematicError`

## Compatibility and Requirements

This application has been validated using TomoTherapy version 4.2 and 5.0 patient archives on Macintosh OSX 10.10 (Yosemite) and MATLAB version 8.4 with Parallel Computing Toolbox version 6.4.  As discussed above, the Parallel Computing Toolbox is only required if using the Gamma metric plugin with GPU based computation.  Only helical TomoTherapy plans are currently supported.

## Troubleshooting

This application records key input parameters and results to a log.txt file using the `Event()` function. The log is the most important route to troubleshooting errors encountered by this software.  The author can also be contacted using the information above.  Refer to the license file for a full description of the limitations on liability when using or this software or its components.

## Failure Modes

Failure modes are simulated by adjusting the optimized delivery plan for each optimized TomoTherapy treatment plan using "plugin" functions.  The cell array `modifications` in the function `AutoSystematicError` specifies the list of plugins that will be executed for each TomoTherapy plan.  Each row in this array specifies the name, function, and optional additional arguments to be passed to the plugin function as three string elements.  In the following example, the plugin "mlcrand2pct" calls the function "ModifyMLCRandom" with the additional parameter "2".  Multiple arguments (up to three) can be specified in the argument string, separated by a forward slash (/).

`modifications = {'mlcrand2pct'   'ModifyMLCRandom'   '2'};`

Each plugin is executed using the `feval()` command, with the delivery plan structure as the first argument and any additional arguments as specified in the `modifications` cell array.  A modified delivery plan structure (in the same format as the reference plan) is expected as the return variable.  Given the example above, the execution will be as follows:

`modPlan = feval('ModifyMLCRandom', referencePlan, '2');`

For more information on the delivery plan format, refer to the documentation in `LoadPlan()`.

### Current Installed Failure Modes

The following plugins are predefined and represent basic modifications to the delivery plan (couch, jaws, gantry, MLC).  Note that only delivery plan modifications are available; changes that would affect the beam model (energy, output, etc) are not supported at this time.

| Function | Arguments | Description |
|----------|-----------|-------------|
| ModifyMLCLeafOpen | leaf | Modifies the delivery plan assuming that leaf is open for all active projections.  Used to simulate a stuck leaf.
| ModifyMLCRandom | percent | Modifies the delivery plan by reducing all open leaves by an average percent (range of reduction is between zero and 2*percent).
| ModifyCouchSpeed | percent | Modifies the delivery plan couch speed uniformly across the entire treatment by percent. Used to simulate a miscalibration.
| ModifyGantryAngle | degree | 
| ModifyGantryRate | degsec |
| ModifyJawFront | distance |
| ModifyJawBack | distance |

### Adding New Failure Mode Plugins


## Comparison Metrics


### Current Installed Metrics


### Adding New Metric Plugins


## Report Files


## Gamma Computation Methods

To compute the 3D gamma analysis metric, a Gamma analysis is performed based on the formalism presented by D. A. Low et. al., [A technique for the quantitative evaluation of dose distributions.](http://www.ncbi.nlm.nih.gov/pubmed/9608475), Med Phys. 1998 May; 25(5): 656-61.  In this formalism, the Gamma quality index *&gamma;* is defined as follows for each point in measured dose/response volume *Rm* given the reference dose/response volume *Rc*:

*&gamma; = min{&Gamma;(Rm,Rc}&forall;{Rc}*

where:

*&Gamma; = &radic; (r^2(Rm,Rc)/&Delta;dM^2 + &delta;^2(Rm,Rc)/&Delta;DM^2)*,

*r(Rm,Rc) = | Rc - Rm |*,

*&delta;(Rm,Rc) = Dc(Rc) - Dm(Rm)*,

*Dc(Rc)* and *Dm(Rm)* represent the reference and measured doses at each *Rc* and *Rm*, respectively, and

*/&Delta;dM* and *&Delta;DM* represent the absolute and Distance To Agreement Gamma criterion (by default 3%/3mm), respectively.  

The absolute criterion is typically given in percent and can refer to a percent of the maximum dose (commonly called the global method) or a percentage of the voxel *Rm* being evaluated (commonly called the local method).  The application is capable of computing gamma using either approach, and can be set in `CalcGammaMetric()` by editing the line `local = 0;` from 0 to 1.  By default, the global method (0) is applied.

The computation applied in the TomoTherapy FMEA Simulation Tool is a 3D algorithm, in that the distance to agreement criterion is evaluated in all three dimensions when determining *min{&Gamma;(Rm,Rc}&forall;{Rc}*. To accomplish this, the modified dose volume is shifted along all three dimensions relative to the reference dose using linear 3D interpolation.  For each shift, *&Gamma;(Rm,Rc}* is computed, and the minimum value *&gamma;* is determined.  To improve computation efficiency, the computation space *&forall;{Rc}* is limited to twice the distance to agreement parameter.  Thus, the maximum "real" Gamma index returned by the application is 2.

## Third Party Statements

SSH/SFTP/SCP for Matlab (v2)
<br>Copyright &copy; 2014, David S. Freedman
<br>All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in
  the documentation and/or other materials provided with the distribution

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
