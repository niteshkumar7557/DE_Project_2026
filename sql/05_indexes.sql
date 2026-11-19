-- =====================================================================
-- Spotify DBMS Project: Phase 4 Indexes
-- File: sql/05_indexes.sql
--
-- Every index created below is documented with:
-- 1. Which queries it serves (R01-R25, W01-W05).
-- 2. Why this index type was chosen (B-tree, GIN trgm, partial, covering).
-- 3. Why this column order was selected (equality first, range/sort second).
-- =====================================================================

SET search_path TO spotify, public;

-- Enable trigram extension for fuzzy/wildcard text search (R03)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------
-- 1. TRACKS: GIN Trigram Index on title
-- Serves: R03 (Search: tracks whose title contains 'love')
-- Type:   GIN with gin_trgm_ops
-- Reason: Standard B-tree indexes cannot accelerate leading-wildcard
--         patterns ('%love%'). Trigram GIN indexing breaks text into 3-character
--         grams, enabling fast bitmap index scans instead of a 67,808-row
--         sequential scan.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tracks_title_trgm
  ON tracks USING gin (title gin_trgm_ops);

-- ---------------------------------------------------------------------
-- 2. TRACKS: Partial Index on Explicit Tracks
-- Serves: R12 (Compliance: explicit tracks streamed by minors)
-- Type:   B-tree partial index
-- Reason: Only tracks with explicit = true need to be evaluated for minor
--         compliance. The predicate WHERE explicit keeps the index small
--         (184 kB) and allows Index Only Scans when probing track explicit status.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tracks_explicit
  ON tracks (track_id) WHERE explicit;

-- ---------------------------------------------------------------------
-- 3. TRACKS: Covering Index for Album Join
-- Serves: R24 (Label report: average track length and explicit share)
-- Type:   B-tree covering index
-- Reason: Groups tracks by album_id while including duration_ms and explicit
--         in the payload to support index-only evaluations during aggregation.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tracks_album_covering
  ON tracks (album_id) INCLUDE (duration_ms, explicit);

-- ---------------------------------------------------------------------
-- 4. TRACK_ARTISTS: Artist to Track Mapping Index
-- Serves: R01, R08, R15, R16, R19, W04
-- Type:   B-tree composite index
-- Reason: The primary key is (track_id, artist_id), which cannot be used
--         when filtering by artist_id. This index puts artist_id leading
--         for equality lookups, and includes track_id so all artist-to-track
--         queries can be resolved via Index Only Scans without scanning
--         77,489 rows in track_artists.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_track_artists_artist_track
  ON track_artists (artist_id, track_id);

-- ---------------------------------------------------------------------
-- 5. ARTIST_FOLLOWS: Artist Followers Inverted Index
-- Serves: R15 ("Fans also like": followers of artist 33)
-- Type:   B-tree composite index
-- Reason: The primary key is (user_id, artist_id). Finding all users who follow
--         a particular artist (f1.artist_id = 33) previously forced a full table
--         scan of 69,901 rows. Leading with artist_id allows instant index-only
--         retrieval of all follower user_ids.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_artist_follows_artist_user
  ON artist_follows (artist_id, user_id);

-- ---------------------------------------------------------------------
-- 6. ALBUMS: Artist Releases Chronological Index
-- Serves: R11 ("Release Radar": 2026 releases by followed artists)
-- Type:   B-tree composite index
-- Reason: Column order: artist_id first (equality filter from followed artists),
--         release_date DESC second (range filter release_date >= '2026-01-01'
--         and sort order). Eliminates 12,000-row album table scan.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_albums_artist_release
  ON albums (artist_id, release_date DESC);

-- ---------------------------------------------------------------------
-- 7. ALBUMS: Release Date Range Index
-- Serves: R25 (Discovery: tracks released in last 30 days)
-- Type:   B-tree index
-- Reason: Accelerates range filter (release_date >= '2026-05-31') to quickly
--         locate newly released albums without scanning the entire albums table.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_albums_release_date
  ON albums (release_date);

-- ---------------------------------------------------------------------
-- 8. ALBUMS: Covering Index for Album Type
-- Serves: R24 (Label report: tracks and lengths per album type)
-- Type:   B-tree covering index
-- Reason: Pairs album_id with album_type to support fast lookups/joins.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_albums_id_type
  ON albums (album_id, album_type);

-- ---------------------------------------------------------------------
-- 9. PLAYLISTS: Partial Index on Collaborative Playlists
-- Serves: R14 (Collaborative playlists contributor counts)
-- Type:   B-tree partial index
-- Reason: Only 968 of 10,000 playlists are collaborative (<10%). Indexing
--         only WHERE is_collaborative creates a compact 56 kB index that
--         isolates target playlists immediately without scanning public/private
--         non-collaborative playlists.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_playlists_collaborative
  ON playlists (playlist_id, name) WHERE is_collaborative;

