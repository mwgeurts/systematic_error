## TomoTherapy FMEA Simulation Tool

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2014, University of Wisconsin Board of Regents

The TomoTherapy&reg; Failure Modes and Effects Analysis (FMEA) Tool is a console based application written in MATLAB that simulates various delivery failure modes by parsing [TomoTherapy](http://www.accuray.com) patient archives, modifying the delivery plan, and recomputing the plan dose using the Standalone GPU TomoTherapy Dose Calculator.  Each modified plan dose distribution is then compared using various metrics.  Both the failure modes and metrics are customizable through the use of “plugin” functions, as described below.

TomoTherapy is a registered trademark of Accuray Incorporated.

## Contents


## Installation and Use


## Compatibility and Requirements

This application has been validated using TomoTherapy version 4.2 and 5.0 patient archives on Macintosh OSX 10.10 (Yosemite) and MATLAB R2014b (8.4).  No additional MATLAB toolboxes are required for execution.

## Troubleshooting

This application records key input parameters and results to a log.txt file using the `Event()` function. The log is the most important route to troubleshooting errors encountered by this software.  The author can also be contacted using the information above.  Refer to the license file for a full description of the limitations on liability when using or this software or its components.


## Failure Modes


### Current Installed Failure Modes


### Adding New Failure Mode Plugins


## Comparison Metrics


### Current Installed Metrics


### Adding New Metric Plugins

## Gamma Computation Methods

Following dose re-calculation, a Gamma analysis is performed based on the formalism presented by D. A. Low et. al., [A technique for the quantitative evaluation of dose distributions.](http://www.ncbi.nlm.nih.gov/pubmed/9608475), Med Phys. 1998 May; 25(5): 656-61.  In this formalism, the Gamma quality index *&gamma;* is defined as follows for each point in measured dose/response volume *Rm* given the reference dose/response volume *Rc*:

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
