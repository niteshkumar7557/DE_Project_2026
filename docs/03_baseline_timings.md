# Baseline Benchmark Timings (Phase 3)

Source: saved `EXPLAIN (ANALYZE, BUFFERS)` plans in `benchmarks/results/baseline/` and `benchmarks/results/baseline/summary.csv`. Each query has three recorded runs. Times are PostgreSQL execution times in milliseconds; planning time is excluded. Averages are rounded to three decimal places.

## 1. Baseline Timing Table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Artist page: artist 33's 10 most-streamed tracks in the last 28 days | READ | 107.650 | 9.144 | 8.208 | 41.667 |
| R02: Album page: tracklist of album 1469 | READ | 0.673 | 0.023 | 0.023 | 0.240 |
| R03: Search: tracks whose title contains "love", most popular first | READ | 47.491 | 23.949 | 28.307 | 33.249 |
| R04: "Recently played": user 1038's last 50 streams | READ | 6.416 | 6.990 | 5.971 | 6.459 |
| R05: Playlist page: playlist 501 in order, with every artist on each track | READ | 1.508 | 0.149 | 0.155 | 0.604 |
| R06: "Liked Songs": user 1038's liked tracks, newest first | READ | 0.053 | 0.052 | 0.056 | 0.054 |
| R07: Royalties: streams of 30 seconds or more ("royalty-eligible") per artist in June 2026, top 20 | READ | 16.398 | 12.373 | 11.810 | 13.527 |
| R08: Spotify for Artists: skip rate of each of artist 33's tracks | READ | 10.770 | 10.735 | 10.559 | 10.688 |
| R09: Wrapped 2025: user 1038's top 5 artists by minutes listened | READ | 5.945 | 5.810 | 6.039 | 5.931 |
| R10: Platform analytics: daily streams per platform in June 2026 | READ | 11.117 | 10.995 | 12.359 | 11.490 |
| R11: "Release Radar": 2026 releases by artists user 1038 follows | READ | 1.887 | 0.916 | 0.505 | 1.103 |
| R12: Compliance: explicit tracks streamed by users who were under 18 at the time | READ | 23.902 | 15.967 | 21.085 | 20.318 |
| R13: Curation team: public playlists that have never been played | READ | 24.996 | 23.461 | 26.344 | 24.934 |
| R14: Collaborative playlists: number of different people who added tracks | READ | 20.195 | 8.992 | 8.852 | 12.680 |
| R15: "Fans also like": artists most followed by the followers of artist 33 | READ | 6.222 | 2.118 | 2.094 | 3.478 |
| R16: Artist profiles: distinct listeners of every artist in the last 28 days ("monthly listeners") | READ | 18.049 | 18.339 | 18.162 | 18.183 |
| R17: Growth: free users with 4+ streams in June 2026 (Premium upsell list) | READ | 11.325 | 11.359 | 11.613 | 11.432 |
| R18: Platform analytics: share of offline listening per platform | READ | 16.060 | 15.214 | 16.252 | 15.842 |
| R19: Verified artists report: total streams and the latest stream of every verified artist | READ | 10690.187 | 9213.419 | 9294.085 | 9732.564 |
| R20: Listening patterns: streams per hour of the day per country | READ | 162.771 | 153.050 | 207.017 | 174.279 |
| R21: Rights management: look up a recording by its ISRC code | READ | 0.348 | 0.032 | 0.033 | 0.138 |
| R22: Playlist hygiene: playlists that contain the same track more than once | READ | 24.445 | 23.922 | 28.905 | 25.757 |
| R23: Support console: all streams, newest first, page 8,001 (25 per page) | READ | 51.167 | 49.558 | 48.527 | 49.751 |
| R24: Label report: average track length and explicit share per album type | READ | 24.771 | 12.464 | 12.095 | 16.443 |
| R25: Discovery: tracks released in the last 30 days, ranked by streams | READ | 18.251 | 15.241 | 16.771 | 16.754 |
| W01: Player: log a stream of track 1389 by user 1038 | WRITE | 1.850 | 0.595 | 0.575 | 1.007 |
| W02: Heart button: user 1038 likes track 1389 | WRITE | 0.950 | 0.550 | 0.542 | 0.681 |
| W03: "Add to playlist": append track 1389 to the end of playlist 501 | WRITE | 2.008 | 0.523 | 0.571 | 1.034 |
| W04: Nightly job: recompute every artist's monthly listeners (last 28 days) | WRITE | 45.550 | 42.561 | 43.863 | 43.991 |
| W05: Takedown: the label withdrew the whole album of track 1389, so remove its tracks from every playlist | WRITE | 7.926 | 7.770 | 13.158 | 9.618 |
| **Total (sum of all 30)** | | **11360.881** | **9696.271** | **9854.536** | **10303.896** |

---

## 2. Plan Observations: Scan Types and Performance Analysis

