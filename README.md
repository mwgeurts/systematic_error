## TomoTherapy FMEA Simulation Tool

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2015, University of Wisconsin Board of Regents

## Description

The TomoTherapy&reg; Failure Modes and Effects Analysis (FMEA) Tool is a console based application written in MATLAB that simulates various delivery failure modes by parsing [TomoTherapy](http://www.accuray.com) patient archives, modifying the delivery plan, and recomputing the plan dose using the Standalone GPU TomoTherapy Dose Calculator.  Each modified plan dose distribution is then compared using various metrics.  Both the failure modes and metrics are customizable through the use of “plugin” functions, as described in the [wiki](../../wiki/).

## Installation

This application can be installed by cloning this git repository.  See [Installation and Use](../../wiki/Installation-and-Use) for more details.

## Usage and Documentation

Please see the [wiki](../../wiki) for basic usage and other documentation on using the TomoTherapy FMEA Simulation Tool.

## License

Released under the GNU GPL v3.0 License.  See the [license](license) file for further details.
