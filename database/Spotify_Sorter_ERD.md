```mermaid

erDiagram
%% ============================================================
SOURCE DATA
%% ============================================================

USERS {
    BIGINT id PK
    TEXT spotify_user_id UK
    TEXT display_name
    TIMESTAMPTZ created_at
}

ALBUMS {
    BIGINT id PK
    TEXT spotify_album_id UK
    TEXT name
    DATE release_date
    TIMESTAMPTZ created_at
}

ARTISTS {
    BIGINT id PK
    TEXT spotify_artist_id UK
    TEXT name
    TIMESTAMPTZ created_at
}

SONGS {
    BIGINT id PK
    TEXT spotify_track_id UK
    TEXT isrc
    TEXT song_name
    INTEGER duration_ms
    DATE release_date
    INTEGER release_year
    BIGINT album_id FK
    TIMESTAMPTZ created_at
    TIMESTAMPTZ updated_at
}

GENRES {
    BIGINT id PK
    TEXT name UK
}

SONG_ARTISTS {
    BIGINT song_id PK, FK
    BIGINT artist_id PK, FK
    TEXT artist_role
}

SONG_GENRES {
    BIGINT song_id PK, FK
    BIGINT genre_id PK, FK
    TEXT source
}

SOURCE_PLAYLISTS {
    BIGINT id PK
    TEXT spotify_playlist_id UK
    BIGINT user_id FK
    TEXT name
    TEXT description
    TEXT snapshot_id
    TIMESTAMPTZ created_at
    TIMESTAMPTZ updated_at
}

SOURCE_PLAYLIST_SONGS {
    BIGINT playlist_id PK, FK
    BIGINT song_id PK, FK
    INTEGER position PK
    TIMESTAMPTZ added_at
}

SONG_AUDIO_FEATURES {
    BIGINT id PK
    BIGINT song_id FK
    NUMERIC tempo
    NUMERIC energy
    NUMERIC danceability
    NUMERIC valence
    NUMERIC acousticness
    NUMERIC instrumentalness
    NUMERIC speechiness
    NUMERIC liveness
    NUMERIC loudness
    TEXT source
    TIMESTAMPTZ retrieved_at
}

SONG_METADATA {
    BIGINT song_id PK, FK
    TEXT era
    TIMESTAMPTZ created_at
    TIMESTAMPTZ updated_at
}


%% ============================================================
%% CLUSTERING
%% ============================================================

CLUSTERING_RUNS {
    BIGINT id PK
    TEXT name
    TEXT algorithm
    INTEGER k
    JSONB features_used
    TEXT normalisation_method
    INTEGER random_seed
    TIMESTAMPTZ created_at
}

CLUSTERS {
    BIGINT id PK
    BIGINT clustering_run_id FK
    INTEGER cluster_number
    INTEGER song_count
}

SONG_CLUSTERS {
    BIGINT clustering_run_id PK, FK
    BIGINT cluster_id FK
    BIGINT song_id PK, FK
    NUMERIC distance_from_centroid
}

CLUSTER_PROFILES {
    BIGINT cluster_id PK, FK
    NUMERIC avg_tempo
    NUMERIC avg_energy
    NUMERIC avg_danceability
    NUMERIC avg_valence
    NUMERIC avg_acousticness
    NUMERIC avg_instrumentalness
    NUMERIC avg_speechiness
    NUMERIC avg_liveness
    NUMERIC avg_loudness
}

CLUSTER_GENRES {
    BIGINT cluster_id PK, FK
    BIGINT genre_id PK, FK
    INTEGER song_count
    NUMERIC percentage
}

CLUSTER_REPRESENTATIVES {
    BIGINT cluster_id PK, FK
    BIGINT song_id PK, FK
    NUMERIC distance_from_centroid
    INTEGER rank
}


%% ============================================================
%% AI CURATION
%% ============================================================

CURATION_RUNS {
    BIGINT id PK
    BIGINT user_id FK
    BIGINT clustering_run_id FK
    TEXT model
    TEXT prompt_version
    TEXT status
    TIMESTAMPTZ created_at
    TIMESTAMPTZ completed_at
}

CURATED_PLAYLISTS {
    BIGINT id PK
    BIGINT curation_run_id FK
    TEXT playlist_key
    TEXT name
    TEXT description
    TEXT energy
    TEXT tempo
    TEXT vocal_character
    TEXT rationale
    TIMESTAMPTZ created_at
}

CURATED_PLAYLIST_GENRES {
    BIGINT playlist_id PK, FK
    TEXT genre PK
}

CURATED_PLAYLIST_ERAS {
    BIGINT playlist_id PK, FK
    TEXT era PK
}

CURATED_PLAYLIST_VIBES {
    BIGINT playlist_id PK, FK
    TEXT vibe PK
}

CURATED_PLAYLIST_CLUSTERS {
    BIGINT playlist_id PK, FK
    BIGINT cluster_id PK, FK
}


%% ============================================================
%% AI SONG CLASSIFICATION
%% ============================================================

AI_RUNS {
    BIGINT id PK
    BIGINT curation_run_id FK
    TEXT agent_type
    TEXT model
    TEXT prompt_version
    TIMESTAMPTZ started_at
    TIMESTAMPTZ completed_at
    TEXT status
}

AI_SONG_ASSIGNMENTS {
    BIGINT id PK
    BIGINT ai_run_id FK
    BIGINT song_id FK
    BIGINT playlist_id FK
    NUMERIC confidence
    TEXT reason
    JSONB raw_response
    TIMESTAMPTZ created_at
}

CURATED_PLAYLIST_SONGS {
    BIGINT playlist_id PK, FK
    BIGINT song_id PK, FK
    NUMERIC confidence
    TEXT assignment_method
    TIMESTAMPTZ created_at
}


%% ============================================================
%% SOURCE DATA RELATIONSHIPS
%% ============================================================

%% SOURCE DATA

USERS ||--o{ SOURCE_PLAYLISTS : " "

ALBUMS ||--o{ SONGS : " "

SONGS ||--o{ SONG_ARTISTS : " "
ARTISTS ||--o{ SONG_ARTISTS : " "

SONGS ||--o{ SONG_GENRES : " "
GENRES ||--o{ SONG_GENRES : " "

SOURCE_PLAYLISTS ||--o{ SOURCE_PLAYLIST_SONGS : " "
SONGS ||--o{ SOURCE_PLAYLIST_SONGS : " "

SONGS ||--o{ SONG_AUDIO_FEATURES : " "
SONGS ||--o| SONG_METADATA : " "


%% CLUSTERING

CLUSTERING_RUNS ||--o{ CLUSTERS : " "

CLUSTERING_RUNS ||--o{ SONG_CLUSTERS : " "
CLUSTERS ||--o{ SONG_CLUSTERS : " "
SONGS ||--o{ SONG_CLUSTERS : " "

CLUSTERS ||--o| CLUSTER_PROFILES : " "

CLUSTERS ||--o{ CLUSTER_GENRES : " "
GENRES ||--o{ CLUSTER_GENRES : " "

CLUSTERS ||--o{ CLUSTER_REPRESENTATIVES : " "
SONGS ||--o{ CLUSTER_REPRESENTATIVES : " "


%% AI CURATION

USERS ||--o{ CURATION_RUNS : " "
CLUSTERING_RUNS ||--o{ CURATION_RUNS : " "

CURATION_RUNS ||--o{ CURATED_PLAYLISTS : " "

CURATED_PLAYLISTS ||--o{ CURATED_PLAYLIST_GENRES : " "
CURATED_PLAYLISTS ||--o{ CURATED_PLAYLIST_ERAS : " "
CURATED_PLAYLISTS ||--o{ CURATED_PLAYLIST_VIBES : " "

CURATED_PLAYLISTS ||--o{ CURATED_PLAYLIST_CLUSTERS : " "
CLUSTERS ||--o{ CURATED_PLAYLIST_CLUSTERS : " "


%% AI CLASSIFICATION

CURATION_RUNS ||--o{ AI_RUNS : " "

AI_RUNS ||--o{ AI_SONG_ASSIGNMENTS : " "

SONGS ||--o{ AI_SONG_ASSIGNMENTS : " "
CURATED_PLAYLISTS ||--o{ AI_SONG_ASSIGNMENTS : " "


%% FINAL PLAYLISTS

CURATED_PLAYLISTS ||--o{ CURATED_PLAYLIST_SONGS : " "
SONGS ||--o{ CURATED_PLAYLIST_SONGS : " "