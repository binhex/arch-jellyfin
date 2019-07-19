# download statically compiled ffmpeg
curly.sh -rc 6 -rw 10 -of /tmp/download.tar.xz --url https://www.johnvansickle.com/ffmpeg/old-releases/ffmpeg-4.0.3-64bit-static.tar.xz

# unpack
cd /tmp && tar -xvf /tmp/download.tar.xz

chmod +x /tmp/ffmpeg*/*

# move statically built ffmpeg and ffprobe
mv /tmp/ffmpeg*/ffmpeg /usr/bin/  
mv /tmp/ffmpeg*/ffprobe /usr/bin/

# remove source zip files
rm -rf /tmp/download.tar.xz /tmp/ffmpeg*