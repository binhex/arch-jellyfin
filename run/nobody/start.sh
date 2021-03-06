#!/bin/bash

# specify argument values
config_path="/config"
ffmpeg_file_path="/usr/bin/ffmpeg"

# create folders to store config, data, cache and logs
mkdir -p /config/config /config/data /config/cache /config/logs

# run jellyfin with arguments
/usr/bin/dotnet /usr/lib/jellyfin/jellyfin.dll \
--datadir "${config_path}/data" \
--cachedir "${config_path}/cache" \
--configdir "${config_path}/config" \
--logdir "${config_path}/logs" \
--ffmpeg "${ffmpeg_file_path}"