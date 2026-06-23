# Jellyfin ARR Stack

Complete Docker Compose media stack for Jellyfin with request management, media automation, indexer management, downloads, and subtitles.

## Services

| Service | URL | Purpose |
| --- | --- | --- |
| Jellyfin | `http://<server-ip>:8096` | Media server and playback |
| Jellyseerr | `http://<server-ip>:5055` | Movie and TV request portal |
| Radarr | `http://<server-ip>:7878` | Movie automation |
| Sonarr | `http://<server-ip>:8989` | TV automation |
| Prowlarr | `http://<server-ip>:9696` | Indexer management for Radarr and Sonarr |
| qBittorrent | `http://<server-ip>:8080` | Torrent download client |
| Bazarr | `http://<server-ip>:6767` | Subtitle automation |

Replace `<server-ip>` with the IP address or hostname of the Docker host. On the same machine, use `localhost`.

This stack is intended for local network use only. Do not forward these ports on your router or expose them directly to the public internet.

## Stack Layout

This compose file stores application config in the project directory and media/download data outside the repo under `/mnt` by default.

```text
JellyFin/
|-- docker-compose.yaml
|-- Makefile
|-- jellyfin/config/
|-- jellyfin/cache/
|-- jellyseerr/config/
|-- radarr/config/
|-- sonarr/config/
|-- prowlarr/config/
|-- qbittorrent/config/
`-- bazarr/config/

/mnt/media/
|-- movies/
`-- tv/

/mnt/downloads/
```

## Requirements

- Docker Engine
- Docker Compose plugin
- Linux host recommended for `/dev/dri` hardware transcoding passthrough
- Media mounted at `/mnt/media`, or set `MEDIA_ROOT`
- Downloads mounted at `/mnt/downloads`, or set `DOWNLOADS_ROOT`

The compose file defaults to `PUID=1000`, `PGID=1000`, `TZ=Africa/Johannesburg`, `MEDIA_ROOT=/mnt/media`, and `DOWNLOADS_ROOT=/mnt/downloads`. Make sure the user and group IDs match the host user that should own the config, media, and download files.

If the target host will not use hardware transcoding, remove the Jellyfin `devices` entry for `/dev/dri` before starting the stack.

You can override these values when starting the stack:

```bash
PUID=1001 PGID=1001 TZ=Etc/UTC MEDIA_ROOT=/mnt/storage/media DOWNLOADS_ROOT=/mnt/storage/downloads docker compose up -d
```

## Make Targets

If `make` is not installed on the host, install it first:

```bash
sudo apt-get install -y make
```

Install Docker Engine and the Docker Compose plugin on an Ubuntu-based host:

```bash
make deps
```

Create the default media and download folders:

```bash
make media-dirs
```

Prompt for the media and download folder locations:

```bash
make media-dirs-prompt
```

Create folders using explicit paths:

```bash
make media-dirs MEDIA_ROOT=/mnt/storage/media DOWNLOADS_ROOT=/mnt/storage/downloads
```

## Prepare Folders

Create the media and download folders before starting the stack:

```bash
sudo mkdir -p /mnt/media/movies /mnt/media/tv /mnt/downloads
sudo chown -R 1000:1000 /mnt/media /mnt/downloads
```

Docker will create the local config folders automatically, but creating them up front is also fine:

```bash
mkdir -p jellyfin/config jellyfin/cache
mkdir -p jellyseerr/config radarr/config sonarr/config prowlarr/config
mkdir -p qbittorrent/config bazarr/config
```

## Start the Stack

From this directory:

```bash
docker compose up -d
```

If you use non-default media paths, pass the same values to Compose:

```bash
MEDIA_ROOT=/mnt/storage/media DOWNLOADS_ROOT=/mnt/storage/downloads docker compose up -d
```

Check container status:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f
```

View one service:

```bash
docker compose logs -f jellyfin
```

## First Run Setup

### Jellyfin

1. Open `http://<server-ip>:8096`.
2. Complete the setup wizard.
3. Add media libraries:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
4. If the host supports Intel/AMD hardware acceleration through `/dev/dri`, enable hardware transcoding in the Jellyfin admin dashboard.

Jellyfin is configured with `network_mode: host`, so it uses the host network directly instead of a Docker port mapping.

### qBittorrent

1. Open `http://<server-ip>:8080`.
2. Sign in using the initial credentials shown by the container logs if prompted.
3. Set the default save path to `/downloads`.
4. Keep the Web UI port as `8080`.

Useful log command:

```bash
docker compose logs qbittorrent
```

### Prowlarr

1. Open `http://<server-ip>:9696`.
2. Add your indexers.
3. Connect Prowlarr to Radarr and Sonarr:
   - Radarr URL: `http://radarr:7878`
   - Sonarr URL: `http://sonarr:8989`
