#!/bin/bash
# set variables
CONFIGS="${HOME}/configs";

#init all submodules recursively
cd ..;
git submodule init;
git submodule update --recursive ;

#run shared install processes
source ./linux-win-install.sh