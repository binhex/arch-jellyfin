#!/bin/bash

# config below is taken from bash script /usr/bin/jellyfin.sh

# set env variables for jellyfin
export MONO='/usr/bin/mono'
export PROGRAM_DATA='/config'
export FFMPEG='/usr/bin/ffmpeg'
export FFPROBE='/usr/bin/ffprobe'

# run jellyfin
exec '/usr/bin/jellyfin'
