-- QUERY TRUNCATED
-- ============================================================
-- SPOTIFY MUSIC CURATION DATABASE
-- ============================================================
-- WARNING:
-- This script deletes the existing schema/tables.
-- Make sure you do not need any existing data before running it.
-- ============================================================


-- ============================================================
-- 1. DROP EXISTING TABLES
-- ============================================================

DROP TABLE IF EXISTS ai_song_assignments CASCADE;
DROP TABLE IF EXISTS ai_runs CASCADE;

DROP TABLE IF EXISTS curated_playlist_songs CASCADE;
DROP TABLE IF EXISTS curated_playlist_vibes CASCADE;
DROP TABLE IF EXISTS curated_playlist_eras CASCADE;
DROP TABLE IF EXISTS curated_playlist_genres CASCADE;
DROP TABLE IF EXISTS curated_playlist_clusters CASCADE;
DROP TABLE IF EXISTS curated_playlists CASCADE;
DROP TABLE IF EXISTS curation_runs CASCADE;

DROP TABLE IF EXISTS cluster_representatives CASCADE;
DROP TABLE IF EXISTS cluster_genres CASCADE;
DROP TABLE IF EXISTS cluster_profiles CASCADE;
DROP TABLE IF EXISTS song_clusters CASCADE;
DROP TABLE IF EXISTS clusters CASCADE;
DROP TABLE IF EXISTS clustering_runs CASCADE;

DROP TABLE IF EXISTS song_metadata CASCADE;
DROP TABLE IF EXISTS song_audio_features CASCADE;

DROP TABLE IF EXISTS song_genres CASCADE;
DROP TABLE IF EXISTS genres CASCADE;

DROP TABLE IF EXISTS song_artists CASCADE;
DROP TABLE IF EXISTS artists CASCADE;

DROP TABLE IF EXISTS songs CASCADE;
DROP TABLE IF EXISTS albums CASCADE;

DROP TABLE IF EXISTS source_playlist_songs CASCADE;
DROP TABLE IF EXISTS source_playlists CASCADE;

DROP TABLE IF EXISTS users CASCADE;


-- ============================================================
-- 2. USERS
-- ============================================================

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,

    spotify_user_id TEXT NOT NULL UNIQUE,

    display_name TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 3. ALBUMS
-- ============================================================

