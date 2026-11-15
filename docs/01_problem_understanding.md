# Problem understanding

| Problem | Business need and affected stakeholder | Class |
|---|---|---|
| P1 | Open artist, album, and playlist pages promptly for listeners, including free and Premium users. | Customer-facing / real-time |
| P2 | Return search, recent plays, and liked songs promptly and record likes/plays for heavy listeners. | Customer-facing / real-time |
| P3 | Give artists usable skip, listener, and related-fan statistics in Spotify for Artists. | Customer-facing / real-time |
| P4 | Find recordings by ISRC for labels and rights holders; count royalty-eligible plays accurately for royalties/finance. | Mixed: ISRC lookup real-time; royalty report analytics |
| P5 | Identify public playlists with zero plays so the curation team can review them. | Reporting / analytics |
| P6 | Produce Wrapped and Release Radar for listeners and surface recent releases. | Mixed: discovery real-time; Wrapped analytics |
| P7 | Find explicit plays made while a listener was a minor for compliance. | Reporting / analytics |
| P8 | Add tracks quickly, measure collaborators, and find duplicate playlist entries for playlist owners and the curation team. | Mixed: add real-time; audits analytics |
| P9 | Give growth a free-user upsell list and give platform analysts daily, offline, hourly, and artist reports as streams grow. | Reporting / analytics |

## Assumptions

- A stream earns royalty eligibility when `ms_played >= 30000`, independent of its `skipped` flag.
- “Monthly listeners” means distinct users over a rolling 28-day window; the stored artist count is a periodically refreshed snapshot.
- A track is a recording on one album; its ISRC identifies that recording. Multiple artist credits are represented separately.
- Playlist streams have a playlist reference in the export. Other sources have none; a deleted playlist can leave a historical playlist stream without one.
- Real-time work should be judged by user-visible latency; reporting jobs can run asynchronously and have larger targets. Targets need measurements in Phase 3.
