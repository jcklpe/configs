#!/bin/bash
##- symlink stuff to $WINHOME
cp -f ${CONFIGS}/hyper-js/windows.hyper.js ${WINHOME}/AppData/Roaming/Hyper/.hyper.js
ln -sf  ${CONFIGS}/vscode/settings.json ${WINHOME}/AppData/Roaming/Code/User/settings.json

ln -sf ${CONFIGS}/nextcloud/sync-exclude.lst ${WINHOME}/AppData/Roaming/Nextcloud/sync-exclude.lst
ln -lf ${CONFIGS}/ueli/config.json ${WINHOME}/AppData/Roaming/ueli/config.json


#/AppData/Roaming/Blender/user-pref.blend
