# Simplus-Grid-Tool-Power-Flow-Sensitivities

This respository contains a modified version of the [**Simplus Grid Tool**](https://github.com/Future-Power-Networks/Simplus-Grid-Tool) 
that has been built upon to allow for the calculation of eigenvalue sensitivities to 
perturbation in power injections. The examples included (Examples/PowerFlowSensitivity) were used to generate the results 
of the paper [**"System Strength Sensitivity to Power Flow Perturbations in AC Power Systems with
Inverter-based Resources"**]() by Trager Joswig-Jones, Baosen Zhang, Shuan Dong, and Jin Tan.

The development of this modified repository was primarily done by [Trager Joswig-Jones](https://github.com/TragerJoswig-Jones) (joswitra@uw.edu) during 
a summer internship at the [National Renewable Energy Laboratory](https://github.com/NREL).

The installation instructions for the Simplus Grid Tool and other information can be found [below](#Quick-Start). 
To run the files within the PowerFlowSensitivity folder, ensure that the dependencies subfolders have been added to your MATLAB path.
To generate the heat maps and test results presented in the paper run the ```PFSUserMain.m``` file with the specified system case.

## Citation

If you use this modified version of the Simplus-GT toolbox, please cite the following paper
```
@inproceedings{Joswig-Jones_PFS_2025,
      title={System Strength Sensitivity to Power Flow Perturbations in AC Power Systems with Inverter-based Resources},
      url={},
      DOI={},
      booktitle={},
      publisher={},
      author={Joswig-Jones, Trager and Zhang, Baosen and Dong, Shuan and Tan, Jin},
      year={2025}
}
```
as well as the original toolbox at "[github.com/Future-Power-Networks/Simplus-Grid-Tool](github.com/Future-Power-Networks/Simplus-Grid-Tool)".

## Simplus Grid Tool (Version: v2025-Sep-11*)

Simplus Grid Tool (SimplusGT in short) is an open-source tool for dynamic analysis and time-domain simulation of power systems (large-scale 100+ bus systems, SG-IBR-composite systems, AC or DC or hybrid AC-DC systems, HVDC systems, etc). The tool is based on Matlab/Simulink.

![](https://raw.githubusercontent.com/Future-Power-Networks/Simplus-Grid-Tool/master/Documentations/Figures/SoftwareExample.png)

### System Requirement

Matlab 2020a or later, with Simulink, Simscape/PowerSystem.

### Quick Start

Copy the repository (download all codes) into your PC, and run "InstallSimplusGT.m" by Matlab. That's all! 

Run "UserMain.m" and you will automatically get results of an example 4-bus power system whose default parameters are saved in "UserData.xlsm". More examples can be found in "Examples" folder.

### Documentations

The comments in "UserMain.m" and "UserData.xlsm" are very important. Please read them carefully. More details can be found in manuals in "Documentations" folder.

