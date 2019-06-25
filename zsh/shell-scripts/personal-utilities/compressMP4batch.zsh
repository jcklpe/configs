## Requires ffmpeg

function compressMP4batch()  {
for fname in *.mp4
do

#take off the mp4
pathAndName=${fname%.mp4}

#take off the path from the file name
videoname=${pathAndName##*/}

#take off the file name from the path
videopath=$pathAndName:h

#create new folder for converted icons to be placed in
mkdir -p ${videopath}/compressed/

ffmpeg -y -r 30 -i ${fname} -vcodec libx265 -b:v 700k -acodec mp3 ${videopath}/compressed/${videoname}-compressed.mp4



echo "\033[1;33m compressed ${videoname}\n \033[0m"
done

}
