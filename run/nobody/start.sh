#!/bin/bash

# specify argument values
config_path="/config"
ffmpeg_file_path="/usr/bin/ffmpeg"
ffprobe_file_path="/usr/bin/ffprobe"

# move older config to new structure - temporary hack, remove in a few builds time
mkdir -p /config/config
mv -f /config/dlna /config/config/ 2> /dev/null
mv -f /config/logging.json /config/config/ 2> /dev/null
mv -f /config/system.xml /config/config/ 2> /dev/null
mv -f /config/users /config/config/ 2> /dev/null

# move older data to new structure - temporary hack, remove in a few builds time
mkdir -p /config/data
find /config/data -maxdepth 1 -type f -exec mv {} /config/data/data/ \;
mv -f /config/data/ScheduledTasks /config/data/data/ScheduledTasks/ 2> /dev/null
mv -f /config/data/playlists /config/data/data/playlists/ 2> /dev/null
mv -f /config/localization /config/data/ 2> /dev/null
mv -f /config/root /config/data/root/ 2> /dev/null

# move older data to new structure - temporary hack, remove in a few builds time
mkdir -p /config/logs
mv -f /config/log*.log /config/logs/ 2> /dev/null

# run jellyfin with arguments
/usr/bin/dotnet /usr/lib/jellyfin/jellyfin.dll \
--datadir "${config_path}/data" \
--cachedir "${config_path}/cache" \
--configdir "${config_path}/config" \
--logdir "${config_path}/logs" \
--ffmpeg "${ffmpeg_file_path}" \
--ffprobe "${ffprobe_file_path}"