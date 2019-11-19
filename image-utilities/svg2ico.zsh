## Requires node module called svgexport and imagemagick
# for single operational use. takes one parameter

function svg2ico ()  {
for fname in $1/**/*.svg
do

#take off the svg
pathAndName=${fname%.svg}

svgexport ${fname} ${pathAndName}-256tmp.png 256:
svgexport ${fname} ${pathAndName}-128tmp.png 128:
svgexport ${fname} ${pathAndName}-64tmp.png 64:
svgexport ${fname} ${pathAndName}-32tmp.png 32:
svgexport ${fname} ${pathAndName}-24tmp.png 24:
svgexport ${fname} ${pathAndName}-16tmp.png 16:

#convert all pngs into a ico container
convert \
 ${pathAndName}-256tmp.png \
 ${pathAndName}-128tmp.png \
 ${pathAndName}-64tmp.png \
 ${pathAndName}-32tmp.png \
 ${pathAndName}-24tmp.png \
 ${pathAndName}-16tmp.png \
 -background none ${pathAndName}.ico

 #delete residual leftover pngs
rm -rf ${pathAndName}*tmp.png

echo "\033[1;33m converted ${iconname}.svg to ico\n \033[0m"
done

}
