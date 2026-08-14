# Spotify Playlist Automation — Technical Business Analysis Plan

## 1. Executive Summary

### Objective

Build an automated system that takes a user's Spotify playlist, enriches each song with musical metadata, categorises the songs according to configurable rules, and creates or updates Spotify playlists based on those categories.

For example, a source playlist containing 500 songs could automatically produce:

- **High Energy**
- **Low Energy / Chill**
- **Dance**
- **Electronic**
- **Rock**
- **Hip-Hop**
- **Indie**
- **Workout**
- **Late Night**
- **Background / Focus**

The key architectural principle is:

> **Spotify provides playlist and catalogue identity; external services provide musical enrichment; PostgreSQL provides persistent state; the classification layer turns structured attributes into categories; Spotify is then used to create/update the resulting playlists.**

---

## 2. Target Architecture

```text
                    ┌──────────────────────┐
                    │       Spotify        │
                    │                      │
                    │ • User playlists     │
                    │ • Track metadata      │
                    │ • Spotify IDs         │
                    │ • Playlist management │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Extraction Layer   │
                    │                      │
                    │ OAuth + API calls    │
                    │ Pagination           │
                    │ Deduplication        │
                    │ Retry / rate limits  │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │      PostgreSQL      │
                    │                      │
                    │ Users                │
                    │ Playlists            │
                    │ Playlist imports     │
                    │ Tracks               │
                    │ Artists              │
                    │ Albums               │
                    │ Playlist items       │
                    │ External IDs         │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
          ┌──────────────────┐   ┌──────────────────┐
          │  ReccoBeats      │   │    Last.fm       │
          │                  │   │                  │
          │ BPM / tempo      │   │ Genres / tags    │
          │ Energy           │   │ Artist metadata  │
          │ Danceability     │   │ Track tags       │
          │ Valence          │   │                  │
          │ Acousticness     │   │                  │
          └─────────┬────────┘   └─────────┬────────┘
                    │                      │
                    └──────────┬───────────┘
                               ▼
                    ┌──────────────────────┐
                    │ Enriched Track Data  │
                    │                      │
                    │ Feature values       │
                    │ Genres / tags        │
                    │ Data provenance      │
                    │ Confidence           │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Classification Layer │
                    │                      │
                    │ Rules / thresholds   │
                    │ + optional AI agent  │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Playlist Assignment  │
                    │                      │
                    │ Track → Category     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │       Spotify        │
                    │                      │
                    │ Create playlists     │
                    │ Add tracks           │
                    │ Reorder / replace    │
                    └──────────────────────┘
```

---

# 3. Spotify Data Extraction

## 3.1 Authentication

The application should use Spotify OAuth rather than storing a user's Spotify password.

The application should request the minimum scopes necessary.

For this use case, the important permissions are likely:

- `playlist-read-private`
- `playlist-modify-private`
- `playlist-modify-public`

Spotify's current Web API documentation should be checked before implementation because API access requirements and policies can change.

The application should store information such as:

```text
spotify_user_id
access_token
refresh_token
token_expiry
scopes
```

Tokens should **not** be stored in plaintext in the application database.

---

## 3.2 Extracting the Source Playlist

The implementation should use the current Spotify playlist-items endpoint rather than the older playlist-tracks endpoint.

Conceptually:

```text
GET /playlists/{playlist_id}/items
```

The extraction layer should support pagination using the response's `next` field.

```text
Request 1
GET /playlists/{id}/items?limit=50&offset=0

        ↓

next != null

        ↓

Request 2
GET /playlists/{id}/items?limit=50&offset=50

        ↓

...

        ↓

next == null

        ↓

Extraction complete
```

This approach also maps cleanly onto an n8n HTTP Request workflow where pagination continues until `next` is `null`.

---

# 4. What Should Be Extracted from Spotify?

The extraction layer should primarily capture **identity and playlist relationships**, rather than attempting to obtain every possible musical attribute from Spotify.

### Playlist

```text
Spotify playlist ID
Playlist name
Description
Owner
Public/private status
Snapshot ID
Total items
```

### Playlist item

```text
Spotify track ID
Track name
Artist(s)
Album
Album release date
Track duration
Spotify URL
Added timestamp
Playlist position
```

The system should also retain relevant relinking/linked-track information where applicable.

---

# 5. Track Identity and Database Design

A song and its appearance in a playlist are **not the same entity**.

For example:

```text
Song:
Daft Punk – One More Time

Playlist A:
position 12

Playlist B:
position 57

Playlist C:
position 3
```

There should therefore be one canonical `track` record but three playlist relationships.

## Recommended principle

