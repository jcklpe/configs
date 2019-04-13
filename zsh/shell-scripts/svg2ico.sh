```
mkdir temp; declare -a res=(16 24 32 48 64 128 256); for f in *.svg; do for r in "${res[@]}"; do inkscape -z -e temp/${f}${r}.png -w $r -h $r $f; done; resm=( "${res[@]/#/temp/$f}" ); resm=( "${resm[@]/%/.png}" ); convert "${resm[@]}" ${f%%.*}.ico; done; rm -rf temp;
```
`mogrify -path ../PathToFolder/ -format ico -density 600 -define icon:auto-resize=128,64,48,32,16 *.svg`