4. Use each app's API key from its settings page.

### Radarr

1. Open `http://<server-ip>:7878`.
2. Set the root folder to `/movies`.
3. Add qBittorrent as the download client:
   - Host: `qbittorrent`
   - Port: `8080`
   - Category: `movies`
4. Confirm completed downloads import from `/downloads`.

### Sonarr

1. Open `http://<server-ip>:8989`.
2. Set the root folder to `/tv`.
3. Add qBittorrent as the download client:
   - Host: `qbittorrent`
   - Port: `8080`
   - Category: `tv`
4. Confirm completed downloads import from `/downloads`.

### Bazarr

1. Open `http://<server-ip>:6767`.
2. Connect Bazarr to Radarr and Sonarr using their API keys.
3. Confirm paths match:
   - Movies: `/movies`
   - TV: `/tv`

### Jellyseerr

1. Open `http://<server-ip>:5055`.
2. Connect Jellyseerr to Jellyfin using `http://host.docker.internal:8096`.
3. Connect Jellyseerr to Radarr and Sonarr using their API keys.
4. Send requests to the matching root folders and quality profiles.

## Networking Notes

Most services are on the default Docker Compose network and can reach each other by service name:

```text
radarr
sonarr
prowlarr
qbittorrent
bazarr
jellyseerr
```

Use those service names for app-to-app settings inside the stack. Use `<server-ip>` only when accessing the web interfaces from a browser.

Jellyfin is the exception because it runs in host network mode. Jellyseerr includes a `host.docker.internal` mapping so it can reach Jellyfin at `http://host.docker.internal:8096`.

For a LAN-only deployment:

- Keep router port forwarding disabled for all stack ports.
- Use the Linux host firewall to restrict access to the local subnet, especially for Jellyfin because it uses host networking and is not controlled by Docker port bindings.
- Use a VPN such as WireGuard or Tailscale if remote access is needed later.

## Volumes and Paths

| Host Path | Container Path | Used By |
| --- | --- | --- |
| `./jellyfin/config` | `/config` | Jellyfin |
| `./jellyfin/cache` | `/cache` | Jellyfin |
| `${MEDIA_ROOT:-/mnt/media}` | `/media:ro` | Jellyfin |
| `./jellyseerr/config` | `/app/config` | Jellyseerr |
| `./radarr/config` | `/config` | Radarr |
| `${MEDIA_ROOT:-/mnt/media}/movies` | `/movies` | Radarr, Bazarr |
| `./sonarr/config` | `/config` | Sonarr |
| `${MEDIA_ROOT:-/mnt/media}/tv` | `/tv` | Sonarr, Bazarr |
| `./prowlarr/config` | `/config` | Prowlarr |
| `./qbittorrent/config` | `/config` | qBittorrent |
| `${DOWNLOADS_ROOT:-/mnt/downloads}` | `/downloads` | Radarr, Sonarr, qBittorrent |
| `./bazarr/config` | `/config` | Bazarr |

Jellyfin mounts the media root read-only. Radarr, Sonarr, and Bazarr mount their specific media folders with write access.

## Maintenance

Update images and restart:

```bash
docker compose pull
docker compose up -d
```

Restart one service:

```bash
docker compose restart jellyfin
```

Stop the stack without removing containers:

```bash
docker compose stop
```

Stop and remove containers without deleting config or media:

```bash
docker compose down
```

Remove unused Docker images:

```bash
docker image prune
```

## Backups

Back up the local config folders regularly:

```text
jellyfin/
jellyseerr/
radarr/
sonarr/
prowlarr/
qbittorrent/
bazarr/
```

The media and download folders live outside this repo under `MEDIA_ROOT` and `DOWNLOADS_ROOT`.

## Troubleshooting

If a web UI does not load, check that the container is running:

```bash
docker compose ps
```

If imports fail, check permissions on `MEDIA_ROOT` and `DOWNLOADS_ROOT`, then confirm the same paths are configured inside Radarr, Sonarr, and qBittorrent.

If hardware transcoding does not work, confirm the host exposes `/dev/dri`:

```bash
ls -ld /dev/dri
```

If qBittorrent credentials are not known, inspect its logs:

```bash
docker compose logs qbittorrent
```

## Current Compose Defaults

- Timezone: `Africa/Johannesburg`
- User/group IDs: `1000:1000` for LinuxServer.io services
- qBittorrent Web UI port: `8080`
- Jellyfin host media path: `${MEDIA_ROOT:-/mnt/media}`
- Download path: `${DOWNLOADS_ROOT:-/mnt/downloads}`
- Jellyfin hardware device mount: `/dev/dri`
