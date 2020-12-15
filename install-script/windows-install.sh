#!/bin/bash
##- VARIABLES
# set path for the winhome and configs
WINHOME=$(wslpath $(cmd.exe /C "echo %USERPROFILE%"));
WINHOME=${WINHOME//$'\015'};
CONFIGS="${WINHOME}/home/Documents/configs";

#run shared install processes
source ./linux-win-install.sh
