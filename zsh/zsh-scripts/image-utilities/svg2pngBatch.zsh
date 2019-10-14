## requires node module svgexport

function svg2pngBatch ()  {
for fname in $1/**/*.svg
do

#take off the svg
pathAndName=${fname%.svg}

#take off the path from the file name
iconname=${pathAndName##*/}

#take off the file name from the path
iconpath=$pathAndName:h

svgexport ${fname} ${iconpath}/png-converted/${iconname}.png 500:
echo "\033[1;33m converted ${iconname}.svg to png\n \033[0m"
done

}
