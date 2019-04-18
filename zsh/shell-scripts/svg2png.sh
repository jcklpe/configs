## Requires node module called svgexport. Allows for cleaner code without aspect ratio issues

function svg2png ()  {
for fname in $1/*.svg
do
pathname=${fname%.svg}
name=${pathname##*/}
svgexport ${pathname}.svg ./$1/converted/${name}.png $2:
   echo "\033[36m converted ${name}.svg to png \033[0m"
done
}