Use an internal database-generated ID as the primary key, while enforcing uniqueness on the Spotify track ID. The Spotify ID remains the canonical external identifier used to identify and deduplicate Spotify tracks.

```text
tracks
------
id                  ← internal PK
spotify_track_id    ← external identifier / unique
reccobeats_track_id ← external identifier / nullable
...
```

Likewise:

```text
playlists
---------
id
spotify_playlist_id
...
```

This gives the application control over its own identity model while retaining external provider IDs.

---

# 6. Handling Duplicate Playlist Imports

Repeated imports should be allowed.

A playlist import should represent a **point-in-time snapshot**, rather than replacing previous data.

Recommended structure:

```text
playlist_imports
----------------
id
playlist_id
imported_at
spotify_snapshot_id
```

and:

```text
playlist_items
--------------
id
playlist_import_id
track_id
position
added_at
```

For example:

```text
Playlist: "My Music"

Import 1
100 songs

Import 2
117 songs

Import 3
123 songs
```

The system can then identify:

- New tracks
- Removed tracks
- Reordered tracks
- Unchanged tracks

This is preferable to overwriting the previous state.

---

# 7. ReccoBeats Track Identity

Do **not** attempt to mathematically convert a Spotify ID into a ReccoBeats ID.

Treat the identifiers as separate external IDs.

For example:

```text
tracks

id = 1234
spotify_track_id = <Spotify ID>
reccobeats_track_id = <ReccoBeats ID>
```

The application should perform a ReccoBeats lookup using the available Spotify identifier and store the resulting ReccoBeats identifier.

This gives the database a mapping between:

```text
Internal track ID
       │
       ├── Spotify track ID
       │
       └── ReccoBeats track ID
```

---

# 8. Musical Enrichment

Spotify should not be treated as the primary source for historical audio-feature data in a new implementation.

Instead, introduce an **enrichment layer**:

```text
Track
  │
  ├── Spotify metadata
  │
  ├── ReccoBeats features
  │
  └── Last.fm tags
```

This means the system is not unnecessarily dependent on one enrichment provider.

---

# 9. ReccoBeats

ReccoBeats is particularly useful for numerical musical features.

Potential features include:

| Feature | Example use |
|---|---|
| `tempo` | BPM-based categorisation |
| `danceability` | Dance playlists |
| `energy` | Workout / high-energy playlists |
| `valence` | Positive vs darker music |
| `acousticness` | Acoustic playlists |
| `instrumentalness` | Instrumental playlists |
| `speechiness` | Spoken-word / rap distinction |
| `liveness` | Live-performance detection |
| `loudness` | Intensity / volume analysis |

Example conceptual record:

```json
{
  "tempo": 128.4,
  "danceability": 0.82,
  "energy": 0.91,
  "valence": 0.74,
  "acousticness": 0.03,
  "instrumentalness": 0.01,
  "speechiness": 0.04,
  "liveness": 0.12,
  "loudness": -5.4
}
```

Recommended table:

```text
track_audio_features
---------------------
id
track_id
provider
provider_track_id
tempo
danceability
energy
valence
acousticness
instrumentalness
speechiness
liveness
loudness
retrieved_at
```

The `provider` field is important because it allows additional providers to be introduced later.

---

# 10. Last.fm for Genres and Tags

Last.fm is useful for information that is much harder to express numerically.

Potential tags include:

```text
rock
alternative
indie
electronic
house
techno
hip-hop
rap
pop
soul
funk
jazz
```

A track might therefore have:

```text
Track:
Daft Punk – Around the World

Last.fm tags:
- electronic
- house
- french house
- dance
- disco
```

Do **not** store genre as a single string.

Instead:

```text
genres
------
id
name
```

and:

```text
track_genres
------------
track_id
genre_id
provider
confidence
```

This allows one track to have multiple genres/tags.

---

# 11. Other Potential APIs

These should be treated as optional enrichment providers rather than mandatory dependencies.

| Provider | Useful information | Priority |
|---|---|---:|
| Spotify | Track/artist/album/playlist metadata | **Core** |
| ReccoBeats | BPM, energy, danceability, valence etc. | **Core** |
| Last.fm | Genres, tags, artist metadata | **Core** |
| MusicBrainz | Artist/album/recording identity and IDs | Medium |
| GetSongBPM | BPM / tempo | Optional fallback |
| AcousticBrainz | Audio descriptors | Investigate availability |
| Discogs | Release/artist metadata | Optional |

The key design principle is:

> **Do not call every API for every song.**

Use a provider waterfall:

