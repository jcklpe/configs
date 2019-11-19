## Requires ffmpeg and inotify-tools

# testing with this:inotifywait -m . -e create --excludei \.mkv  --format '%w%f' | cat


# inotifywait --monitor . --event create --event move_to --event modify  --format '%w%f'

function compressMP4watch()  {

inotifywait --monitor . --event create --excludei \.mkv  --format '%w%f' |

 while read -r fname
    do

    #take off the mp4
    pathAndName=${fname%.mp4}

    #take off the path from the file name
    videoname=${pathAndName##*/}

    #take off the file name from the path
    videopath=$pathAndName:h

    mkdir -p ${videopath}/compressed/

    ffmpeg -y -i  ${fname} -vcodec libx264 -acodec mp3 -movflags +faststart -crf 18 -r 29.97 ${videopath}/compressed/${videoname}-compressed.mp4

    echo "\033[1;33m compressed ${videoname}\n \033[0m"

    done

}