Below is the scan type from the raw execution plan and an explanation of why each query is slow or fast in the baseline configuration:

- **R01**: **Scan Type:** `Seq Scan on streams | Seq Scan on track_artists | Index Scan using tracks_pkey on tracks`.  
  *Why:* **Slow (41.667 ms avg)** because finding artist 33's top tracks forces a parallel sequential scan of all 250,000 rows in `streams` and a sequential scan of all 77,489 rows in `track_artists` due to the lack of an index leading with `artist_id`.
- **R02**: **Scan Type:** `Index Scan using tracks_album_id_disc_no_track_no_key on tracks`.  
  *Why:* **Fast (0.240 ms avg)** because the unique key constraint on `(album_id, disc_no, track_no)` allows direct B-tree index lookup and ordering for album 1469.
- **R03**: **Scan Type:** `Seq Scan on tracks`.  
  *Why:* **Slow (33.249 ms avg)** because standard B-tree indexes cannot index substring wildcards (`ILIKE '%love%'`), forcing PostgreSQL to sequentially scan all 67,808 tracks.
- **R04**: **Scan Type:** `Seq Scan on streams | Index Scan using tracks_pkey on tracks`.  
  *Why:* **Slow (6.459 ms avg)** because finding user 1038's 50 most recent streams requires a parallel sequential scan across all 250,000 streams and an external sort, as there is no index on `streams(user_id)`.
- **R05**: **Scan Type:** `Index Scan using playlist_tracks_pkey on playlist_tracks | Index Scan using tracks_pkey on tracks | Index Scan using track_artists_pkey on track_artists | Index Scan using artists_pkey on artists`.  
  *Why:* **Fast (0.604 ms avg)** because playlist 501 is looked up directly via `playlist_tracks_pkey`, followed by primary-key index lookups on tracks, track_artists, and artists.
- **R06**: **Scan Type:** `Index Scan using liked_tracks_pkey on liked_tracks | Index Scan using tracks_pkey on tracks`.  
  *Why:* **Fast (0.054 ms avg)** because user 1038's liked tracks are accessed directly using the primary key on `liked_tracks(user_id, track_id)`.
- **R07**: **Scan Type:** `Seq Scan on streams | Index Only Scan using track_artists_pkey on track_artists`.  
  *Why:* **Slow (13.527 ms avg)** because filtering streams in June 2026 with `ms_played >= 30000` scans all 250,000 streams in parallel without date-range index support.
- **R08**: **Scan Type:** `Seq Scan on streams | Seq Scan on track_artists | Index Scan using tracks_pkey on tracks`.  
  *Why:* **Slow (10.688 ms avg)** because calculating skip rates for artist 33 requires sequential scans of both `track_artists` (77,489 rows) and `streams` (250,000 rows).
- **R09**: **Scan Type:** `Seq Scan on streams | Index Scan using track_artists_pkey on track_artists | Index Scan using artists_pkey on artists`.  
  *Why:* **Slow (5.931 ms avg)** because `EXTRACT(YEAR FROM s.started_at) = 2025` is a non-sargable expression that prevents index usage, scanning 250,000 streams in parallel.
- **R10**: **Scan Type:** `Seq Scan on streams`.  
  *Why:* **Slow (11.490 ms avg)** because the expression `started_at::date BETWEEN ...` prevents index range scanning, forcing a full parallel sequential scan of 250,000 streams.
- **R11**: **Scan Type:** `Seq Scan on albums | Index Only Scan using artist_follows_pkey on artist_follows | Index Scan using artists_pkey on artists`.  
  *Why:* **Moderately fast (1.103 ms avg)** but un-indexed on `albums.artist_id`, which forces a full sequential scan across all 12,000 albums to find followed artist releases.
- **R12**: **Scan Type:** `Seq Scan on streams | Seq Scan on tracks | Index Scan using users_pkey on users`.  
  *Why:* **Slow (20.318 ms avg)** because it scans 250,000 streams in parallel and 67,808 tracks to find explicit tracks before testing minor age conditions.
- **R13**: **Scan Type:** `Seq Scan on playlists | Seq Scan on streams`.  
  *Why:* **Slow (24.934 ms avg) and returns wrong result (0 rows)** because `streams.playlist_id` contains `NULL` values; under SQL three-valued logic, `NOT IN (..., NULL)` evaluates to `UNKNOWN`, causing the query to return empty while scanning both tables sequentially.
- **R14**: **Scan Type:** `Seq Scan on playlist_tracks | Seq Scan on playlists`.  
  *Why:* **Slow (12.680 ms avg)** because identifying collaborative playlists and counting contributors scans all 10,000 playlists and all 120,004 playlist_tracks sequentially.
