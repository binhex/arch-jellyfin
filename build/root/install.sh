#!/bin/bash

# exit script if return code != 0
set -e

# app name from buildx arg, used in healthcheck to identify app and monitor correct process
APPNAME="${1}"
shift

# release tag name from buildx arg, stripped of build ver using string manipulation
RELEASETAG="${1}"
shift

# target arch from buildx arg
TARGETARCH="${1}"
shift

if [[ -z "${APPNAME}" ]]; then
	echo "[warn] App name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${RELEASETAG}" ]]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${TARGETARCH}" ]]; then
	echo "[warn] Target architecture name from build arg is empty, exiting script..."
	exit 1
fi

# jellyfin install source, read from the environment as this is supplied via a Dockerfile
# build arg rather than a positional argument, so the default can be overridden at build
# time without changing the argument list passed by the buildx workflow
jellyfin_source="${JELLYFIN_SOURCE:-upstream}"

if [[ "${jellyfin_source}" != 'arch' && "${jellyfin_source}" != 'upstream' ]]; then
	echo "[warn] Jellyfin source '${jellyfin_source}' is invalid, expecting 'arch' or 'upstream', exiting script..."
	exit 1
fi

# write APPNAME and RELEASETAG to file to record the app name and release tag used to build the image
echo -e "export APPNAME=${APPNAME}\nexport IMAGE_RELEASE_TAG=${RELEASETAG}\n" >> '/etc/image-build-info'

# ensure we have the latest builds scripts
refresh.sh

# pacman packages
####

# call pacman db and package updater script
source upd.sh

# define packages required for hardware transcoding, needed whichever jellyfin install source is used
packages_hardware_transcoding="libva-intel-driver intel-media-driver intel-media-sdk"
packages_hardware_transcoding+=" onevpl-intel-gpu intel-compute-runtime"

# define pacman packages, when installing direct from upstream the jellyfin packages are
# downloaded below rather than installed from the arch repositories, github-cli provides
# the 'gh' utility used to download the jellyfin-ffmpeg release asset. the remaining
# additions are runtime dependencies normally pulled in by the jellyfin-server arch
# package: fontconfig (and in turn freetype2) is required by the bundled skia sharp
# libraries, icu is required by the bundled dotnet runtime for globalization and krb5 is
# required for negotiate/kerberos authentication
if [[ "${jellyfin_source}" == 'arch' ]]; then
	pacman_packages="git ${packages_hardware_transcoding} jellyfin-server jellyfin-web jellyfin-ffmpeg noto-fonts"
else
	pacman_packages="git github-cli fontconfig icu krb5 ${packages_hardware_transcoding} noto-fonts"
fi

# install compiled packages using pacman
if [[ -n "${pacman_packages}" ]]; then
	# arm64 currently targetting aor not archive, so we need to update the system first
	if [[ "${TARGETARCH}" == "arm64" ]]; then
		pacman -Syu --noconfirm
	fi
	pacman -S --needed $pacman_packages --noconfirm
fi

# create /var/empty to fix access denied message from dotnet during build of jellyfin
mkdir -p /var/empty && chmod -R 777 /var/empty

# jellyfin install from upstream
####

