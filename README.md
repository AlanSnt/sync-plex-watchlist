# Sync plex watchlist to Radarr and Sonarr
## Description
This is a simple script to sync plex watchlist to Radarr and Sonarr, you can run directly the script or use docker to build and run the container.

The container is cron job to sync plex watchlist to Radarr and Sonarr every day at 00:00.

## Usage

### Directly
1. Overwrite env var in script.sh :
```sh
#!/bin/bash
PLEX_TOKEN="your_plex_token"
RADARR_API_KEY="your_radarr_api_key"
SONARR_API_KEY="your_sonarr_api_key"
TMDB_API_KEY="your_tmdb_api_key"
TVDB_API_KEY="your_tvdb_api_key"

RADARR_IP="your_radarr_ip"
SONARR_IP="your_sonarr_ip"

RADARR_ROOT_FOLDER="your_radarr_root_folder"
SONARR_ROOT_FOLDER="your_sonarr_root_folder"

RADARR_URL="http://${RADARR_IP}:7878/api/v3"
SONARR_URL="http://${SONARR_IP}:8989/api/v3"

# ... rest of the script
```

2. Run script.sh :
```sh
./script.sh
```

### Docker
1. Build image using docker :
```sh
docker build -t sync-plex-watchlist .
```

2. Run container using docker :
```sh
docker run -d \
-e PLEX_TOKEN=your_plex_token \
-e RADARR_API_KEY=your_radarr_api_key \
-e SONARR_API_KEY=your_sonarr_api_key \
-e TMDB_API_KEY=your_tmdb_api_key \
-e TVDB_API_KEY=your_tvdb_api_key \
-e RADARR_IP=your_radarr_ip \
-e SONARR_IP=your_sonarr_ip \
-e RADARR_ROOT_FOLDER=your_radarr_root_folder \
-e SONARR_ROOT_FOLDER=your_sonarr_root_folder \
alansanter/sync-plex-watchlist
```

3. If you want to use with docker compose
```yml
version: '3'
services:
  sync-plex-watchlist:
    image: alansanter/sync-plex-watchlist:latest
    container_name: sync-plex-watchlist
    environment:
      - PLEX_TOKEN=your_plex_token
      - RADARR_API_KEY=your_radarr_api_key
      - SONARR_API_KEY=your_sonarr_api_key
      - TMDB_API_KEY=your_tmdb_api_key
      - TVDB_API_KEY=your_tvdb_api_key
      - RADARR_IP=your_radarr_ip
      - SONARR_IP=your_sonarr_ip
      - RADARR_ROOT_FOLDER=your_radarr_root_folder
      - SONARR_ROOT_FOLDER=your_sonarr_root_folder
    restart: always
```
