# Site picker: device-location fallback (issue #965)

Date: 2026-08-11
Issue: https://github.com/submersion-app/submersion/issues/965

## Problem

Reported against v1.7.3.5623: assigning a dive site to a manually recorded dive
lists the nearest sites first, but doing the same to a dive brought in by a
Bluetooth dive computer import lists sites alphabetically.

## Root cause

There is no separate site picker for imports. Both paths open the same
`SitePickerSheet`
(`lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart`),
which sorts by distance only when it can resolve an anchor point:

```dart
GeoPoint? get _anchor {
  if (widget.diveLocation != null) return widget.diveLocation;
  final cl = widget.currentLocation;
  return cl == null ? null : GeoPoint(cl.latitude, cl.longitude);
}
```

With no anchor the sheet takes the `else` branch and preserves the order it
received from `sitesProvider`, which is `SiteRepositoryImpl.getAllSites` ->
`OrderingTerm.asc(t.name)`. Alphabetical order is therefore not a separate code
path; it is the absence of a location.

Both anchors are null after a dive computer import:

- `diveLocation` is null because dive computers do not record surface GPS.
  `parsed_dive_mapper.dart` never sets `entryLocation`/`exitLocation`; GPS is
  only stamped opportunistically from a recorded surface track in
  `dive_import_service.dart`.
- `currentLocation` is null because `DiveEditPage` calls
  `_captureLocationForNearby()` only on the new-dive branch
  (`dive_edit_page.dart`), never when `isEditing` and never when `isBulk`.

An imported dive is edited, not created, so it never gets a device fix. The same
gap silently affects `BulkDiveEditPage`, which is how a user would assign one
site to a batch of freshly imported dives.

## Design

Make `SitePickerSheet` self-sufficient about its anchor rather than fixing the
one caller. Showing nearby sites is the sheet's job, so resolving the location
belongs there, and every present and future caller benefits.

### Anchor resolution

`_anchor` gains a third rung: `diveLocation ?? currentLocation ?? _deviceLocation`.

`_deviceLocation` is resolved once from `initState`, and only when the caller
supplied neither anchor:

```dart
if (widget.diveLocation == null && widget.currentLocation == null) {
  unawaited(_resolveDeviceLocation());
}
```

The resolver reads `locationServiceProvider` and requests coordinates only
(`includeGeocoding: false`) with a 10 second timeout, mirroring
`DiveEditPage._captureLocationForNearby`.

Resolution lives in `initState`, not `build`: `build` re-runs on every keystroke
in the search field, so a build-triggered lookup would fire repeated GPS
requests.

The `diveLocation == null && currentLocation == null` guard keeps this cheap. A
dive that already has GPS never pays for a fix, and the new-dive path still uses
the `_currentLocation` the edit page pre-warmed.

### Data flow

Unchanged downstream. The anchor feeds `_distanceToSite` (Haversine,
`core/utils/geo_math.dart`), which feeds the existing nearest-first sort with
GPS-less sites last. The search filter still runs after sorting, so filtered
results stay distance-ordered. When the fix arrives, `setState` re-runs `build`
and the list re-sorts in place.

`SiteRepositoryImpl.getAllSites` keeps its name ordering. That order is correct
for the sites list page, and the picker has always been the layer that re-ranks.

### Header states

Three, up from two:

| Condition | Icon | String |
| --- | --- | --- |
| dive GPS anchor | `Icons.place` | `diveLog_sitePicker_sortedByDiveDistance` |
| device GPS anchor | `Icons.my_location` | `diveLog_sitePicker_sortedByDistance` |
| resolving, no anchor yet | `Icons.my_location`, muted | `diveLog_edit_gettingLocation` |

All three keys already exist, so no ARB changes across the 11 locales.

The resolving state uses a static icon rather than a `CircularProgressIndicator`,
which the first draft of this change used. An indeterminate indicator schedules
frames forever, so `pumpAndSettle` never returns while one is on screen. Because
this is a shared widget, the breakage landed in an unrelated consumer test
(`dive_edit_geofence_suggestion_test.dart`, which taps "Add site" and settles),
and it would recur in every future test that opens the sheet. Reusing the
resolved-state icon also avoids an icon swap when the fix arrives; only the text
changes.

### Error handling

`LocationService.getCurrentLocation` already returns null for disabled location
services, denied permission, and permanently denied permission, and swallows
platform errors internally. A `try`/`catch` in the resolver is belt and braces.
A null result leaves the anchor null and the list alphabetical, which is exactly
today's behavior. Nothing is surfaced to the user: proximity sort is a
convenience, not a requirement.

## Testing

`locationServiceProvider` is the existing injection seam. The `_pump` helper in
`site_picker_sheet_test.dart` gains a default fake returning null so none of the
8 existing tests reach a platform channel.

New tests:

1. No `diveLocation`, no `currentLocation`, fake device GPS at the reef ->
   distance order and the "Sorted by distance" caption. This is the #965
   regression test.
2. Device GPS returns null -> alphabetical order, no caption. Guards the
   graceful fallback.
3. `diveLocation` supplied -> the fake is never called. Guards against spending
   a GPS fix when the dive already has coordinates.
4. A fix still in flight -> the "Getting location..." caption shows, and
   completing the fix replaces it with distance order.

Test 3 passes against the unfixed code, so it was verified by mutation: removing
the `initState` guard makes it, and only it, fail.

## Out of scope

- Pre-warming GPS in `DiveEditPage.initState` on the edit path.
- Changing repository ordering.
- The `!widget.isEditing` gate on the form-row caption in `dive_edit_page.dart`,
  which is the form's own hint and independent of the sheet.

## Known limitation

Importing dives by Bluetooth long after the trip and away from the site ranks
sites near the device now, not near where the dive happened. This is inherent to
the parity the issue asks for; the manual path behaves identically. It is
mitigated by the per-tile distance readout, by the "nearby" highlight firing
only under 50 km, and by search. No date or location heuristics are added.
