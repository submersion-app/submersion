# Seacraft ENC tracks: original file, update in place, origin, markers, export

Issue: #4231

## Problem

A Seacraft ENC CSV holds every row as metres north and east of the
console's own origin. That origin is where the console was switched on,
or the first point of a dive plan stored on it, which can belong to
another site. The app drew each sample at the track's anchor (the site
pin) plus that offset, so a recording made with an old plan still on the
console landed as far from the site as the old plan's start: 37 km in
one real recording, 300 m in another. The CSV has no coordinates and no
jump that would reveal it.

The import also dropped raw values (negative `BattV` markers, depths
between -1 and 0 m, out-of-range courses), so a recording could neither
be derived again after a parser fix nor exported unchanged. Re-importing
the same file only offered "Replace", which deleted the stored track with
its alignment, site, name and dive link.

## Decisions

1. **Original file.** `nav_tracks.source_file` (v343, nullable BLOB)
   keeps the file gzipped and byte for byte as it arrived
   (`nav_track_source_file_codec.dart`, capped at 16 MB in both
   directions because the column syncs). `points` stays the derived cache
   every reader already uses. Only ENC imports store a file.
2. **Origin.** The parser rebases every recording on the first sample of
   the active range (`rebaseOnActiveStart`), always and without a
   threshold: the app never knows where the console's origin is, so no
   distance can tell a wrong origin from a right one. A pre-dive GPS
   calibration stays before the reference, so the anchor keeps meaning
   "where the dive began". Every sample shifts by the same amount, so
   steps, fix events and the active range are unchanged.
3. **Markers.** A negative `BattV` on any row but the first is a marker.
   The first row is excluded because the console keeps the magnetic
   declination there, which can be negative. The value repeats within a
   recording (`-101` twice), so markers are numbered in file order rather
   than by value, and normal and return markers share one symbol. They are
   read from the stored file, not stored on their own, so they always
   match the points derived from it. They show on the detail map, the
   alignment page and the track's 3D view (labelled with the same
   number), not in the seascape.
4. **Re-import.** A file counts as already imported when its name matches
   a stored track's `source_ref` and the recordings start within seven
   days of each other. The ENC numbers files `001` to `050` and starts
   over, so a name alone matches different dives months apart. The review
   page then asks: update the stored track or import a new one. Updating
   is preselected only when the two recordings overlap in time (the same
   recording read again); a file of the same name recorded at another
   time within the window may be a different dive, so a new track is
   preselected there.
   Updating rewrites only the data (file, points, statistics, times) and
   keeps every setting: dive link, primary role, site, name, device and
   the whole alignment. The detail page offers the same update without a
   time window, confirming first when the picked file has another name.
5. **Export.** The detail page exports the stored file under its
   `source_ref`. A track imported before v343 has none and is pointed at
   "Update from file" first.

## Out of scope

- Correcting a wrong console clock.
- Suunto routes keeping their original file.
- Markers in the seascape view.
- Surface GPS jumps under the segmenter's 50 m threshold during a dive.