```text
Need audio features?
       │
       ▼
ReccoBeats
       │
       ├── Success → store
       │
       └── Failure
              │
              ▼
        fallback provider
```

This reduces:

- API calls
- Execution time
- Rate-limit problems
- Duplicated data

---

# 12. Data Quality and Provenance

Every enrichment value should have provenance.

For example:

```text
track_audio_features

track_id: 1234
tempo: 127.8
energy: 0.91
provider: reccobeats
retrieved_at: 2026-08-08
```

For genres:

```text
track_genres

track_id: 1234
genre_id: 15
provider: lastfm
confidence: 0.87
```

This allows the system to answer:

> Where did this information come from?

This is important because third-party APIs can disagree.

---

# 13. Recommended PostgreSQL Model

At a high level:

```text
users
  │
  └── playlists
        │
        ├── playlist_imports
        │       │
        │       └── playlist_items
        │                    │
        │                    ▼
        │                  tracks
        │                    │
        │              ┌─────┴─────┐
        │              ▼           ▼
        │           artists      albums
        │
        └── generated_playlists
```

Enrichment sits alongside tracks:

```text
tracks
  │
  ├── track_audio_features
  │
  ├── track_genres
  │
  └── external_track_ids
```

The key modelling principle is to keep **source data, enrichment data and classification data separate**.

---

# 14. Classification Architecture

There are two distinct problems.

## Problem A — Objective categorisation

For example:

```text
tempo > 120
energy > 0.75
danceability > 0.70
```

This does not require AI.

A normal rules engine is:

- Deterministic
- Cheap
- Explainable
- Testable
- Reproducible

Example:

```text
energy >= 0.80
       ↓
HIGH ENERGY
```

```text
tempo >= 120
       ↓
FAST
```

```text
danceability >= 0.75
       ↓
DANCEABLE
```

---

## Problem B — Subjective categorisation

Examples:

> "Which songs feel appropriate for a late-night drive?"

> "Which tracks fit a chilled summer evening?"

> "Which tracks would work well for a workout?"

These are potentially more suitable for a semantic classification layer.

---

# 15. Recommended Hybrid Classification Model

Use three layers.

## Layer 1 — Deterministic Rules

Calculate objective classifications:

```text
tempo_category
energy_category
danceability_category
acoustic_category
instrumental_category
```

---

## Layer 2 — Genre / Tag Classification

Use Last.fm tags to establish categories such as:

```text
electronic
rock
indie
hip-hop
house
jazz
```

Then normalise them.

For example:

```text
"electro house"
"electro-house"
"electrohouse"
```

could all map to:

```text
Electronic → House
```

---

## Layer 3 — Semantic Classification

Higher-level categories could include:

```text
Workout
Party
Chill
Focus
Driving
Late Night
Summer
Morning
Romantic
```

This is where an AI layer could potentially be useful, subject to the applicable API/provider terms and policies.

---

# 16. AI Agent Role

The AI agent should **not** be responsible for retrieving data from Spotify or directly modifying playlists.

Instead:

```text
                    AI Agent
                       │
                       ▼
             Classification request
                       │
                       ▼
             Structured track data
                       │
                       ▼
                 Classification
                       │
                       ▼
              Structured response
```

Example output:

```json
{
  "track_id": 1234,
  "categories": [
    "dance",
    "high_energy",
    "electronic"
  ],
  "confidence": 0.91,
  "reason_codes": [
    "high_energy",
    "high_danceability",
    "house_genre"
  ]
}
```

The AI should return **structured output**, not prose.

---

# 17. Important Spotify / AI Policy Consideration

Spotify's current developer policies include restrictions around the use of Spotify Content in machine-learning and AI models.

Therefore, the production system should **not assume that Spotify-derived data can simply be sent to an arbitrary AI model**.

This should be treated as a policy/licensing decision requiring review.

For an initial implementation, the safer foundation is:

```text
Spotify
   ↓
Structured data
   ↓
Deterministic classification
   ↓
Playlist
```

The AI layer can then be introduced only where the relevant terms permit the proposed processing.

---

# 18. Agent Workflow

A practical workflow would be:

```text
1. User selects Spotify playlist
              ↓
2. Extract playlist items
              ↓
3. Identify new/changed tracks
              ↓
4. Check PostgreSQL cache
              ↓
5. Enrich missing tracks
              ↓
6. Validate data quality
              ↓
7. Calculate deterministic features
              ↓
8. Categorisation
              ↓
9. Validate classifications
              ↓
10. Generate playlist assignments
              ↓
11. Preview changes
              ↓
12. User approval
              ↓
13. Update Spotify
              ↓
14. Record result
```

---

