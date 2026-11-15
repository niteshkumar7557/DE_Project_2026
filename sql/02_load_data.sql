-- Run with psql from the repository root after: unzip -q seed_data.zip
\set ON_ERROR_STOP on
SET search_path TO spotify;
\copy artists FROM 'seed_data/artists.csv' WITH (FORMAT csv, HEADER true)
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy albums FROM 'seed_data/albums.csv' WITH (FORMAT csv, HEADER true)
\copy tracks FROM 'seed_data/tracks.csv' WITH (FORMAT csv, HEADER true)
\copy track_artists FROM 'seed_data/track_artists.csv' WITH (FORMAT csv, HEADER true)
\copy playlists FROM 'seed_data/playlists.csv' WITH (FORMAT csv, HEADER true)
\copy playlist_tracks FROM 'seed_data/playlist_tracks.csv' WITH (FORMAT csv, HEADER true)
\copy streams FROM 'seed_data/streams.csv' WITH (FORMAT csv, HEADER true)
\copy liked_tracks FROM 'seed_data/liked_tracks.csv' WITH (FORMAT csv, HEADER true)
\copy artist_follows FROM 'seed_data/artist_follows.csv' WITH (FORMAT csv, HEADER true)
ANALYZE;
