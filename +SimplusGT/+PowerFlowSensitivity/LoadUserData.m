% Loads the user data into the MATLAB Workspace as a Structure
% Modified section from +Toolbox/Main.m
function [UserData,UserDataStruct] = LoadUserData(UserDataName,UserDataType,verbose)
arguments
    UserDataName
    UserDataType
    verbose = false
end
%% Chech the input data type and convert it to struct
if verbose
fprintf('\n')
fprintf('==================================\n')
fprintf('Check User Data File\n')
fprintf('==================================\n')
end
if UserDataType == 1
    UserData = [UserDataName, '.xlsx'];
    if isempty(which(UserData))
        UserData = [UserDataName,'.xlsm'];
        if isempty(which(UserData))
            error(['Error: The Excel format of "' UserDataName '" cannot be found.'])
        end
    end
    SimplusGT.Toolbox.Excel2Json(UserData);
elseif UserDataType == 0
else
    error('Error: Please check the setting of "UserDataType", which should be "1" or "0".')
end
UserData = [UserDataName, '.json'];
if isempty(which(UserData))
    error(['Error: The json format of "' UserDataName '" cannot be found.'])
end
if verbose
fprintf([UserData,' is used for analysis.\n'])
which(UserData)
end
UserDataStruct = SimplusGT.JsonDecoder(UserData);
end