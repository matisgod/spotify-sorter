# Spotify Sorter & Intelligent Playlist Generator — Technical Business Analysis Plan

## 1. Executive Summary

### Objective

Build an automated system that extracts a user’s Spotify playlist data via manual JSON file upload, enriches each song with musical metadata using the SoundCharts API, processes tracks through statistical standardized clustering ($K$-Means), categorizes clusters via an AI Agent (`gpt-5-mini`), and creates structured output mapping tracks to musically coherent categories.

For example, a raw Spotify data file containing hundreds of songs could automatically produce:

* **High-Energy House**
* **Dark Techno**
* **UK Garage & Bass**
* **Ambient / Chill**
* **Melodic Deep House**

The key architectural principle is:

> **The user provides local Spotify playlist data via JSON upload; SoundCharts provides musical enrichment; local data processing standardizes audio metrics and executes $K$-Means clustering; the OpenAI AI Agent layer turns mathematical clusters into human-centric playlist categories; the system outputs structured playlist mappings.**

---

## 2. Target Architecture

```text
                    ┌──────────────────────┐
                    │      User Upload     │
                    │                      │
                    │ • Spotify JSON data  │
                    │ • Track URIs & info  │
                    │ • Playlist structure │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Extraction Layer   │
                    │                      │
                    │ Extract from File    │
                    │ Get All Playlists    │
                    │ Get All Songs        │
                    │ Deduplication        │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  SoundCharts API     │
                    │                      │
                    │ Metadata enrichment  │
                    │ Genres & Sub-genres  │
                    │ Audio features       │
                    │ ISRCs & Composers    │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Data Processing & ML │
                    │                      │
                    │ Feature Selection    │
                    │ Standardisation      │
                    │ K-Means (K=10)       │
                    │ Profile Generation   │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │    AI Agent Layer    │
                    │                      │
                    │ OpenAI Chat Model    │
                    │ Cluster Interpretation│
                    │ Category Mapping     │
                    │ Structured Parser    │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Playlist Assignment  │
                    │                      │
                    │ Group Songs By       │
                    │ Generated Playlist   │
                    └──────────────────────┘
```

---

## 3. Spotify Data Ingestion & Setup

### 3.1 User Prerequisites & Data Retrieval

Rather than relying on live Spotify OAuth API calls for track retrieval, this workflow utilizes user-exported Spotify data files:

1. **Spotify Data Download:** The user requests and downloads their personal account data package directly from Spotify.
2. **File Ingestion:** The extracted JSON file (containing playlist data arrays, track names, and `spotify:track:...` URIs) is supplied directly to the workflow’s `Extract from File` node.

### 3.2 Data Extraction Pipeline

The initial workflow nodes handle parsing, unnesting, and deduplicating the imported file payload:

```text
Upload Spotify Data JSON
           ↓
Extract from File
           ↓
Get All Playlists
           ↓
Get All Songs (items)
           ↓
Remove Duplicates
           ↓
Extract URI
```

---

## 4. What Is Extracted from the User Upload?

The extraction layer captures **playlist relationships and track identity** from the raw JSON payload before sending track identifiers for enrichment.

### Playlist Information
* Playlist Name
* Last Modified Date
* Collaborator Array
* Playlist Description

### Track Metadata
* Track Name
* Artist Name
* Album Name
* Spotify Track URI
* Date Added

---

## 5. Track Identity and Canonical Representation

To prevent redundant processing, track identities are normalized by stripping the `spotify:track:` prefix into a raw Spotify Track ID string.

```text
Raw URI: spotify:track:2PsWarAIzrS1LQG8fHr4Dr
Clean ID: 2PsWarAIzrS1LQG8fHr4Dr
```

The system maintains a clean key structure throughout the data pipeline:

| Key Name | Type | Description |
|---|---|---|
| `song_name` | String | Name of the track |
| `isrc` | String | International Standard Recording Code from SoundCharts |
| `artists` | Array | Primary and featured artists |
| `release_date` | String | Album or single release date |
| `duration` | Number | Track length in milliseconds |
| `genres` | Array | Combined root and sub-genres from SoundCharts |
| `audio` | Object | Full set of numerical audio metrics |

---

## 6. SoundCharts API Integration for Musical Enrichment

SoundCharts serves as the single source of truth for detailed track metadata and musical feature values, replacing legacy audio analysis APIs.

```text
Clean Spotify Track ID
          │
          ▼
GET https://customer.api.soundcharts.com/api/v2.25/song/by-platform/spotify/{trackUri}
Header: x-app-id
Header: x-api-key
```

### 6.1 SoundCharts Data Payload

SoundCharts returns both descriptive metadata and low-level numerical audio metrics required for statistical processing:

```json
{
  "object": {
    "name": "Techno Positivo",
    "isrc": { "value": "FR10S2100050" },
    "artists": [{ "name": "Kendal" }],
    "releaseDate": "2021-03-26",
    "duration": 345000,
    "genres": [{ "root": "Electronic", "sub": ["Techno"] }],
    "audio": {
      "tempo": 135.0,
      "energy": 0.89,
      "danceability": 0.76,
      "valence": 0.54,
      "acousticness": 0.01,
      "instrumentalness": 0.82,
      "speechiness": 0.04,
      "liveness": 0.11,
      "loudness": -5.2,
      "key": 1,
      "mode": 1,
      "timeSignature": 4
    }
  }
}
```


## 7. Machine Learning Pipeline: Feature Engineering & Clustering

Once enriched by SoundCharts, songs pass through an automated statistical clustering pipeline rather than static manual rules.

