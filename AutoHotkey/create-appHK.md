1. Install AHK

2. write a file that contains the following config. 
`
^+.:: ; ctrl+shift+. to launch hyper.js
Run C:\Users\{{YOUR USERNAME}}\AppData\Local\hyper\app-2.0.0\Hyper.exe
Return
`

3. Hit the win key and type `run` to open the windows runner. 

4. type `shell:startup` to open the Windows shell startup folder. 

5. Place the file.ahk in the folder. 

Now that ahk script will always register itself at start time. 


These steps can be used to make any global application launching shortcut but this was the specific tool I needed and maybe you do too. 

This AHK tool is espc useful when paired with the hyperterm-summon plugin: https://github.com/soutar/hyperterm-summon