CREATE TABLE albums (
    id BIGSERIAL PRIMARY KEY,

    spotify_album_id TEXT NOT NULL UNIQUE,

    name TEXT NOT NULL,

    release_date DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 4. ARTISTS
-- ============================================================

CREATE TABLE artists (
    id BIGSERIAL PRIMARY KEY,

    spotify_artist_id TEXT UNIQUE,

    name TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 5. SONGS
-- ============================================================

CREATE TABLE songs (
    id BIGSERIAL PRIMARY KEY,

    spotify_track_id TEXT NOT NULL UNIQUE,

    isrc TEXT,

    song_name TEXT NOT NULL,

    duration_ms INTEGER,

    release_date DATE,

    release_year INTEGER,

    album_id BIGINT REFERENCES albums(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_duration
        CHECK (duration_ms IS NULL OR duration_ms >= 0),

    CONSTRAINT valid_release_year
        CHECK (
            release_year IS NULL
            OR release_year BETWEEN 1800 AND 2200
        )
);


-- ============================================================
-- 6. SONG ↔ ARTIST
-- ============================================================

CREATE TABLE song_artists (
    song_id BIGINT NOT NULL
        REFERENCES songs(id)
        ON DELETE CASCADE,

    artist_id BIGINT NOT NULL
        REFERENCES artists(id)
        ON DELETE CASCADE,

    artist_role TEXT,

    PRIMARY KEY (song_id, artist_id)
);


-- ============================================================
-- 7. GENRES
-- ============================================================

CREATE TABLE genres (
    id BIGSERIAL PRIMARY KEY,

    name TEXT NOT NULL UNIQUE
);


-- ============================================================
-- 8. SONG ↔ GENRE
-- ============================================================

CREATE TABLE song_genres (
    song_id BIGINT NOT NULL
        REFERENCES songs(id)
        ON DELETE CASCADE,

    genre_id BIGINT NOT NULL
        REFERENCES genres(id)
        ON DELETE CASCADE,

    source TEXT,

    PRIMARY KEY (song_id, genre_id)
);


-- ============================================================
-- 9. SOURCE SPOTIFY PLAYLISTS
-- ============================================================
-- These are playlists imported from Spotify.
-- They are NOT the AI-generated curated playlists.
-- ============================================================

CREATE TABLE source_playlists (
    id BIGSERIAL PRIMARY KEY,

    spotify_playlist_id TEXT NOT NULL UNIQUE,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    description TEXT,

    snapshot_id TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 10. SOURCE PLAYLIST ↔ SONG
-- ============================================================
-- Allows the same song to appear multiple times in a playlist.
-- Position therefore belongs to the relationship, not the song.
-- ============================================================

CREATE TABLE source_playlist_songs (
    playlist_id BIGINT NOT NULL
        REFERENCES source_playlists(id)
        ON DELETE CASCADE,

    song_id BIGINT NOT NULL
        REFERENCES songs(id)
        ON DELETE CASCADE,

    position INTEGER NOT NULL,

    added_at TIMESTAMPTZ,

    PRIMARY KEY (playlist_id, position),

    CONSTRAINT valid_position
        CHECK (position >= 0)
);


-- ============================================================
-- 11. SONG AUDIO FEATURES
-- ============================================================

CREATE TABLE song_audio_features (
    id BIGSERIAL PRIMARY KEY,

    song_id BIGINT NOT NULL
        REFERENCES songs(id)
        ON DELETE CASCADE,

    tempo NUMERIC,

    energy NUMERIC,

    danceability NUMERIC,

    valence NUMERIC,

    acousticness NUMERIC,

    instrumentalness NUMERIC,

    speechiness NUMERIC,

    liveness NUMERIC,

    loudness NUMERIC,

    source TEXT,

    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (song_id, source)
);


-- ============================================================
-- 12. DERIVED SONG METADATA
-- ============================================================

CREATE TABLE song_metadata (
    song_id BIGINT PRIMARY KEY
        REFERENCES songs(id)
        ON DELETE CASCADE,

    era TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 13. CLUSTERING RUNS
-- ============================================================
-- Represents one execution/configuration of K-Means.
-- ============================================================

CREATE TABLE clustering_runs (
    id BIGSERIAL PRIMARY KEY,

    name TEXT,

    algorithm TEXT NOT NULL DEFAULT 'kmeans',

    k INTEGER NOT NULL,

    features_used JSONB NOT NULL,

    normalisation_method TEXT,

    random_seed INTEGER,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_k
        CHECK (k > 0)
);


-- ============================================================
-- 14. CLUSTERS
-- ============================================================

CREATE TABLE clusters (
    id BIGSERIAL PRIMARY KEY,

    clustering_run_id BIGINT NOT NULL
        REFERENCES clustering_runs(id)
        ON DELETE CASCADE,

    cluster_number INTEGER NOT NULL,

    song_count INTEGER,

    UNIQUE (clustering_run_id, cluster_number),

    CONSTRAINT valid_cluster_number
        CHECK (cluster_number >= 0),

    CONSTRAINT valid_song_count
        CHECK (song_count IS NULL OR song_count >= 0)
);


-- ============================================================
-- 15. SONG ↔ CLUSTER
-- ============================================================
-- A song can belong to different clusters in different
-- clustering runs.
-- ============================================================

CREATE TABLE song_clusters (
    clustering_run_id BIGINT NOT NULL
        REFERENCES clustering_runs(id)
        ON DELETE CASCADE,

    cluster_id BIGINT NOT NULL
        REFERENCES clusters(id)
        ON DELETE CASCADE,

    song_id BIGINT NOT NULL
        REFERENCES songs(id)
        ON DELETE CASCADE,

    distance_from_centroid NUMERIC,

    PRIMARY KEY (clustering_run_id, song_id)
);


-- ============================================================
-- 16. CLUSTER PROFILES
-- =====================================