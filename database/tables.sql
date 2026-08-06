-- Drop tables in dependency order (optional during development)

DROP TABLE IF EXISTS song_artist CASCADE;
DROP TABLE IF EXISTS library_song CASCADE;
DROP TABLE IF EXISTS songs CASCADE;
DROP TABLE IF EXISTS artists CASCADE;
DROP TABLE IF EXISTS albums CASCADE;
DROP TABLE IF EXISTS libraries CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-------------------------------------------------------
-- Users
-------------------------------------------------------

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-------------------------------------------------------
-- Playlists
-------------------------------------------------------

CREATE TABLE playlists (
    playlist_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    playlist_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_playlist_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

-------------------------------------------------------
-- Albums
-------------------------------------------------------

CREATE TABLE albums (
    album_id SERIAL PRIMARY KEY,
    album_name VARCHAR(255) NOT NULL,
    release_year INTEGER,
    spotify_album_id VARCHAR(50) UNIQUE
);

-------------------------------------------------------
-- Artists
-------------------------------------------------------

CREATE TABLE artists (
    artist_id SERIAL PRIMARY KEY,
    artist_name VARCHAR(255) NOT NULL,
    spotify_artist_id VARCHAR(50) UNIQUE
);

-------------------------------------------------------
-- Songs
-------------------------------------------------------

CREATE TABLE songs (
    song_id SERIAL PRIMARY KEY,

    album_id INTEGER,

    song_name VARCHAR(255) NOT NULL,
    duration_ms INTEGER,

    spotify_track_id VARCHAR(50) UNIQUE,

    CONSTRAINT fk_song_album
        FOREIGN KEY (album_id)
        REFERENCES albums(album_id)
        ON DELETE SET NULL
);

-------------------------------------------------------
-- Playlist <-> Songs (Many-to-Many)
-------------------------------------------------------

CREATE TABLE playlist_song (
    playlist_id INTEGER NOT NULL,
    song_id INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (playlist_id, song_id),

    CONSTRAINT fk_ps_playlist
        FOREIGN KEY (playlist_id)
        REFERENCES playlists(playlist_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_ps_song
        FOREIGN KEY (song_id)
        REFERENCES songs(song_id)
        ON DELETE CASCADE
);

-------------------------------------------------------
-- Song <-> Artist (Many-to-Many)
-------------------------------------------------------

CREATE TABLE song_artist (
    song_id INTEGER NOT NULL,
    artist_id INTEGER NOT NULL,

    PRIMARY KEY (song_id, artist_id),

    CONSTRAINT fk_sa_song
        FOREIGN KEY (song_id)
        REFERENCES songs(song_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_sa_artist
        FOREIGN KEY (artist_id)
        REFERENCES artists(artist_id)
        ON DELETE CASCADE
);

-------------------------------------------------------
-- Helpful indexes
-------------------------------------------------------

CREATE INDEX idx_playlist_user
ON playlists(user_id);

CREATE INDEX idx_playlist_song_song
ON playlist_song(song_id);

CREATE INDEX idx_song_album
ON songs(album_id);

CREATE INDEX idx_song_artist_artist
ON song_artist(artist_id);