# 19. Do Not Let the AI Directly Modify Spotify

Separate:

```text
AI decision
```

from:

```text
Spotify mutation
```

The agent should produce:

```text
Track 123 → Workout
Track 456 → Chill
Track 789 → Electronic
```

A normal application service should then validate this.

Only after validation should the Spotify integration execute the changes.

This prevents an incorrect AI response from directly causing destructive playlist changes.

---

# 20. Generated Playlist Management

Maintain a mapping such as:

```text
generated_playlists
-------------------
id
user_id
source_playlist_id
spotify_playlist_id
category_id
created_at
updated_at
```

Example:

```text
Source:
"My Massive Playlist"

             │
             ├── High Energy → Spotify playlist
             ├── Chill       → Spotify playlist
             ├── Electronic  → Spotify playlist
             └── Workout     → Spotify playlist
```

When the source playlist changes, calculate a new desired state.

Instead of blindly adding tracks:

```text
current Spotify playlist
          ↓
desired playlist
          ↓
diff
          ↓
add/remove/reorder
```

---

# 21. Example Categorisation

Imagine:

| Track | BPM | Energy | Danceability | Genre |
|---|---:|---:|---:|---|
| A | 128 | 0.92 | 0.88 | House |
| B | 74 | 0.31 | 0.42 | Indie |
| C | 140 | 0.86 | 0.79 | Drum & Bass |
| D | 105 | 0.45 | 0.71 | Hip-Hop |

The classification engine could produce:

```text
A
→ High Energy
→ Dance
→ Electronic
→ Fast

B
→ Low Energy
→ Indie
→ Chill

C
→ High Energy
→ Dance
→ Electronic
→ Fast

D
→ Medium Energy
→ Danceable
→ Hip-Hop
```

The playlist generator could then create:

```text
🔥 High Energy
💃 Dance
🎧 Electronic
🌙 Chill
🎸 Indie
🏋️ Workout
```

---

# 22. Caching Strategy

Caching is essential.

Suppose:

```text
Playlist A = 500 tracks
Playlist B = 300 tracks
Playlist C = 400 tracks
```

There may only be:

```text
650 unique tracks
```

The system should therefore enrich each **track once**, rather than once per playlist.

```text
Spotify playlist
       ↓
Spotify track ID
       ↓
PostgreSQL lookup
       │
       ├── Exists + features → use cached data
       │
       └── Doesn't exist → call enrichment APIs
```

This substantially reduces:

- API calls
- Execution time
- Rate-limit problems
- Duplicated data

---

# 23. Failure Handling

Every external API call should be treated as unreliable.

For example:

```text
ReccoBeats
   │
   ├── 200 → store
   ├── 404 → mark unavailable
   ├── 429 → retry/backoff
   └── 500 → retry
```

The database should record:

```text
enrichment_status
last_attempted_at
attempt_count
error_code
error_message
```

This allows failed tracks to be retried without rerunning the entire playlist.

---

# 24. MVP Roadmap

## MVP 1 — Extraction

Build:

```text
Spotify
   ↓
Playlist
   ↓
Track metadata
   ↓
PostgreSQL
```

Success criteria:

- Correctly authenticate
- Retrieve playlists
- Handle pagination
- Store tracks
- Handle duplicates
- Support repeated imports

---

## MVP 2 — Enrichment

Add:

```text
PostgreSQL
    ↓
ReccoBeats
    ↓
Audio features

PostgreSQL
    ↓
Last.fm
    ↓
Genre/tags
```

Success criteria:

- High percentage of tracks successfully enriched
- Cached enrichment reused
- Failed requests retried
- Provider/source recorded

---

## MVP 3 — Rules Engine

Implement:

```text
High Energy
Chill
Dance
Fast
Slow
Instrumental
Electronic
Rock
Hip-Hop
```

No AI yet.

This establishes whether the underlying data actually produces useful playlists.

---

## MVP 4 — AI / Semantic Layer

Only after the deterministic system works should the AI component be investigated.

The AI layer could then help with:

```text
User:
"Create a late-night driving playlist"

        ↓

Classification specification

        ↓

Feature/category filters

        ↓

Candidate tracks

        ↓

Ranking

        ↓

Playlist
```

This is much more robust than:

> "Here are 500 songs, please sort them."

---

# 25. Recommended Technology Stack

| Component | Technology |
|---|---|
| Spotify integration | Spotify Web API |
| Enrichment | ReccoBeats |
| Genre/tag enrichment | Last.fm |
| Database | PostgreSQL |
| Backend | Python |
| API | FastAPI |
| Workflow orchestration | n8n initially |
| Data validation | Pydantic |
| HTTP | `httpx` / `requests` |
| Database ORM | SQLAlchemy |
| Testing | pytest |
| Classification | Python rules engine |
| AI layer | Separate service/agent |
| Authentication | Spotify OAuth 2.0 |
| Logging | Structured application logs |

