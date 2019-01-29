#!/bin/bash

# set env variables for jellyfin
export JELLYFIN_DATA="/tmp"
export JELLYFIN_ADD_OPTS=""
export FFMPEG="/usr/bin/ffmpeg"
export FFPROBE="/usr/bin/ffprobe"

# run jellyfin
/usr/bin/dotnet /usr/lib/jellyfin/jellyfin.dll -programdata "${JELLYFIN_DATA}" "${JELLYFIN_ADD_OPTS}"
