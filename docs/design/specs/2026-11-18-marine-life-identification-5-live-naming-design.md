# Marine life identification, piece 5: live naming

Program overview, with the decisions that apply to every piece:
[2026-11-17-marine-life-identification-program-design.md](2026-11-17-marine-life-identification-program-design.md).
The video piece, which this one changes:
[2026-11-17-marine-life-identification-2-video-design.md](2026-11-17-marine-life-identification-2-video-design.md).
Read both first. This document does not repeat their reasoning.

Decisions are marked **(decided)** when the maintainer made them and
**(proposed)** when they are the designer's call, open to correction.

Target release: chosen by the maintainer when the issue is opened. One pull
request, under the existing `marineLifeIdEnabled` flag with no switch of
its own **(decided)**. That flag is on for iPhone, iPad and Mac since
PR #4701, so this piece reaches divers in the release that carries it.

## What this piece delivers

On an iPhone, iPad or Mac that runs marine life identification:

1. The video scan follows where the diver is watching. It scans forward
   from the playhead, moves to wherever the diver seeks, and fills in what
   it skipped afterwards.
2. A fish is named while it is still in view, about a second after it
   appears, instead of only once it has left the frame. Its name is
   updated when a clearly better view of it comes along.
3. While a video plays, every fish the app could suggest a name for gets
   its pill, not only fish named above the confident bar.

On a device that scans faster than playback (every phone and tablet the
8 GB floor admits, and Apple silicon Macs) the effect is that names appear
as the fish do, wherever the diver is in the video.

## Why

The program promised two kinds of video analysis: a scan first, then
labelled playback, and live naming "on devices fast enough". Piece 2
built the scan. Measured on an iPhone 17 Pro Max, that scan already runs
about three times faster than playback (a 27 s 4K clip in about 7 s), and
it already starts when the video opens. So, played from the start, the
scan keeps ahead. What still stands between the diver and live names is:

- **No names while playing.** Piece 2 shows only confident names while a
  video plays. The published pack (2026.11.18.0356) sets the confident bar
  to 1.01, which nothing reaches, because no bar measured 95% right. So a
  playing video shows only the fish the diver tagged. Suggestions (89.7%
  right, on about a third of fish, in the measured accuracy work) appear
  only when paused.
- **The scan runs from the start towards the end.** A diver who jumps to
  2:00 waits for the scan to get there.
- **A fish is named only when its track closes,** once it has left the
  frame or the video has ended. A fish in view for thirty seconds gets its
  pill late, partway through.
- **Nothing shows until the first ten-second chunk is done,** about four
  seconds on that phone.

The maintainer chose to close these gaps by making the existing scan
follow the playhead and name fish sooner **(decided)**, rather than to
build a second, live engine, and to show suggestions while playing
**(decided)**. The player (`video_player`) gives the app no access to its
frames, so any live naming would decode the file a second time, which is
what the scan already does.

## Goals

- Names at the point the diver is watching, while it plays, as soon as the
  device can produce them, with no separate mode, setting or device list.
- A fish's label from shortly after it appears, not after it leaves.
- One set of results. What the scan finds while following the playhead is
  stored exactly as today's scan results are, so a later playback costs
  nothing and every decision (accept, dismiss, a claim from a dot) works
  as before.
- No work done twice in normal viewing: a stretch of video is scanned
  once, whichever order the diver watched it in. A seek may throw away one
  unfinished chunk.

## Non-goals

- A second inference path that reads the player's frames.
- Android, Windows and Linux (piece 3). Nothing here is Apple-specific in
  Dart, so piece 3 inherits it.
- Scanning a video the diver has not opened, or after they leave it. Both
  stay as in piece 2.
- Changing the naming bars or the label look.
- Measuring a 6 GB phone or changing the memory floor.

## Anti-goals

- A scan that chases a playhead it cannot catch, scanning fragments and
  never finishing anything.