-- ---------------------------------------------------------------------
-- 10. PLAYLIST_TRACKS: Track ID Index (Foreign Key Index)
-- Serves: W05 (Album takedown: delete withdrawn album tracks from playlists)
-- Type:   B-tree index
-- Reason: The table only had PK (playlist_id, position). When deleting rows
--         by track_id, PostgreSQL had to sequentially scan 120,004 rows.
--         This index enables direct bitmap index scans, reducing execution
--         time by over 96%.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_playlist_tracks_track_id
  ON playlist_tracks (track_id);

-- ---------------------------------------------------------------------
-- 11. PLAYLIST_TRACKS: Playlist-Track Composite Index
-- Serves: R22 (Playlist hygiene: duplicate tracks in playlists)
-- Type:   B-tree composite index
-- Reason: Pairs (playlist_id, track_id) to enable Index Only Scans for duplicate
--         detection without accessing the heap table.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist_track
  ON playlist_tracks (playlist_id, track_id);

-- ---------------------------------------------------------------------
-- 12. USERS: Partial Index on Free Subscribers
-- Serves: R17 (Growth: free users with 4+ streams for upsell)
-- Type:   B-tree partial index
-- Reason: Indexes user_id only WHERE subscription = 'FREE'. Avoids scanning
--         paying users (PREMIUM, DUO, FAMILY, STUDENT) and provides a compact
--         Index Only Scan target for the join with streams.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_free
  ON users (user_id) WHERE subscription = 'FREE';

-- ---------------------------------------------------------------------
-- 13. USERS: Composite User Country Index
-- Serves: R20 (Listening patterns: streams per hour per country)
-- Type:   B-tree composite index
-- Reason: Pairs (user_id, country_code) to allow fast lookups of country_code
--         for stream join operations.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_user_country
  ON users (user_id, country_code);

-- ---------------------------------------------------------------------
-- 14. STREAMS: User Listening History Covering Index
-- Serves: R04 ("Recently played": user 1038's last 50 streams)
--         R09 (Wrapped 2025: user 1038's top artists by listening time)
-- Type:   B-tree composite index with INCLUDE clause
-- Reason: Column order: user_id leading (equality filter), started_at DESC
--         second (chronological ordering and date range scans). The INCLUDE
--         clause stores track_id, ms_played, and platform so that R04 and R09
--         execute completely as Index Only Scans with zero heap visits.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_streams_user_started
  ON streams (user_id, started_at DESC) INCLUDE (track_id, ms_played, platform);

-- ---------------------------------------------------------------------
-- 15. STREAMS: Track Stream Activity Index
-- Serves: R01 (Artist page top tracks in last 28 days)
--         R08 (Skip rate per track for artist 33)
--         R19 (Verified artists stream counts and last streamed time)
--         R25 (Discovery: newly released tracks ranked by stream count)
-- Type:   B-tree composite index
-- Reason: track_id leading (equality join from track_artists or tracks),
--         started_at second (range filtering). Replaces full 250,000-row
--         table scans with precise index lookups per track.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_streams_track_started
  ON streams (track_id, started_at);

-- ---------------------------------------------------------------------
-- 16. STREAMS: Unified Temporal Analytical Covering Index
-- Serves: R07 (June 2026 eligible royalties)
--         R10 (Daily platform streams in June 2026)
--         R12 (Compliance: explicit tracks streamed by minors)
--         R16 (Monthly listeners distinct counts in last 28 days)
--         R17 (Free users streaming in June 2026)
--         R23 (Support console: page 8,001 newest first pagination)
--         W04 (Nightly job: recalculate artist monthly listeners)
-- Type:   B-tree composite index with INCLUDE clause
-- Reason: started_at leading (range scans and chronological order; works
--         both ASC and DESC via Index Scan Backward). track_id, user_id,
--         and ms_played in key columns enable filtering and grouping;
--         stream_id and platform in INCLUDE payload enable full Index Only
--         Scans across 7 different read/write workload queries.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_streams_started_at
  ON streams (started_at, track_id, user_id, ms_played) INCLUDE (stream_id, platform);

-- ---------------------------------------------------------------------
-- 17. STREAMS: Partial Index on Playlist Streams
-- Serves: R13 (Curation team: public playlists never played)
-- Type:   B-tree partial index
-- Reason: Over 55% of streams (137,386 rows) have playlist_id IS NULL.
--         Indexing only WHERE playlist_id IS NOT NULL creates an index
--         that is under 1 MB, accelerating the NOT EXISTS anti-join to
--         find unplayed public playlists with minimal overhead.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_streams_playlist_id
  ON streams (playlist_id) WHERE playlist_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 18. STREAMS: Platform and Offline Analytics Index
-- Serves: R18 (Share of offline listening per platform)
-- Type:   B-tree composite covering index
-- Reason: Allows a Parallel Index Only Scan over (platform, offline) for
--         global platform aggregation without scanning table heap pages.
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_streams_platform_offline
  ON streams (platform, offline);

-- Refresh statistics after index creation
ANALYZE;
