#!/bin/bash
RADARR_URL="http://${RADARR_IP}:7878/api/v3"
SONARR_URL="http://${SONARR_IP}:8989/api/v3"

get_radarr_quality_profile_id() {
    quality_profiles_url="${RADARR_URL}/qualityProfile?apikey=${RADARR_API_KEY}"
    response=$(curl -s "$quality_profiles_url")
    if [[ $(echo "$response" | jq '. | length') -gt 0 ]]; then
        profile_id=$(echo "$response" | jq '.[] | select(.name == "Ultra-HD VF") | .id')
        echo "$profile_id"
    else
        echo "Failed to retrieve quality profiles."
        exit 1
    fi
}

get_sonarr_quality_profile_id() {
    quality_profiles_url="${SONARR_URL}/qualityProfile?apikey=${SONARR_API_KEY}"
    response=$(curl -s "$quality_profiles_url")
    if [[ $(echo "$response" | jq '. | length') -gt 0 ]]; then
        profile_id=$(echo "$response" | jq '.[] | select(.name == "HD-1080p") | .id')
        echo "$profile_id"
    else
        echo "Failed to retrieve quality profiles."
        exit 1
    fi
}

get_tvdb_token() {
    payload=$(jq -n --arg key "$TVDB_API_KEY" '{apikey: $key,}')
    response=$(curl -s -H "Content-Type: application/json" -X POST -d "$payload" "https://api4.thetvdb.com/v4/login")

    if [[ $(echo "$response" | jq -e '.status') ]]; then
        id=$(echo "$response" | jq -r '.data.token')
        echo "$id"
    else
        echo "Failed to retrieve TVDB TOKEN."
        exit 1
    fi

}

RADARR_QUALITY_PROFILE=$(get_radarr_quality_profile_id)
SONARR_QUALITY_PROFILE=$(get_sonarr_quality_profile_id)
TVDB_TOKEN=$(get_tvdb_token)

fetch_plex_watchlist() {
    echo "Fetching Plex watchlist..."
    plex_url="https://metadata.provider.plex.tv/library/sections/watchlist/all?X-Plex-Token=${PLEX_TOKEN}"
    response=$(curl -s "$plex_url")
    root=$(echo "$response" | xmllint --xpath '//Directory | //Video' -)
    echo "$root"
}

fetch_tmdb_id() {
    title="$1"
    year="$2"

    if [ -z "$title" ]; then
        echo "No title given. Skipping."
        return
    fi

    search_url="https://api.themoviedb.org/3/search/movie?api_key=${TMDB_API_KEY}&language=en-US&query=${title}&year=${year}&page=1&include_adult=false"
    response=$(curl -s "$search_url")

    if [[ $(echo "$response" | jq -r '.results | length') -gt 0 ]]; then
        tmdb_id=$(echo "$response" | jq -r '.results[0].id')

        if [ -n "$tmdb_id" ]; then
            echo "$tmdb_id"
        fi
    fi
}

fetch_tvdb_id() {
    title="$1"
    year="$2"

    if [ -z "$title" ]; then
        echo "No title given. Skipping."
        return
    fi

    search_url="https://api4.thetvdb.com/v4/search?query=${title}&year=${year}"
    response=$(curl -s "$search_url" -H "Authorization: Bearer ${TVDB_TOKEN}")

    if [[ $(echo "$response" | jq -r '.data | length') -gt 0 ]]; then
        tvdb_id=$(echo "$response" | jq -r '.data[0].tvdb_id')

        if [ -n "$tvdb_id" ]; then
            echo "$tvdb_id"
        fi
    fi
}