- Names that flicker from one species to another every few seconds.
- Labels on the wrong fish where two scanned stretches meet.
- A filled pill left on a fish the app has since named as something else,
  when the diver never picked that fish.
- More battery or memory than today's scan for the same video, beyond the
  small costs counted under "Cost".

## Constraints

- Everything in piece 2's constraints still holds: links only, no
  download started by the scan, no GPU work in the background on iOS, the
  plugin's single serial queue.
- The Swift side does not change. Pass 1 (`detectVideo`) already starts
  at any time in a video, and pass 2 (`embedMoments`) takes any moments.
  Pass 1 is one native call per chunk and cannot be interrupted part-way.
- Three other marine life sessions are open in parallel (auto-apply, the
  naming layer, pack install). Any of them may take the next schema
  number; this piece takes whichever number is free when it merges.

## Approaches

Three ways of recording which parts of a video are scanned were weighed.

1. **Scanned stretches (chosen).** The run row holds a short list of the
   stretches that are scanned. The scan goes to the first gap at or after
   the playhead, and fills gaps behind it once it reaches the end. Any
   number of seeks is handled. Needs a schema step.
2. **One mark plus one jump stretch.** Today's "scanned from the start to
   here" mark, plus one stretch scanned after a jump. Smaller, but a second
   jump either throws the first jump's work away (to be scanned again) or
   has to wait for it.
3. **Jump-ahead results in memory only.** No schema change, but every
   jumped-to part is scanned twice, its labels vanish on reopening, and a
   decision on one of its fish has nowhere to be kept. Ruled out.

The maintainer chose approach 1 **(decided)**.

## Behaviour

### Labels while playing