# download the latest jellyfin releases direct from jellyfin, nothing is pinned to a
# specific version. the jellyfin server tarball is self contained, it includes the dotnet
# runtime and the web client, so no aspnet-runtime or jellyfin-web package is required
if [[ "${jellyfin_source}" == 'upstream' ]]; then

	if [[ "${TARGETARCH}" == 'arm64' ]]; then
		jellyfin_arch='arm64'
		jellyfin_ffmpeg_asset_regex='portable_linuxarm64-gpl\.tar\.xz$'
	else
		jellyfin_arch='amd64'
		jellyfin_ffmpeg_asset_regex='portable_linux64-gpl\.tar\.xz$'
	fi

	jellyfin_download_path='/tmp/jellyfin'
	jellyfin_server_url="https://repo.jellyfin.org/files/server/linux/latest-stable/${jellyfin_arch}"
	jellyfin_ffmpeg_repo='jellyfin/jellyfin-ffmpeg'

	# curl options used for all upstream downloads, --fail ensures an http error is not
	# written to disk as if it were a valid tarball, retries cover transient failures
	jellyfin_curl_opts=(
		--connect-timeout 5 --max-time 1800 --retry 5 --retry-delay 0 --retry-max-time 120 --fail -sSL
	)

	mkdir -p "${jellyfin_download_path}"

	# identify the latest stable jellyfin server release, the 'latest-stable' path is a
	# rolling pointer so the newest release is always picked up
	jellyfin_server_filename=$(curl "${jellyfin_curl_opts[@]}" "${jellyfin_server_url}/" \
		| grep -oE "jellyfin_[0-9][^\"]*-${jellyfin_arch}\.tar\.xz" | sort -V | tail -1)

	if [[ -z "${jellyfin_server_filename}" ]]; then
		echo "[warn] Unable to identify the latest jellyfin server release, exiting script..."
		exit 1
	fi

	jellyfin_server_version="${jellyfin_server_filename#jellyfin_}"
	jellyfin_server_version="${jellyfin_server_version%-"${jellyfin_arch}".tar.xz}"

	echo "[info] Latest jellyfin server release identified as '${jellyfin_server_version}'"

	# download and extract the jellyfin server
	curl "${jellyfin_curl_opts[@]}" -o "${jellyfin_download_path}/${jellyfin_server_filename}" \
		"${jellyfin_server_url}/${jellyfin_server_filename}"
	tar -xJf "${jellyfin_download_path}/${jellyfin_server_filename}" -C "${jellyfin_download_path}"

	# install the web client to the path referenced in start.sh, the web client is bundled
	# inside the jellyfin server tarball rather than being a separate download
	mkdir -p '/usr/share/jellyfin' '/usr/lib/jellyfin'
	rm -rf '/usr/share/jellyfin/web'
	mv "${jellyfin_download_path}/jellyfin/jellyfin-web" '/usr/share/jellyfin/web'

	# install the jellyfin server, this includes the bundled dotnet runtime together with
	# the native libraries used for image processing, such as skia sharp
	cp -a "${jellyfin_download_path}/jellyfin/." '/usr/lib/jellyfin/'

	# identify the latest jellyfin-ffmpeg release and the asset matching the target arch
	jellyfin_ffmpeg_release=$(curl "${jellyfin_curl_opts[@]}" \
		"https://api.github.com/repos/${jellyfin_ffmpeg_repo}/releases/latest")
	jellyfin_ffmpeg_tag=$(echo "${jellyfin_ffmpeg_release}" | jq -r '.tag_name // empty')
	jellyfin_ffmpeg_asset=$(echo "${jellyfin_ffmpeg_release}" | jq -r --arg regex "${jellyfin_ffmpeg_asset_regex}" \
		'.assets[]? | select(.name | test($regex)) | .name')

	if [[ -z "${jellyfin_ffmpeg_tag}" || -z "${jellyfin_ffmpeg_asset}" ]]; then
		echo "[warn] Unable to identify the latest jellyfin-ffmpeg release, exiting script..."
		exit 1
	fi

	echo "[info] Latest jellyfin-ffmpeg release identified as '${jellyfin_ffmpeg_tag}'"

	curl "${jellyfin_curl_opts[@]}" -o "${jellyfin_download_path}/${jellyfin_ffmpeg_asset}" \
		"https://github.com/${jellyfin_ffmpeg_repo}/releases/download/${jellyfin_ffmpeg_tag}/${jellyfin_ffmpeg_asset}"

	# install jellyfin-ffmpeg, the portable build is self contained and provides the same
	# binaries and paths as the jellyfin-ffmpeg arch package
	mkdir -p '/usr/lib/jellyfin-ffmpeg'
	tar -xJf "${jellyfin_download_path}/${jellyfin_ffmpeg_asset}" -C '/usr/lib/jellyfin-ffmpeg'
	chmod 755 '/usr/lib/jellyfin-ffmpeg/ffmpeg' '/usr/lib/jellyfin-ffmpeg/ffprobe'

	# create the data directory, this is created by the jellyfin-server arch package but
	# not by the upstream tarball
	mkdir -p '/var/lib/jellyfin'

	# remove the downloaded tarballs
	rm -rf "${jellyfin_download_path}"

	# record the versions installed from upstream, useful when investigating issues
	echo -e "export JELLYFIN_VERSION=${jellyfin_server_version}\n" >> '/etc/image-build-info'
	echo -e "export JELLYFIN_FFMPEG_VERSION=${jellyfin_ffmpeg_tag#v}\n" >> '/etc/image-build-info'

fi

# container perms
####

# define comma separated list of paths
install_paths="/usr/lib/jellyfin,/usr/lib/jellyfin-ffmpeg,/var/lib/jellyfin,/home/nobody"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

# In install.sh heredoc, replace the chown section:
cat <<EOF > /tmp/permissions_heredoc
install_paths="${install_paths}"
EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/bin/init.sh
rm /tmp/permissions_heredoc

# env vars
####

# cleanup
cleanup.sh