- **R15**: **Scan Type:** `Seq Scan on artist_follows | Index Only Scan using artist_follows_pkey on artist_follows | Index Scan using artists_pkey on artists`.  
  *Why:* **Slow (3.478 ms avg)** because `artist_follows` PK is `(user_id, artist_id)`; finding followers of artist 33 requires sequentially scanning all 69,901 rows.
- **R16**: **Scan Type:** `Seq Scan on streams | Seq Scan on track_artists`.  
  *Why:* **Slow (18.183 ms avg)** because aggregating distinct monthly listeners across all artists requires full table scans of 250,000 streams and 77,489 track_artists rows.
- **R17**: **Scan Type:** `Seq Scan on streams | Seq Scan on users`.  
  *Why:* **Slow (11.432 ms avg)** because identifying free users with 4+ streams scans all 250,000 streams and all 30,000 users sequentially without index filters.
- **R18**: **Scan Type:** `Seq Scan on streams`.  
  *Why:* **Slow (15.842 ms avg)** because computing offline listening share requires a full parallel sequential scan of all 250,000 streams to evaluate every row.
- **R19**: **Scan Type:** `Seq Scan on artists | Seq Scan on streams | Seq Scan on track_artists`.  
  *Why:* **Extremely slow (9,732.564 ms avg, slowest query)** because for every verified artist, two correlated subqueries execute sequential scans of `streams` (250,000 rows) and `track_artists` (77,489 rows), resulting in over 668 full table scans.
- **R20**: **Scan Type:** `Seq Scan on streams | Seq Scan on users`.  
  *Why:* **Very slow (174.279 ms avg)** because joining 250,000 streams and 30,000 users with `GROUP BY 1, 2 ORDER BY 1, 2` forces an external merge sort to temporary disk files (spilling 4.4 MB) during `GroupAggregate`.
- **R21**: **Scan Type:** `Index Scan using tracks_isrc_key on tracks | Index Scan using albums_pkey on albums`.  
  *Why:* **Very fast (0.138 ms avg)** because the unique constraint index on `tracks.isrc` and primary key index on `albums.album_id` provide single-row index lookups.
- **R22**: **Scan Type:** `Seq Scan on playlist_tracks`.  
  *Why:* **Slow (25.757 ms avg)** because detecting duplicate tracks in playlists scans all 120,004 rows in `playlist_tracks` and spills 672 kB to disk during HashAggregate.
- **R23**: **Scan Type:** `Seq Scan on streams`.  
  *Why:* **Slow (49.751 ms avg)** because it scans all 250,000 streams and sorts 200,025 rows in memory before discarding the first 200,000 rows for `OFFSET 200000`.
- **R24**: **Scan Type:** `Seq Scan on tracks | Seq Scan on albums`.  
  *Why:* **Slow (16.443 ms avg)** because it performs full sequential scans across all 67,808 tracks and 12,000 albums to compute catalog-wide duration and explicit statistics.
- **R25**: **Scan Type:** `Seq Scan on streams | Seq Scan on albums | Index Scan using tracks_album_id_disc_no_track_no_key on tracks`.  
  *Why:* **Slow (16.754 ms avg)** because finding newly released tracks scans all 12,000 albums and hash joins against all 250,000 streams.
- **W01**: **Scan Type:** `(no scan)`.  
  *Why:* **Fast (1.007 ms avg)** because single-row insert into `streams` does not scan tables, executing foreign-key validation triggers quickly.
- **W02**: **Scan Type:** `(no scan)`.  
  *Why:* **Fast (0.681 ms avg)** because single-row insert into `liked_tracks` uses the primary key index for fast conflict detection.
- **W03**: **Scan Type:** `Index Scan using playlists_pkey on playlists | Index Only Scan using playlist_tracks_pkey on playlist_tracks`.  
  *Why:* **Fast (1.034 ms avg)** because `max(position)` is evaluated using a backward index-only scan on `playlist_tracks_pkey`.
- **W04**: **Scan Type:** `Index Scan using artists_pkey on artists | Seq Scan on streams | Seq Scan on track_artists | Seq Scan on artists`.  
  *Why:* **Slow (43.991 ms avg)** because the update computes monthly listeners by scanning 250,000 streams and 77,489 track_artists rows before updating 3,000 artist rows.
- **W05**: **Scan Type:** `Index Scan using tracks_pkey on tracks | Seq Scan on playlist_tracks | Index Scan using tracks_album_id_disc_no_track_no_key on tracks`.  
  *Why:* **Slow (9.618 ms avg)** because `playlist_tracks` lacks an index on `track_id`, forcing a full sequential scan across 120,004 rows during deletion.

---

## 3. Verification Notes

The 30 saved query files in `benchmarks/results/baseline/` contain 90 execution plans (3 runs per query): 25 read queries and 5 write queries. The summary in `benchmarks/results/baseline/summary.csv` matches the recorded times. All write queries (`W01`–`W05`) were executed inside `BEGIN ... ROLLBACK` transactions so database state remained unchanged.