**(decided 2026-11-18, reversing piece 2's "only confident names while
playing")**

- While playing, every undecided fish that passed the bars to be suggested
  shows its outlined pill, exactly as it does when paused. A fish above
  the confident bar shows the same pill, as today.
- Accepted fish show their filled pill, as today. Dots stay paused only.
- Everything else in piece 2's label rules holds: at most six labels at
  once, largest first; nothing over a dismissed fish or one with no name;
  pills and dots take taps only while paused.

### Where the scan works

- **Opening a video.** As today, after the trigger's dwell. The scan starts
  at the first unscanned point at or after the playhead (the start, for a
  video just opened).
- **Seeking.** When the diver seeks, the scan moves to the first unscanned
  point at or after the new position **(decided: the scan follows where the
  diver is watching)**. A seek into a stretch already scanned moves it to
  the end of that stretch, if that end is not the end of the video.
- **A seek drops the running chunk (decided).** The chunk in progress
  stops at the next point where it safely can: after pass 1, or between
  two batches of pass 2. Nothing of it is stored (piece 2's stop path),
  and its stretch is scanned again later. On the iPhone 17 Pro Max that
  puts names at the new spot about 2 to 3 s after the seek, and a seek
  throws away at most about 3.5 s of scanning.
- **Scrubbing.** While the diver drags the scrubber nothing moves. The scan
  moves once the playhead has settled for about half a second
  **(proposed)**.
- **Pausing.** Pausing never stops the scan. Pausing at a point not yet
  scanned moves the scan there, like a seek, so the paused frame's pills
  and dots come first **(proposed)**.
- **Never chasing.** During normal playback the scan does not move to the
  playhead, even when playback has overtaken it. Only a seek, or a pause on
  unscanned video, moves it **(decided: a slow device behaves exactly as a
  fast one)**. A device slower than playback would never catch a moving
  playhead, so chasing would only scatter its work.
- **Filling gaps.** When the scan reaches the end of the video, it goes
  back to the first gap from the start and fills gaps in order until the
  whole video is scanned **(proposed)**. A video left on screen ends up
  fully scanned, as today.
- **Leaving the video**, the app going to the background, a hot device:
  exactly as piece 2. The chunk in progress finishes and is stored, and the
  next opening picks up from the playhead.

### How soon labels appear

- **The first chunk after opening or a seek is short**, about 2 s of video,
  so the first pills can appear within a second or two of opening on the
  iPhone 17 Pro Max **(proposed)**. Later chunks are longer (10 s, as
  today), since by then the scan is ahead. Exact lengths are the
  builder's, within that target.

### Naming a fish while it is in view

**(decided: name early, update on a clearly better view)**

- At the end of each chunk, a fish still in view that has been seen for at
  least about a second is named from its best moments so far and stored,
  with its track running to the end of the chunk. Its pill can show from
  then on.
- It carries on as the same track into the next chunk, as a fish does
  today when a stopped scan resumes.
- It is named again only when a clearly better view of it has arrived: its
  best new moment is worth markedly more than the moment it was last named
  from, by the same measure that chooses best moments (detector score times
  box area). The row's box and detector score hold that moment, so no new
  column is needed. The builder sets the margin, starting from 1.5 times
  **(proposed)**.
- When the track closes it is named again only under the same rule, not
  automatically.
- Each naming replaces the stored name, candidates, crop, embedding,
  `suggestable`, `confident` and `specific`. The pill can appear, change or
  go partway through a fish's time on screen, and the next playback shows
  the latest name from the fish's first appearance.
- A fish seen for under a second at a chunk's end is not stored yet; it
  stays open in the tracker. If the scan stops there it is kept unnamed, as
  today.

### What a renaming does to the diver's decisions

**(decided: an acceptance by name match is matched again)**

- **Accepted by a name match** (the row is accepted and has no claim): a
  renaming whose new name differs puts it back to undecided, and the
  reconcile that follows decides it again under the current tags. It is
  accepted as whatever tag its new name matches, or, if none does, it is
  undecided and shows its new name as a suggestion. Video only.
- **Named by the diver from the frame** (a claim): never changes. The claim
  is the diver saying "this fish is that species".
- **Dismissed:** never changes.
- **Photos** keep today's rule: a renaming after a pack update leaves
  decisions as they are.
- **Reconcile after each chunk (proposed).** The service reconciles after
  every chunk it stores, not only when the scan ends, so the chip row and
  sheet agree with the labels, which already reconcile in memory.

### Where two scanned stretches meet

When the scan reaches the start of a stretch scanned earlier, a fish in
view on both sides of the seam must stay one fish:

- A track open at the seam is joined to a stored track that starts within
  the tracker's gap allowance after the seam and whose first box overlaps
  its last box by at least the tracker's link overlap. The joined track
  keeps the later row's id and is named again under the better-view rule.
- When both parts carry the diver's say and it differs (one accepted, the
  other dismissed, or two different claims), they are not joined: they
  stay two tracks **(proposed)**. When only one carries it, the joined
  track takes it.

### On a slow or hot device

**(decided: no device list, no measurement, no notice)**

Every device follows the playhead the same way. A device that scans
faster than playback keeps ahead, so labels show as fish appear. A slower
one (an Intel Mac, or a phone slowed by heat) scans the same stretches in
the same order, more slowly: its labels land behind the playhead and show
when the diver pauses or goes back. The progress ring already shows that
the scan is working.

Heat is unchanged from piece 2: a pass refuses to start at a serious or
critical thermal state, the scan stops with what it has, and the next
opening resumes it.

### What the diver sees

Nothing new is drawn: the pill, line and dot, the chip row, the sheet and
the progress ring are piece 2's. What changes is which pills show while
playing, and when and where labels appear:

```
 Today, opened and immediately seeked to 1:30 of a 3:00 clip
   1:30  (no labels)            scan is at 0:25
   1:45  (no labels)            scan is at 0:55; suggestions only paused
   ...   labels near 1:30 only on a later playback, and only paused

 With this piece
   1:30  (no labels yet)        running chunk dropped, scan jumps to 1:30
   1:32  ( Queen Parrotfish )   first short chunk named, shown playing
   1:45  ( Queen Parrotfish )   scan is near 2:15, ahead
```

The progress ring shows the share of the video scanned, whatever order
the stretches were scanned in **(proposed)**.

## How it works

### Storage

Main schema: the next free version (377 at the time of writing).

**`media_identification_runs`** gains one column:

| Column | Meaning |
| --- | --- |
| `scanned_ranges` | Video only: the stretches scanned, packed binary. Null for photos and for videos scanned before this version |

- The packing is a version byte, then each stretch as a start and an end in
  milliseconds. Stretches are kept sorted, non-overlapping and merged where
  they touch. The exact layout is the builder's, like `track_path`'s
  **(proposed)**.
- A null `scanned_ranges` on a video's run is read as one stretch from 0 to
  `scanned_ms`, so existing rows need no rewrite and no data rung
  **(proposed)**. The tables do not sync, so nothing else needs repair.
- `scanned_ms` keeps its meaning, "scanned from the start up to here": it
  is written as the end of the stretch that starts at 0 (0 when none does).
  Its column note stays true **(proposed)**.
- `scanComplete` becomes "the stretches cover 0 to `video_duration_ms`".
- A rescan (new models, a crop missing) clears the stretches, as it sets
  `scanned_ms` to 0 today.

### Telling the scan where the playhead is

- The viewer's video item reports the playhead to the service: on a seek
  once it has settled, and on a pause at a point not yet scanned. Reports
  go through a new method on `MediaIdentificationService` (named by the
  builder), keyed by media id. A report for a video that is not being
  scanned is remembered for when its scan starts, and dropped when the
  diver leaves the video.
- The scan reads the latest reported position after pass 1 and between
  pass 2 batches (to drop the running chunk) and between chunks (to choose
  the next).
- How a seek is told apart from playback (a jump in position larger than
  playback explains) is the builder's.

### Choosing the next chunk

A pure function beside the refresh rules, with tests: given the scanned
stretches, the video's length, where the last chunk ended, and the latest
reported position, it returns where the next chunk starts and how long it
may be (it ends at the next stretch's start at the latest). After the last
gap it returns none.

### The scan

`VideoIdentificationScan` changes from "carry on from `scanned_ms`" to
"scan the chunk the choosing function names":

- It keeps one tracker per run of consecutive chunks. When the next chunk
  does not start where the last one ended, the open tracks are stored (as
  `finish` does when a scan stops, named under the rules above) and the
  tracker starts afresh at the new point.
- When a chunk ends at the start of a stretch scanned earlier, the seam
  rule joins tracks.
- At the end of every chunk, open tracks seen for about a second or more
  are named (if not named yet, or under the better-view rule) and stored.
- Resuming on the next opening uses today's mechanism: stored tracks that
  end at a stretch's end are taken up again when the scan continues from
  there.

### Labels

`labelKind` in `track_labels.dart` gives a suggestable undecided track an
outlined pill while playing as well as paused. The rest of the label code
is unchanged.

### Cost

- **Memory:** unchanged. The same two passes run one at a time, holding one
  frame at a time.
- **Battery and heat:** about the same total work as today, since each
  stretch is scanned once. Three small additions: renaming a fish on a
  better view embeds up to three more moments (about 33 ms each on the
  phone, from the measured pass 2); each jump or short chunk adds one more
  decoder start, which decodes from the keyframe before it; and a seek
  throws away the unfinished chunk, at most about 3.5 s of scanning on the
  phone.
- On the iPhone 17 Pro Max the scan's speed leaves room for these: pass 1
  took about 1.6 s and pass 2 up to 1.9 s per 10 s of 4K video.

## Edge cases

- **A seek while a short video's only chunk runs.** The chunk is dropped
  and the scan starts at the new point; the rest is filled afterwards.
- **Seeking back and forth inside scanned video.** Nothing moves; the scan
  carries on from where it was.
- **Seeking to the very end.** The chunk is shorter than the minimum; it is
  scanned as it is, then the scan fills from the start.
- **Two seeks within one chunk.** Only the latest position counts.
- **Many seeks in a row.** Each drops at most the chunk running; scrubbing
  moves nothing until the playhead settles.
- **A fish that appears, leaves, and comes back.** Two tracks, as today.
- **A rename that drops a fish below the suggest bar.** Its pill goes,
  playing or paused; paused, it may show a dot under piece 2's rules.
- **A fish accepted by name match, renamed to a species also tagged.** It
  is accepted as that species, and its filled pill shows it.
- **The pack changes mid-scan.** As piece 2: the running chunk finishes,
  then the pack change runs. Stretches are cleared only by a rescan.
- **A video scanned before this version.** Read as one stretch from 0;
  following the playhead works from the next opening.
- **A logbook switch mid-chunk.** The chunk's results are dropped, as
  today.

## Testing

Tests are written first. Run only the test files written or changed, by
path.

- **Stretch codec:** round trip, merging, version byte, a bad blob, null
  read as one stretch from `scanned_ms`.
- **Choosing the next chunk:** opening, seek ahead, seek into a scanned
  stretch, pause on unscanned video, playback overtaking the scan (no
  move), reaching the end then filling gaps, the short first chunk, a chunk
  ending at a stretch.
- **Naming early:** a fish named after about a second in view; not named
  again without a better view; named again with one.
- **Renaming and decisions:** an acceptance by name match put back and
  decided again (accepted as another tag, or undecided); a claim and a
  dismissal untouched; photos unchanged.
- **Seams:** joined when the boxes overlap; kept apart when the diver's say
  conflicts; the joined track takes the one decision there is.
- **Label rules:** a suggestable undecided track shows a pill while
  playing; dots still paused only; the six-label cap.
- **Scan:** a seek drops the running chunk after pass 1 and between
  batches, storing nothing of it; open tracks stored at each chunk's end;
  resume across openings with stretches. Uses the fake `VisionEngine`.
- **Service:** playhead reports reach a running scan, are remembered for a
  queued one, and are ignored for other media; reconcile after each chunk.
- **Storage:** the migration following
  `test/core/database/migration_v362_dive_deco_status_test.dart`;
  repository reads and writes of `scanned_ranges`.
- **Widget:** the video item reports a settled seek and a pause on
  unscanned video, and nothing during playback; the label layer shows a
  suggestion pill while playing.

The Swift side is unchanged, so no new native check is needed. The real
check is the macOS app against the published pack and a real dive video:
seek ahead of the scan and watch suggestions appear while playing.

## Screenshots for the pull request

Before and after: a playing video at a point seeked ahead of where the
scan would have reached. Before shows no pills; after shows suggestion
pills while playing. Taken through the macOS background window route
with its own empty database.

## Left to the builder

- Internal names, file layout and the service method's shape.
- Chunk lengths, within "first pills within a second or two" on the phone.
- How a seek is detected and how long the playhead must settle.
- The better-view margin, starting from 1.5 times.
- The `scanned_ranges` packing.

## Documents to update

- The program overview: "How labels look on video" (suggestions show while
  playing), "Video analysis" and "The pieces, in order" (live naming is the
  scan following the playhead, on every device).
- `docs/developer/species-identification.md`: the scan's order, early
  naming, the new column and the label rule.
- The generated SQL column notes, for `scanned_ranges`.

## For the maintainer to check

Calls made in this document that are the designer's, not yours:

1. Scrubbing moves nothing until the playhead settles for about half a
   second.
2. Pausing on unscanned video moves the scan there, like a seek.
3. After reaching the end, the scan goes back and fills the gaps, so a
   video left on screen ends fully scanned.
4. The first chunk after opening or a seek is about 2 s; later chunks
   stay 10 s.
5. A renaming needs a view worth 1.5 times the one the fish was named
   from, by detector score times box area.
6. Where stretches meet, two parts of a fish with conflicting decisions
   stay two tracks.
7. The service reconciles after every chunk.
8. Videos scanned before this version need no data rewrite: their single
   mark is read as one stretch.
9. The progress ring shows the share scanned, in any order.