Given an existing n8n + PostgreSQL workflow, n8n can initially handle orchestration rather than building a large backend immediately.

---

# 26. Suggested n8n Implementation

```text
[Manual/Webhook Trigger]
          ↓
[Spotify OAuth]
          ↓
[Get Playlist]
          ↓
[Get Playlist Items]
          ↓
[Pagination]
          ↓
[Normalise Track Data]
          ↓
[PostgreSQL: Find Existing Track]
          ↓
       ┌──┴──┐
       │     │
    Exists  New
       │     │
       │     ▼
       │ [ReccoBeats]
       │     ↓
       │ [Last.fm]
       │     ↓
       └──┬──┘
          ↓
[PostgreSQL: Save/Update]
          ↓
[Classification]
          ↓
[Generate Playlist Assignments]
          ↓
[Human Approval]
          ↓
[Spotify Playlist Update]
          ↓
[Log Execution]
```

---

# 27. Key Business Requirements

### Functional Requirements

**FR1 — Import playlist**

The system shall allow a user to select a Spotify playlist for processing.

**FR2 — Extract tracks**

The system shall retrieve all playlist items using current Spotify endpoints.

**FR3 — Maintain track identity**

The system shall maintain a single canonical track record regardless of how many playlists contain the track.

**FR4 — Maintain import history**

The system shall retain historical playlist imports/snapshots.

**FR5 — Enrich tracks**

The system shall retrieve available audio and genre metadata from approved external providers.

**FR6 — Cache enrichment**

The system shall avoid unnecessarily repeating enrichment requests.

**FR7 — Categorise tracks**

The system shall assign tracks to one or more categories.

**FR8 — Generate playlists**

The system shall create or update Spotify playlists based on category assignments.

**FR9 — Preview**

The system should allow the user to review proposed playlist changes before they are applied.

**FR10 — Audit**

The system shall record what tracks were assigned to which categories and when.

---

# 28. Non-Functional Requirements

### Reliability

External API failure must not corrupt existing playlist data.

### Performance

Previously enriched tracks should not require another external API call.

### Maintainability

External APIs should be abstracted behind provider-specific services.

For example:

```python
class AudioFeatureProvider:
    def get_features(self, track):
        ...
```

rather than embedding ReccoBeats calls throughout the application.

### Security

Spotify OAuth credentials and refresh tokens must be protected.

### Traceability

Every enrichment value should have:

```text
source
timestamp
external ID
```

### Explainability

A classification should have a reason.

For example:

```text
Workout
-------------------------
energy: 0.91
danceability: 0.83
tempo: 142 BPM
```

rather than simply:

```text
Workout = TRUE
```

---

# 29. Final Recommended Architecture

```text
                  SPOTIFY
                     │
                     │ playlist metadata
                     ▼
              ┌─────────────┐
              │  Extraction │
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │ PostgreSQL  │
              │             │
              │ Canonical   │
              │ music data  │
              └──────┬──────┘
                     │
             ┌───────┴────────┐
             │                │
             ▼                ▼
       ┌───────────┐    ┌───────────┐
       │ReccoBeats │    │  Last.fm  │
       │           │    │           │
       │Audio      │    │Genres/tags│
       │features   │    │           │
       └─────┬─────┘    └─────┬─────┘
             │                │
             └───────┬────────┘
                     ▼
              ┌─────────────┐
              │ Enrichment  │
              │   Layer     │
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │Classification│
              │             │
              │ Rules first  │
              │ AI where     │
              │ permitted    │
              └──────┬──────┘
                     │
                     ▼
              ┌─────────────┐
              │ Playlist    │
              │ assignments │
              └──────┬──────┘
                     │
                     ▼
                  SPOTIFY
```

## Main Recommendation

The most important design decision is to **avoid making the AI agent the centre of the system**.

The core product is:

> **Spotify playlist → canonical music database → enrichment → classification → playlist synchronisation**

This provides a stronger technical BA solution because it demonstrates:

1. API integration
2. API deprecation management
3. OAuth
4. Data modelling
5. ETL / data enrichment
6. Data provenance
7. Caching
8. Error handling
9. Business rules
10. AI orchestration
11. Human-in-the-loop controls
12. Closed-loop synchronisation back to Spotify

The system also remains resilient if Spotify changes an API or an AI provider changes its model.
