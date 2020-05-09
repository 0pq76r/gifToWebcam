#!/bin/bash

if [ -z ${GIPHY_API_KEY+x} ]; then
    GIPHY_API_KEY="dc6zaTOxFJmzC"; # public demo key
fi

usage() {
    echo "$0 [-t 'tag'] -d duration -o /dev/videoN [-p file]"
}

play () {
    ffmpeg -ignore_loop 0 -re -i "$1" -t "$2" -vcodec rawvideo -pix_fmt yuv420p -vf 'scale=1280x720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,hflip' -threads 1 -f v4l2 "$3"
}

giphy_fetch() {
    tag=$(echo "$1" | perl -MURI::Escape -e 'while (<>) {print uri_escape($_);}');
    url=$(curl "https://api.giphy.com/v1/gifs/random?api_key=${GIPHY_API_KEY}&rating=r&tag=$tag" \
              | jq -r '.data.image_url')
    tmpf=/tmp/$(echo "$url" | sed -e 's#/#_#g')
    wget -c -O "$tmpf" "$url" > /dev/null
    echo "$tmpf"
}

main() {
    args=$@;
    tag="bartender";
    duration="100";
    output="/dev/video0";
    while getopts ":d:o:t:p:h" opt; do
        case ${opt} in
	    d)
                duration=$OPTARG;
	        ;;
	    t)
                tag=$OPTARG;
	        ;;
	    o)
                output=$OPTARG;
                ;;
	    p)
	        play "$OPTARG" "$duration" "$output"
                return;
                ;;
            h)
                usage $args;
                return;
                ;;
            *)
                echo "Invalid argument -$OPTARG";
                usage $args;
                return;
                ;;
        esac
    done
    if [ ! -w "$output" ]; then
        ndev=$(echo "$output" | sed -ne 's/[^0-9]//pg');
        sudo modprobe v4l2loopback devices=$((ndev+1));
    fi
    file=$(giphy_fetch "$tag");
    while :; do
        old=$file;
        play "$file" "$duration" "$output" &
        file=$(giphy_fetch "$tag");
        wait;
        rm "$old";
    done
}

main "$@"