### 7.1 Feature Vector Standardization

To balance parameters across different scales (e.g., `tempo` in BPM vs. `danceability` between $0.0$ and $1.0$), 8 key audio features are extracted and normalized using $Z$-score standardization:

$$\text{Standardized Vector component } z = \frac{x - \mu}{\sigma}$$

Features used: `tempo`, `energy`, `danceability`, `valence`, `acousticness`, `instrumentalness`, `speechiness`, `liveness`.

### 7.2 K-Means Clustering Algorithm

The pipeline executes an unsupervised $K$-Means clustering algorithm directly within a custom JavaScript node:

* **Cluster Parameter ($K$):** 10 distinct centroids.
* **Distance Metric:** Euclidean distance across the 8-dimensional standardized feature vectors.
* **Convergence:** Iterates up to 100 cycles or until centroid movement is below $\text{TOLERANCE} = 0.0001$.

```text
Standardized Vectors
         ↓
Random Centroid Initialization (K=10)
         ↓
Assign Songs to Nearest Centroid
         ↓
Recalculate Means & Update Centroids
         ↓
Check Movement < Tolerance?
  ├─ No  ➔ Repeat Iteration
  └─ Yes ➔ Append 'cluster_id' to Each Track
```

### 7.3 Profile & Representative Track Extraction

For every generated cluster, two summary items are created:

1. **Audio Profile:** Calculates `mean`, `min`, and `max` for all 8 audio parameters alongside a frequency count of top genres.
2. **Representative Songs:** Selects the 5 tracks closest to the mathematical cluster centroid to act as exemplar songs.

---

## 8. AI Agent Layer: Semantic Category Generation

The mathematical output ($K$-Means clusters) is translated into human-understandable playlist categories using an AI LLM Agent.

### 8.1 OpenAI Agent Role

* **Model:** OpenAI Chat Model (`gpt-5-mini` / `gpt-4o-mini`).
* **Input Payload:** JSON summary containing all 10 cluster profiles, genre distributions, and the top 5 representative songs per cluster.
* **Instructions:** Infer cohesive musical themes. The agent is instructed **not** to create a playlist for every cluster blindly, but to merge musically similar clusters and filter out incoherence.

```text
                    Cluster Profiles & Representative Songs
                                       │
                                       ▼
                       ┌──────────────────────────────┐
                       │   AI Agent (gpt-5-mini)      │
                       │                              │
                       │ • Evaluates audio profiles   │
                       │ • Analyzes representative    │
                       │   track titles & genres      │
                       │ • Merges similar clusters    │
                       │ • Names & describes playlists│
                       └──────────────┬───────────────┘
                                       │
                                       ▼
                       ┌──────────────────────────────┐
                       │ Structured Output Parser     │
                       │                              │
                       │ Formats response into valid  │
                       │ JSON schema                  │
                       └──────────────┬───────────────┘
```

### 8.2 Structured Output Schema

The AI Agent returns a strict JSON structure containing the playlist assignments:

```json
{
  "playlists": [
    {
      "name": "High-Energy House",
      "description": "Upbeat, highly danceable electronic tracks with driving rhythm.",
      "clusters": [2, 7]
    },
    {
      "name": "Dark Techno",
      "description": "Fast, intense electronic tracks featuring heavy basslines.",
      "clusters": [1, 5]
    }
  ]
}
```

---

## 9. Final Playlist Mapping & Output Generation

The concluding stage maps all original songs back to the AI-generated categories based on their mathematical cluster IDs.

```text
AI Playlist Definitions + Songs with Cluster IDs
                       │
                       ▼
    [ Build Cluster ➔ Playlist Mapping ]
                       │
                       ▼
       [ Group Songs By Playlist ]
                       │
                       ▼
          Structured JSON Output
```

### Final Output Payload Format

```json
[
  {
    "playlist_id": "high_energy_house",
    "playlist_name": "High-Energy House",
    "playlist_description": "Upbeat, highly danceable electronic tracks...",
    "songs": [
      {
        "song_name": "Techno Positivo",
        "isrc": "FR10S2100050",
        "artists": ["Kendal"],
        "cluster_id": 2
      }
    ]
  }
]
```

---

## 10. Implementation Technology Stack

| Component | Technology |
|---|---|
| **Workflow Engine** | n8n |
| **Input Data Source** | Exported Spotify Data File (JSON) |
| **Enrichment API** | SoundCharts API (`v2.25`) |
| **Clustering Engine** | Native JavaScript ($K$-Means, $Z$-Score Normalization) |
| **LLM Orchestration** | `@n8n/n8n-nodes-langchain.agent` |
| **AI Model** | OpenAI `gpt-5-mini` |
| **Structured Output Parsing** | LangChain Structured Output Parser |

---

## 11. Key Business & Functional Requirements

### Functional Requirements

* **FR1 — JSON Data Import:** The system shall parse Spotify playlist exports supplied via manual file upload.
* **FR2 — SoundCharts Enrichment:** The system shall enrich track IDs with ISRCs, genres, sub-genres, and audio features using the SoundCharts API.
* **FR3 — Normalization & Clustering:** The system shall normalize audio features and execute $K$-Means clustering ($K=10$) on all tracks.
* **FR4 — AI Semantic Mapping:** The system shall use an LLM Agent to convert mathematical cluster summaries into named, human-friendly playlists.
* **FR5 — Structured Export:** The system shall group all processed tracks into a clean, JSON-formatted playlist structure ready for export or creation.
