# Baseline benchmark timings

Source: saved `EXPLAIN (ANALYZE, BUFFERS)` plans in `benchmarks/results/baseline/` and `summary.csv`. Each query has three recorded runs. Times are PostgreSQL execution times in milliseconds; planning time is excluded. Averages are rounded to three decimal places.

| Query | Type | Runs (ms) | Average (ms) | Median (ms) |
| --- | --- | --- | ---: | ---: |
| R01 | READ | 107.650, 9.144, 8.208 | 41.667 | 9.144 |
| R02 | READ | 0.673, 0.023, 0.023 | 0.240 | 0.023 |
| R03 | READ | 47.491, 23.949, 28.307 | 33.249 | 28.307 |
| R04 | READ | 6.416, 6.990, 5.971 | 6.459 | 6.416 |
| R05 | READ | 1.508, 0.149, 0.155 | 0.604 | 0.155 |
| R06 | READ | 0.053, 0.052, 0.056 | 0.054 | 0.053 |
| R07 | READ | 16.398, 12.373, 11.810 | 13.527 | 12.373 |
| R08 | READ | 10.770, 10.735, 10.559 | 10.688 | 10.735 |
| R09 | READ | 5.945, 5.810, 6.039 | 5.931 | 5.945 |
| R10 | READ | 11.117, 10.995, 12.359 | 11.490 | 11.117 |
| R11 | READ | 1.887, 0.916, 0.505 | 1.103 | 0.916 |
| R12 | READ | 23.902, 15.967, 21.085 | 20.318 | 21.085 |
| R13 | READ | 24.996, 23.461, 26.344 | 24.934 | 24.996 |
| R14 | READ | 20.195, 8.992, 8.852 | 12.680 | 8.992 |
| R15 | READ | 6.222, 2.118, 2.094 | 3.478 | 2.118 |
| R16 | READ | 18.049, 18.339, 18.162 | 18.183 | 18.162 |
| R17 | READ | 11.325, 11.359, 11.613 | 11.432 | 11.359 |
| R18 | READ | 16.060, 15.214, 16.252 | 15.842 | 16.060 |
| R19 | READ | 10690.187, 9213.419, 9294.085 | 9732.564 | 9294.085 |
| R20 | READ | 162.771, 153.050, 207.017 | 174.279 | 162.771 |
| R21 | READ | 0.348, 0.032, 0.033 | 0.138 | 0.033 |
| R22 | READ | 24.445, 23.922, 28.905 | 25.757 | 24.445 |
| R23 | READ | 51.167, 49.558, 48.527 | 49.751 | 49.558 |
| R24 | READ | 24.771, 12.464, 12.095 | 16.443 | 12.464 |
| R25 | READ | 18.251, 15.241, 16.771 | 16.754 | 16.771 |
| W01 | WRITE | 1.850, 0.595, 0.575 | 1.007 | 0.595 |
| W02 | WRITE | 0.950, 0.550, 0.542 | 0.681 | 0.550 |
| W03 | WRITE | 2.008, 0.523, 0.571 | 1.034 | 0.571 |
| W04 | WRITE | 45.550, 42.561, 43.863 | 43.991 | 43.863 |
| W05 | WRITE | 7.926, 7.770, 13.158 | 9.618 | 7.926 |

## Plan observations

- **R01**: Parallel sequential scan of streams joins a sequential scan of track_artists by hash join; track rows use tracks_pkey in a nested loop before grouping and a top-N sort.
- **R02**: Index scan on tracks_album_id_disc_no_track_no_key supplies the requested album track order.
- **R03**: Sequential scan of tracks feeds a sort; no index scan appears.
- **R04**: Parallel sequential scan of streams feeds nested-loop lookups through tracks_pkey; workers sort and Gather Merge combines them.
- **R05**: Nested-loop index lookups use playlist_tracks_pkey, tracks_pkey, track_artists_pkey, and artists_pkey; results are sorted and grouped.
- **R06**: Index scans on liked_tracks_pkey and tracks_pkey feed a nested loop, followed by a sort.
- **R07**: Parallel sequential scan of streams and parallel index-only scan on track_artists_pkey feed a parallel hash join; aggregation follows.
- **R08**: Parallel sequential scan of streams joins a sequential scan of track_artists by hash join; tracks_pkey lookups use a nested loop before grouping.
- **R09**: Parallel sequential scan of streams feeds nested-loop index lookups through track_artists_pkey and artists_pkey, then grouping and sorting.
- **R10**: Parallel sequential scan of streams feeds sorting, Gather Merge, and GroupAggregate.
- **R11**: Sequential scan of albums and index-only scan of artist_follows_pkey feed a hash join; artists_pkey is used for nested-loop lookups.
- **R12**: Parallel sequential scan of streams joins a sequential scan of tracks by hash join; users_pkey supplies nested-loop user lookups.
- **R13**: Sequential scans of playlists and streams appear in the plan; no index scan appears.
- **R14**: Sequential scans of playlist_tracks and playlists feed a hash join, followed by grouping and sorting.
- **R15**: Sequential scan of artist_follows feeds nested-loop lookups via artist_follows_pkey (index-only) and artists_pkey; results are grouped.
- **R16**: Sequential scans of streams and track_artists feed a hash join, followed by grouping and sorting.
- **R17**: Sequential scans of streams and users feed a hash join and hash aggregation.
- **R18**: Parallel sequential scan of streams feeds hash aggregation; Gather Merge, GroupAggregate, and sort finish the plan.
- **R19**: Sequential scans of artists, streams, and track_artists appear, with repeated streams and track_artists scans inside an aggregate subplan; the recorded runs are the slowest (9,213–10,690 ms).
- **R20**: Sequential scans of streams and users feed a hash join; sort and GroupAggregate follow.
- **R21**: Index scan on tracks_isrc_key finds the recording; nested-loop lookup uses albums_pkey.
- **R22**: Sequential scan of playlist_tracks feeds hash aggregation and sorting.
- **R23**: Sequential scan of streams feeds sorting; no index scan appears.
- **R24**: Sequential scans of tracks and albums feed a hash join, then hash aggregation and sorting.
- **R25**: Sequential scan of streams is aggregated; a separate albums sequential scan uses nested-loop tracks lookups via tracks_album_id_disc_no_track_no_key.
- **W01**: Insert on streams; the plan has no scan node.
- **W02**: Insert on liked_tracks; the plan has no scan node.
- **W03**: Insert on playlist_tracks uses playlists_pkey for a playlist lookup and a backward index-only scan of playlist_tracks_pkey.
- **W04**: Update on artists uses an artists_pkey index scan; sequential scans of streams, track_artists, and artists feed hash join and aggregation.
- **W05**: Delete on playlist_tracks uses a sequential scan of playlist_tracks, tracks_pkey and tracks_album_id_disc_no_track_no_key index scans, and a hash join.

## Verification notes

The 30 saved query files contain 90 execution plans and 90 execution-time values: 25 read queries and 5 write queries, each with three runs. The summary has 30 rows; its average, median, minimum, and maximum values match the saved execution times. The benchmark script wraps each write query in `BEGIN` and `ROLLBACK`; quiet `psql` output does not echo those transaction commands in the plan files, so the plans alone do not independently prove database state after the run.

An earlier task brief referred to 105 plans. The specified workload has 30 queries and three runs each, so the correct expected count is **90**, not 105.
