# Submersion Manifest — JSON v1

A small JSON-shaped feed format that Submersion can subscribe to. Pair with
the dive-photo workflow: paste the manifest URL into the photo picker's URL
tab → Manifest mode, optionally subscribe, and Submersion will keep your
dive photos in sync as the feed grows.

## Top-level shape

```json
{
  "version": 1,
  "title": "Eric's Dive Photos",
  "items": [ /* 0 or more entries */ ]
}
```

Required: `version` (must be `1`) and `items` (array; may be empty).
Optional: `title` (string).

Unknown top-level fields are ignored — readers should be tolerant.

## Item shape

```json
{
  "id": "dive-2024-04-12-img-001",
  "url": "https://photos.example.com/dive-001.jpg",
  "thumbnailUrl": "https://photos.example.com/dive-001-thumb.jpg",
  "takenAt": "2024-04-12T14:32:00Z",
  "caption": "Yellowtail at the swim-through",
  "mediaType": "photo",
  "lat": 25.123,
  "lon": -80.456,
  "width": 4032,
  "height": 3024,
  "durationSeconds": null
}
```

### Required item fields

| Field | Type | Notes |
|---|---|---|
| `url` | string | Direct URL to media bytes. HTTP(S) only. |

### Optional item fields

| Field | Type | Notes |
|---|---|---|
| `id` | string | Stable identifier. If omitted, Submersion derives `SHA-256(url + takenAt ?? '')` truncated to 32 hex chars. |
| `takenAt` | RFC 3339 timestamp | If no offset is given, interpreted as UTC. |
| `caption` | string | Free-form. Stored as `MediaItem.caption`. |
| `thumbnailUrl` | string | Used for fast list previews. |
| `mediaType` | `"photo"` or `"video"` | Hint; readers may still re-derive from `Content-Type`. |
| `lat` | number | Decimal degrees. |
| `lon` | number | Decimal degrees. |
| `width` | integer | Pixels. |
| `height` | integer | Pixels. |
| `durationSeconds` | integer | For videos. |

Unknown item fields are ignored.

## Stable identity rules

The `(subscriptionId, id)` pair is the stable key Submersion uses to detect
new vs. removed vs. changed entries on subsequent polls. **Never reuse an
`id` for a different photo**, and don't let it change across polls — both
will produce duplicate or orphaned rows.

## Polling expectations

Submersion polls subscriptions at most once per `pollIntervalSeconds / 4`
(or once per hour, whichever is smaller). Servers should support
conditional GET (`ETag` and/or `Last-Modified`) to keep traffic minimal.

## Minimum viable example

```json
{
  "version": 1,
  "items": [
    { "url": "https://example.com/a.jpg" },
    { "url": "https://example.com/b.jpg" }
  ]
}
```

This is valid: each entry will receive a SHA-derived `id`, and the
`takenAt` fields will be filled in from EXIF after the eager fetch pipeline
runs.
