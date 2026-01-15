# Power Flow Sensitivities

This folder contains the system data files used to generate the results in the paper
[**"System Strength Sensitivity to Power Flow Perturbations in AC Power Systems with
Inverter-based Resources"**]() by Trager Joswig-Jones, Baosen Zhang, Shuan Dong, and Jin Tan. 

The main files used to generate the results are ```MainPFS.m``` and ```TestPFS.m``` 
located in the directory ```+SimplusGT/+PowerFlowSensitivity```. ```MainPFS.m``` 
calculates the eigenvalue sensitivities to power injections at all buses and plots
heat maps of metrics reflecting the largest eigenvalue sensitivities at each bus. 
```TestPFS.m``` compares the true eigenvalue sensitivities found by perturbing 
a power injection value to the calculated eigenvalue sensitivities found using
our approach.