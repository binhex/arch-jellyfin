#!/usr/bin/dumb-init /bin/bash

# specify argument values
config_path="/config"
webdir="/usr/share/jellyfin-web"
ffmpeg_file_path="/usr/lib/jellyfin-ffmpeg/ffmpeg"

# create folders to store config, data, cache and logs
mkdir -p /config/config /config/data /config/cache /config/logs

# run jellyfin with arguments
/usr/lib/jellyfin/jellyfin \
--datadir "${config_path}/data" \
--cachedir "${config_path}/cache" \
--configdir "${config_path}/config" \
--logdir "${config_path}/logs" \
--ffmpeg "${ffmpeg_file_path}" \
--webdir "${webdir}"
