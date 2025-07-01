# Application

[Jellyfin](https://github.com/jellyfin/jellyfin)

## Description

Jellyfin is a Free Software Media System that puts you in control of managing
and streaming your media. It is an alternative to the proprietary Emby and Plex,
to provide media from a dedicated server to end-user devices via multiple apps.
Jellyfin is descended from Emby's 3.5.2 release and ported to the .NET Core
framework to enable full cross-platform support. There are no strings attached,
no premium licenses or features, and no hidden agendas: just a team who want to
build something better and work together to achieve it.

## Build notes

Latest stable Jellyfin release from AUR.

## Usage

```bash
docker run -d \

    -p 8096:8096 \
    --name=<container name> \
    -v <path for media files>:/media \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \

    binhex/arch-jellyfin

```

Please replace all user variables in the above command defined by <> with the
correct values.

## Access application

`<host ip>:8096`

## Example

```bash
docker run -d \

    -p 8096:8096 \
    --name=<container name> \
    -v /media/movies:/media \
    -v /apps/docker/jellyfin/config:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e UMASK=000 \
    -e PUID=0 \
    -e PGID=0 \

    binhex/arch-jellyfin

```

## Notes

User ID (PUID) and Group ID (PGID) can be found by issuing the following command
for the user you want to run the container as:-

```bash
id <username>

```

___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](https://forums.unraid.net/topic/77506-support-binhex-jellyfin/)