add_to_radarr() {
    tmdb_id="$1"
    title="$2"

    if [ -z "$tmdb_id" ]; then
        echo "No TMDB ID given. Skipping."
        return
    fi

    if [ -z "$title" ]; then
        echo "No title given. Skipping."
        return
    fi

    echo "Adding movie '$title' to Radarr..."
    payload=$(jq -n --arg title "$title" --arg tmdb_id "$tmdb_id" --arg qualityProfileId "$RADARR_QUALITY_PROFILE" --arg rootFolderPath "$RADARR_ROOT_FOLDER" --arg monitored "true" '{title: $title, tmdbId: $tmdb_id, qualityProfileId: $qualityProfileId, rootFolderPath: $rootFolderPath, monitored: true}')
    response=$(curl -s -H "Content-Type: application/json" -X POST -d "$payload" "${RADARR_URL}/movie?apikey=${RADARR_API_KEY}")

    if [[ $(echo "$response" | jq 'if type == "array" then 1 else 0 end') -eq 1 ]]; then
        echo "Failed to add movie '$title' to Radarr. (array)"
    else
        if [[ $(echo "$response" | jq -e '.id') ]]; then
            echo "Added movie '$title' to Radarr successfully"
        else
            echo "Failed to add movie '$title' to Radarr."
        fi
    fi
}

add_to_sonarr() {
    tvdb_id="$1"
    title="$2"

    if [ -z "$tvdb_id" ]; then
        echo "No TVDB ID given. Skipping."
        return
    fi

    if [ -z "$title" ]; then
        echo "No title given. Skipping."
        return
    fi

    echo "Adding show '$title' to Sonarr..."
    payload=$(jq -n --arg title "$title" --arg tvdbId "$tvdb_id" --arg qualityProfileId "$SONARR_QUALITY_PROFILE" --arg rootFolderPath "$RADARR_ROOT_FOLDER" --arg monitored "true" '{title: $title, tvdbId: $tvdbId, qualityProfileId: $qualityProfileId, rootFolderPath: $rootFolderPath, monitored: true}')
    response=$(curl -s -H "Content-Type: application/json" -X POST -d "$payload" "${SONARR_URL}/series?apikey=${SONARR_API_KEY}")

    if [[ $(echo "$response" | jq 'if type == "array" then 1 else 0 end') -eq 1 ]]; then
        echo "Failed to add show '$title' to Sonarr. (array)"
    else
        if [[ $(echo "$response" | jq -e '.id') ]]; then
            echo "Added show '$title' to Sonarr successfully"
        else
            echo "Failed to add show '$title' to Sonarr."
        fi
    fi
}

normalize_title() {
    local input_title=$1
    local normalized_title

    # Supprimer l'année entre parenthèses du titre
    normalized_title=$(echo "$input_title" | sed 's/ ([0-9][0-9][0-9][0-9])//g')

    # Remplacer les caractères spéciaux par leurs équivalents URL
    normalized_title=$(echo "$normalized_title" | sed 's/ /%20/g')

    echo "$normalized_title"
}

main() {
    echo "Starting script..."
    watchlist=$(fetch_plex_watchlist)

    echo "Processing Plex watchlist..."
    while IFS= read -r line; do
        media_type=$(echo "$line" | awk -F 'type="' '{print $2}' | awk -F '"' '{print $1}')
        title=$(echo "$line" | awk -F 'title="' '{print $2}' | awk -F '"' '{print $1}')
        year=$(echo "$line" | awk -F 'year="' '{print $2}' | awk -F '"' '{print $1}')
        normalized_title=$(normalize_title "$title")

        if [ -z "$title" ]; then
            echo "No title found. Skipping."
            continue
        fi

        if [ -z "$media_type" ]; then
            echo "No media type found. Skipping."
            continue
        fi

        if [[ $media_type == "show" ]]; then
            id=$(fetch_tvdb_id "$normalized_title" "$year")
        else
            id=$(fetch_tmdb_id "$normalized_title" "$year")
        fi

        if [ -z "$id" ]; then
            echo "No ID found for '$media_type' '$title' '$year'. Skipping."
            continue
        fi

        echo "Processing ($id) $media_type '$title' '$year'..."

        if [[ $media_type == "show" ]]; then
            add_to_sonarr "$id" "$title"
        elif [[ $media_type == "movie" ]]; then
            add_to_radarr "$id" "$title"
        fi
    done <<<"$watchlist"
}

main
