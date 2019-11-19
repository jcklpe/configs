## Requires image magick
function png2ico ()  {
for fname in $1/**/*.png
do
# this is basically the same version as batch but I don't have time to convert this over

#take off the png
pathAndName=${fname%.png}

#take off the path from the file name
iconname=${pathAndName##*/}

#take off the file name from the path
iconpath=$pathAndName:h

#create new folder for converted icons to be placed in
# -p makes mkdir idempotent. Remember this word!
mkdir -p ${iconpath}/ico-converted/



     convert -background transparent $fname  -define icon:auto-resize=16,32,48,64,256 ${iconpath}/ico-converted/${iconname}.ico




echo "\033[1;33m converted ${iconname}.png to ico\n \033[0m"
done

}
