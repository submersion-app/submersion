# Site Details: a "Photos from dives" card

Date: 2026-11-13. Release: v1.8.5. Size: small change (short design).

## Intent

Site Details already lists photos from the dives logged at a site, but they
sit in a collapsed row ("Photos from dives here (N)") at the bottom of the
Site Media card, which is 14th of 18 cards by default. The maintainer did not
know it existed. Goal: a diver opening a site sees its dive photos without
hunting for them.

- **Goal:** dive photos visible near the top of Site Details, with no tap
  needed to see that they exist.
- **Non-goals:** new photo management on the site page (selection, unlink,
  categories stay with site attachments and the dive page); a new gallery
  page; changing which photos count as "from dives at this site".
- **Anti-goals:** loading every photo at the site when the page opens (undoes
  the #4252 / #4275 speed-up); showing the same photos in two cards.

## Approaches

| | Approach | Trade-off |
| --- | --- | --- |
| **A (chosen)** | A separate "Photos from dives" card with a one-row strip | New card id and one small query. Reaches divers with a saved layout, because `ensureAllSections` adds a missing card at its default slot. |
| B | Keep the group in Site Media, open it by default, move Site Media up the default order | Smallest change, but a default-order change never rewrites a saved layout, so existing divers keep it near the bottom. Opening by default loads every photo. |
| C | A photo strip in the page header | Most prominent, but cannot be moved or hidden and crowds the header (the trip header work, #4106, kept headers plain). |

The maintainer picked A.

## Design

**New card.** `SiteDetailSectionId.divePhotos`, declared directly after
`description`, so it is the second card by default. Divers with a saved
layout get it inserted after their Description card by
`ensureAllSections`. Visible by default, movable and hideable like any card,
with an icon, display name and settings description of its own.

**Shown only when the site has dive photos.** The card builder returns null
when the count from `mediaCountFromDivesAtSiteProvider` is zero (or still
loading), the same pattern as Tags and Hazards, so it leaves no gap.

**Collapsed state (default):** title "Photos from dives (N)" plus a
"Show all" action, then one row of the newest photos, newest first. The row
fills the card width: as many fixed-size square tiles as fit (about four on a
phone, more on desktop). Backed by a new
`SiteDiveMediaRepository.getRecentMediaFromDivesAtSite(siteId, limit)` (same
join and enrichment as `getMediaFromDivesAtSite`, ordered newest first, with
a `LIMIT`), read through a new autoDispose family provider that takes the
same media and dives ticks as the flat provider. The limit is a fixed cap
large enough for a wide desktop row; the widget shows as many as fit.

**Expanded state:** "Show all" swaps the strip for the full grid of every
dive photo at the site, chronological, as the old group showed it, read from
the existing `flatMediaFromDivesAtSiteProvider` only once expanded. A "Show
less" action returns to the strip. Expansion is page state, not saved.

**Tap a photo:** opens the existing `SiteMediaViewerPage` with
`SiteViewerScope.divePhotos` at that photo, swipeable across every dive photo
at the site (the viewer's existing chronological order).

**Read-only:** no selection mode, no add button. Same as the old group.

**Site Media card:** the "Photos from dives here" group is removed, so it
shows only media attached to the site directly. Its doc comments and the
settings description for the media card are updated to match.

**List layout:** the card folds to a header row like every other card;
unfolding it shows the strip.

## Constraints

- Thumbnail tiles reuse `MediaThumbnailTile` and respect the active diver's
  unit settings, as the old grid did.
- New strings go through the ARB catalogs; the now-unused
  `media_siteMediaSection_divePhotosGroup` key is removed.
- New providers must pass the provider tick guards in `test/architecture/`.

## Left to the builder

- The strip's exact tile size and the query cap.
- Where the widget file lives (`lib/features/media/presentation/widgets/`
  alongside `site_media_section.dart` is the natural home).
