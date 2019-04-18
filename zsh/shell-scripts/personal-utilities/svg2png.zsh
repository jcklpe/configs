## requires node module svgexport
# used for single conversion operations

function svg2png ()  {
for fname in $1
do

#take off the svg
pathAndName=${fname%.svg}

#take off the path from the file name
iconname=${pathAndName##*/}

#take off the file name from the path
iconpath=$pathAndName:h

svgexport ${fname} ${pathAndName}.png $2:
echo "\033[1;33m converted ${iconname}.svg to png\n \033[0m"
done

}
