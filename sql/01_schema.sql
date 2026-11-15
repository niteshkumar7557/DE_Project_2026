CREATE SCHEMA spotify;
SET search_path TO spotify;

CREATE TABLE artists (
  artist_id integer PRIMARY KEY,
  artist_name text NOT NULL,
  country_code char(2) NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
  primary_genre text NOT NULL,
  is_verified boolean NOT NULL,
  monthly_listeners integer NOT NULL CHECK (monthly_listeners >= 0),
  created_at timestamptz NOT NULL
);

CREATE TABLE users (
  user_id integer PRIMARY KEY,
  email text NOT NULL UNIQUE CHECK (email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  display_name text NOT NULL,
  country_code char(2) NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
  birth_date date NOT NULL CHECK (birth_date >= DATE '1900-01-01'),
  subscription text NOT NULL CHECK (subscription IN ('FREE','PREMIUM','DUO','FAMILY','STUDENT')),
  created_at timestamptz NOT NULL
);

CREATE TABLE albums (
  album_id integer PRIMARY KEY,
  artist_id integer NOT NULL REFERENCES artists(artist_id) ON DELETE RESTRICT,
  album_title text NOT NULL,
  album_type text NOT NULL CHECK (album_type IN ('ALBUM','EP','SINGLE','COMPILATION')),
  release_date date NOT NULL,
  label text NOT NULL,
  upc char(12) NOT NULL UNIQUE CHECK (upc ~ '^[0-9]{12}$')
);

CREATE TABLE tracks (
  track_id integer PRIMARY KEY,
  album_id integer NOT NULL REFERENCES albums(album_id) ON DELETE RESTRICT,
  disc_no smallint NOT NULL CHECK (disc_no >= 1),
  track_no smallint NOT NULL CHECK (track_no >= 1),
  title text NOT NULL,
  duration_ms integer NOT NULL CHECK (duration_ms > 0),
  explicit boolean NOT NULL,
  isrc char(12) NOT NULL UNIQUE CHECK (isrc ~ '^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$'),
  popularity smallint NOT NULL CHECK (popularity BETWEEN 0 AND 100),
  UNIQUE (album_id, disc_no, track_no)
);

CREATE TABLE track_artists (
  track_id integer NOT NULL REFERENCES tracks(track_id) ON DELETE CASCADE,
  artist_id integer NOT NULL REFERENCES artists(artist_id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('PRIMARY','FEATURED')),
  PRIMARY KEY (track_id, artist_id)
);

CREATE TABLE playlists (
  playlist_id integer PRIMARY KEY,
  owner_user_id integer NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  name text NOT NULL,
  is_public boolean NOT NULL,
  is_collaborative boolean NOT NULL,
  created_at timestamptz NOT NULL,
  CHECK (NOT (is_public AND is_collaborative))
);

CREATE TABLE playlist_tracks (
  playlist_id integer NOT NULL REFERENCES playlists(playlist_id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position >= 1),
  track_id integer NOT NULL REFERENCES tracks(track_id) ON DELETE CASCADE,
  added_by_user_id integer NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  added_at timestamptz NOT NULL,
  PRIMARY KEY (playlist_id, position)
);

CREATE TABLE streams (
  stream_id bigint PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  track_id integer NOT NULL REFERENCES tracks(track_id) ON DELETE RESTRICT,
  started_at timestamptz NOT NULL,
  ms_played integer NOT NULL CHECK (ms_played >= 0),
  platform text NOT NULL CHECK (platform IN ('ANDROID','CAR','DESKTOP','IOS','SPEAKER','WEB')),
  source_type text NOT NULL CHECK (source_type IN ('ALBUM','ARTIST','PLAYLIST','RADIO','SEARCH')),
  playlist_id integer REFERENCES playlists(playlist_id) ON DELETE SET NULL,
  skipped boolean NOT NULL,
  offline boolean NOT NULL DEFAULT false,
  CHECK (source_type = 'PLAYLIST' OR playlist_id IS NULL),
  CHECK (NOT skipped OR ms_played < 30000)
);

CREATE TABLE liked_tracks (
  user_id integer NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  track_id integer NOT NULL REFERENCES tracks(track_id) ON DELETE CASCADE,
  liked_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, track_id)
);

CREATE TABLE artist_follows (
  user_id integer NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  artist_id integer NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE,
  followed_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, artist_id)
);
