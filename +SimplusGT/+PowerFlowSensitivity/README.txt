Run 'MainPFS.m' to calculate and plot the power flow eigenvalue sensitivities for a system.

Run 'TestPFS.m' to calculate and compare these sensitivities to the actual sensitivites.

To use this script eigenshuffle () must be added to your MATLAB path and
'SSCal.m' of the Simplus-GT package must be modified for use eigenshuffle to calculate eigenvalues
Replace line 14 of 'SSCal.m' with the following two lines
"""
[Phi,D]=eigenshuffle(A);
D = diag(D);
"""