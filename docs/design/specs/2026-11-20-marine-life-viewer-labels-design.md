# Marine life in the viewer: labels on photos, an All life mode, re-analysis and a tidier panel

Release: v1.8.5. Behind `marineLifeIdEnabled`, like the rest of marine life
identification (program: `2026-11-17-marine-life-identification-program-design.md`).

## Intent

The photo and video viewer is where a diver sees what the app found on a
dive, and today it is a poor place for it:

- A photo shows nothing on the picture. What the app found appears only as
  chips in the bottom panel and rows in the Tag species sheet.
- A video shows a pill on a fish the app can name, and a dot (paused only)
  on some it cannot. Everything else it found stays hidden, and at most six
  labels are drawn at once.
- There is no way to turn the labels off, and no way to ask for a fresh look.
- The species chips under the scrub bar wrap without limit. With many
  species they push the scrub bar up the picture until it meets the play
  button.
- Scan progress is a small ring-and-percent chip at the end of those chips,
  on video only. A photo being analysed shows nothing in the frame.

The maintainer's reason: there are species a diver does not necessarily
notice, so the app should have a way to point out all life forms, even when
it cannot name them all, with a quick way to turn that on and off.

## Goals

1. **Labels on photos.** A photo shows the same pills as a video: filled for
   a species the diver tagged, outlined for a name the app suggests.
2. **A labels menu.** One toolbar button opens a menu with three choices,
   Names, All life and Off, and an analyse action, with the analysis status
   at the top.
3. **All life.** Every life form the app detected and stored gets a mark,
   named or not: a plain dot on each one that has no pill.
4. **No limit on labels.** The six-label display limit goes. The species
   pack's limit of 8 detections per frame or photo rises to a ceiling of 100.
5. **Re-analysis.** Analyse, then Analyse again, in the viewer for the photo
   or video on screen, and Check again on the dive's Marine life card for the
   whole dive. A re-analysis keeps the diver's tags and the names they gave,
   and brings back suggestions they dismissed.
6. **A species list that stays one line high.** As many chips as fit, then a
   "+N" chip that opens the full list.
7. **Progress where the diver looks.** On a video, the analysed stretches are
   tinted on the scrub bar. A ring on the labels button shows analysis under
   way on photos and videos alike, and the menu gives the percentage.

## Non-goals

- Tagging a thing that has no species (a stored "unidentified" tag). A dot
  can be tapped to give the animal a species, and nothing more.
- Outline boxes or corner marks around animals. The maintainer chose the dot.
- Keeping pills from overlapping one another in a school.
- Which animals get named, and how well. Naming bars, naming levels, tracker
  rules and the rules that match a tag to a detection do not change here.
- The people chips row in the same panel.
- Syncing the labels choice between devices. It is a device preference, like
  the other marine life preferences.
- A keyboard shortcut for the labels menu.

## Anti-goals

- The bottom panel growing with the number of species again, by any route.
- A re-analysis that drops a species tag, or a name the diver gave an animal
  from the picture.
- A re-analysis the diver asked for writing a species tag by itself.
- All life changing what Names shows. All life adds dots; it never removes
  or restyles a pill.
- Anything drawn while `marineLifeIdEnabled` is off.
- A write to a synced table from a detection, a label mode change or a
  re-analysis. Identification rows are device-local and stay so.

## Constraints

- `MediaIdentifications` and `MediaIdentificationRuns` are device-local and
  never synced. Nothing in this design needs a schema change.
- What is stored, and so what All life can mark: every detection on a photo,
  with its box, whether or not it could be named; on a video, every track
  the scan keeps. A track seen in a single sample, or with no view that can
  be cropped or named, is not stored today (`video_tracker.dart`,
  `video_identification_scan_naming.dart`) and gets no mark. That stays.
- A photo sits inside a zoomable `PhotoView` child (up to 3x "covered").
  Anything drawn in that child scales with the zoom, which is right for the
  people-tag face boxes and wrong for a name pill.
- A page-level tap catcher sits above the gallery for photos and toggles the
  viewer's controls (`media_viewer_page.dart`). As mounted, it wins every tap
  over anything inside the photo page.
- Labels take taps only while an edit sitting is open (the photo or video is
  unlocked, issue #4527), and on a video only while it is paused. Elsewhere
  taps fall through to the viewer.
- The viewer is a swipeable gallery, so nothing in the bottom panel may
  scroll sideways: it would take the swipe that turns the page.
- The scrub bar is the top row of the bottom panel (issue #4762): what is
  under it pushes it up. That stays; the fix is to stop what is under it
  from growing.
- The viewer toolbar gives its slots to the lowest priority numbers
  (`splitToolbarActions`). A phone about 390 points wide has three slots
  while locked and two while unlocked.
- The species pack is built and published from `submersion-app/species-pack`.
  Its tools pin each detector's settings to the detector's id, and the app
  decides whether a stored result is current by comparing those ids. A
  publish needs the maintainer's go-ahead each time.
- PR #4821 (volume and mute for video) is open and edits
  `video_controls_bar.dart`. Keep the change to that file small.
- New strings go in every locale (the pre-push hook checks generated l10n).
- Files stay under the 800-line guard; `media_viewer_page.dart` and
  `media_viewer_toolbar.dart` are already large, so new widgets get their own
  files.

## Approaches

How the labels are built, so photos and videos look and behave the same:

- **A. A shared label painter (chosen).** The drawing and tap handling now
  inside `VideoIdentificationLayer` (the dot, line and pill, their placement,
  the hit targets, opening a suggestion or the species picker) move into one
  shared widget that takes a list of labels and the picture's rectangle. The
  video layer keeps what is video's own (the playhead, playing or paused) and
  feeds it; a new thin photo layer feeds it the photo's detections. One look
  and one place to change it. It moves working video code, which its tests
  cover.
- **B. A separate photo layer.** The video layer is left alone and a photo
  layer reuses only the leaf widgets (`TrackPill`, `TrackDot`,
  `TrackLabelGeometry`). Safest for video, but placement and tap handling
  then exist twice and drift apart the first time one is changed.
- **C. One layer for both.** A photo treated as a one-frame video. Least
  code on paper, but a photo zooms and has no playhead, and a video has no
  zoom, so the single widget fills with photo-or-video branches.

A is chosen. This is the builder's call, put to the maintainer twice without
an objection; it is not something he picked.

## What the maintainer decided

- Pills on photos as on video. All life marks every life form found, with a
  quick way to switch it. No limit on the labels drawn on a video.
- The unnamed mark is the plain dot.
- The detection limit is raised in the species pack (not overridden in the
  app).
- The labels control is one button that opens a menu. It sits in the top
  bar and takes Info's place on a phone.
- Names keeps today's paused dot on a video. A photo in Names behaves like a
  paused video.
- A re-analysis brings back dismissed suggestions, is offered in the viewer
  and on the dive, and tags nothing by itself.
- The action reads Analyse until the item is fully analysed, then Analyse
  again.
- On a photo, a tag's filled pill shows only on animals the app could
  suggest that name for, or that the diver named from the picture.
- The species list is one line with "+N".
- Progress is the analysed stretches on the scrub bar plus a ring on the
  labels button.

## Design

### 1. Label rules (pure functions, `species_id/domain/services`)

A new enum, `LabelMode { names, allLife, off }`.

What one detection or track gets, by mode:

| Detection | Names | All life | Off |
| --- | --- | --- | --- |
| Tagged by the diver (accepted) | filled pill | filled pill | nothing |
| Tagged by the app, unconfirmed | outlined pill | outlined pill | nothing |
| App is confident, undecided | outlined pill | outlined pill | nothing |
| App can suggest, undecided | outlined pill | outlined pill | nothing |
| Anything else, undecided | the guarded dot (below) | dot | nothing |
| Dismissed (rejected) | nothing | nothing | nothing |

- **The guarded dot in Names.** On a video it is today's rule, unchanged:
  while paused, an animal with no pill gets a dot when its open score passed
  the floor (`specific`) and it was followed for a second or more; playing,
  Names shows pills only. A photo behaves like a paused video: a detection
  with no pill gets a dot when its open score passed the floor. The
  one-second rule has no meaning on a still and does not apply. The dot is
  how a diver names an animal the app could not, without leaving the default
  mode.
- **All life** drops both guards: every detection with no pill gets a dot,
  playing or paused, on photos and videos, dismissed ones excepted. It will
  sometimes mark a hand or a diver; that is accepted. A track kept without a
  name while a scan is stopped (`isPending`) gets a dot too.
- **A tag's filled pill on a photo.** The stored rule that matches a photo's
  tag to detections is loose: a tag accepts every detection whose best guess
  is that species, however weak, and a tag that is no detection's best guess
  accepts the one that ranks it highest. That rule and its stored decisions
  do not change. The label rule narrows what is drawn: on a photo, an
  accepted detection draws the filled pill only when the app could suggest
  it (`suggestable` at the naming level in force) or the diver named it from
  the picture (`claimedSpeciesId`). An accepted photo detection that is
  neither draws as "anything else" in the table. Video is unchanged: its
  matching rule already considers only tracks the app could suggest.
- `labelsAt` loses `maxLabels`. Two labels on one animal are still merged
  into one (overlap at or above `sameAnimalOverlap`; the diver's tag first,
  then the app's surest name, a dot last).
- A photo gets one label per detection by the same rules and the same merge,
  from a new pure function beside `labelsAt` (a photo has no playhead and no
  smoothing). Several fish of one species each get their own pill, as on
  video.

### 2. The shared painter and the photo layer

- New widget in `species_id/presentation/widgets/`: draws a list of
  `TrackLabel`s over a picture rectangle. It holds what `_parts`, `_target`,
  `_openPill` and `_PillLayout` do today. Inputs: the labels, the detections
  by id, the item, the picture's rectangle, an optional floor, the sitting
  that takes edits (or null for see-only), and a scale to draw at.
- `VideoIdentificationLayer` keeps the playhead builder and its tag and
  sitting logic, asks `labelsAt` with the current mode, and hands the result
  to the painter. Its behaviour in Names mode is unchanged apart from the
  missing six-label limit.
- New `PhotoIdentificationLayer`, mounted in `_PhotoItem` beside
  `FaceBoxLayer`, for the current page only. It reads the photo's detections
  at the naming level in force (the same read the video layer uses), applies
  the photo's tags as shown in the sitting (`decisionsAsShown`), and hands
  the labels to the painter.
- **Zoom.** Pills, dots and lines keep the same size on screen at any zoom:
  the photo layer draws them scaled by the inverse of the photo's zoom,
  anchored on each animal's dot.
- **Taps on a photo**, with the photo unlocked: a suggestion pill opens
  `SuggestionCropView`, a tagged pill opens the species page, a dot opens the
  species picker and claims the detection for the species picked. A tap that
  lands on a label acts on the label; a tap anywhere else does what it does
  today. The page-level tap catcher has to let label taps through. Locked,
  every label is see-only and taps reach the photo.
- **Claims on a photo are new.** Until now only a video track could be
  claimed. A claim is written at once (`MediaIdentificationService.claim`
  already takes any detection's id) and the tag-matching rule already honours
  a claim on any detection. What is missing is carrying it: a photo's
  `carryDecisions` deletes every undecided row and never copies
  `claimedSpeciesId`. It gains that: a claimed detection is carried to the
  fresh detection that overlaps it by at least `sameAnimalOverlap`, whatever
  the app's new guess, and kept as it is when none does.
- **When the photo layer shows.** It follows the label mode only, not the
  viewer's controls (as the video layer does). It is hidden in people-tag
  mode and while picking a white point, as the video layer is.
- **Pills keep above the controls while unlocked** (the maintainer's
  choice, after review). While a photo is unlocked its toolbar and bottom
  panel stay up and take taps, so a pill is kept above the panel, as a
  video's is; the panel's edge is converted through the photo's zoom and
  pan. A dot under the panel stays there until the photo is moved. Locked,
  labels take no taps and the panel hides on a tap, so nothing moves.

### 3. The labels menu and the mode

- A new toolbar action in the viewer's top bar, shown when the feature is on
  and the item is a photo or a video this platform scans. It is offered
  whether or not the item is locked and in a read-only browser, because it
  changes nothing in the record.
- **Its rank.** It takes the rank Info has today, directly after Share, and
  Info moves one place down. In a dive's viewer on a phone the locked bar
  then shows Unlock, Share and Labels, and the unlocked bar shows Share and
  Labels; Info is in the overflow menu. In the Media library's viewer, where
  Go to dive also takes a slot, Info is already in the overflow menu on a
  phone today and the labels action joins it there. Wide windows show
  everything.
- Tapping it opens a menu:
  - a status line, not selectable: analysing (with the percentage for a
    video), how many were found, not analysed yet, or no species model
    installed;
  - Names, All life, Off, with a check on the one in force;
  - a divider, then the analyse action (section 5).
- In the overflow menu it is one entry that opens the same menu.
- The icon is tinted while the mode is Names or All life and plain when Off,
  and carries the progress ring (section 7).
- The mode is one device preference for photos and videos together, key
  `species_id_label_mode`, default Names, kept the way the naming level
  preference is kept.

### 4. No limit

- App: remove the display limit (section 1). Check that nothing else in the
  app assumes eight boxes; the embedding of crops is already batched.
- Pack (`submersion-app/species-pack`, its own pull request): `maxBoxes`
  rises from 8 to 100 for each detector and for the merged boxes, each
  detector gets a new id, and the pinned-settings tests are updated. No model
  file changes. Because the ids change, every photo and video analysed before
  is analysed again the next time it is opened or the dive's Find species
  runs, with the diver's decisions carried over as they are today.
- 100 is a safety ceiling against a runaway frame, not a target. Cost: naming
  takes about 85 ms per view on an M-series Mac and up to three views per
  animal on video, so a school scene scans noticeably slower. Phones are
  unmeasured.
- Before the pack is published: measure scan time and memory on one school
  clip at the new ceiling on the Mac, report the numbers, and ask for the
  go-ahead.

### 5. Analyse and Analyse again

Two kinds of request the diver can make by hand:

- **Analyse** is an ordinary request: it does whatever the item needs
  (analyse, name again, or carry on a part-scanned video) and nothing if it
  needs nothing. Made by hand, it runs even when "identify on open" is
  switched off.
- **Analyse again** is a fresh request: it analyses the photo, or scans the
  video from the start, whatever `decideRefresh` or `decideVideoRefresh`
  would say. `MediaIdentificationService.request` and `requestFromRun` gain
  a flag for it.

What a fresh run keeps and resets:

- Kept: detections the diver accepted (their tags) and claims (a name given
  from the picture) are carried to the new detections. Species tags
  themselves live in `media_species` and are not touched, including tags the
  app applied and the diver has not confirmed.
- Reset: a dismissed detection is reopened. It is undecided again, so an
  animal the app can still suggest comes back as a suggestion, and it keeps
  a mark that the diver once dismissed it (its decision time stays set on
  an undecided row; no schema change). A reopened detection the fresh run
  does not find again is dropped.
- Nothing is tagged automatically after a fresh run, in the viewer or on a
  dive: auto-apply does not run for it. A reopened detection is never
  auto-applied later either, and the mark is carried through later
  re-analyses. Without it the choice would not hold: auto-apply's only
  memory that the diver removed a tag is the dismissed mark, and it runs
  again every time the item is opened.

Where:

- **Viewer.** The labels menu's action reads Analyse while the item on
  screen is not fully analysed (never analysed, stale, or a video part
  scanned) and Analyse again once it is. No confirmation. Disabled while that
  item is queued or running, and when no model is installed. A video is
  scanned as any video in the viewer is: in chunks, following the playhead,
  while it stays open.
- **Dive.** On the Marine life card, while the dive is not up to date the
  button is Find species, unchanged. When it is up to date the button reads
  Check again and is enabled, where today it reads "all checked" and is
  disabled. Check again goes through the same start flow as Find species
  with every item fresh, after a confirmation that says dismissed suggestions
  on the dive's photos and videos will come back.

### 6. The species list

- `MediaSpeciesChipsRow` becomes one line. Order as today: the diver's tags,
  the app's unconfirmed tags, then suggestions. As many chips as fit on the
  line are shown, followed by a "+N" chip counting the rest.
- "+N" opens the full list: with the item unlocked, the species sheet (what a
  suggestion chip opens today); locked, a read-only sheet with every chip,
  where a tag opens its species page and a suggestion does nothing.
- The scan progress chip leaves this row (section 7).
- The one-line layout with a counted overflow is a small reusable widget; no
  such widget exists in the app yet.
- The same row serves photos and videos, so a photo's panel stops growing
  too.

### 7. Progress

- **Scrub bar.** While a video's scan is incomplete (running, or stopped
  partway), the stretches already analysed are tinted along the track, under
  the played part and the knob. They come from the run's `scannedRanges` and
  move as chunks are stored. Once the whole video is analysed the tint goes,
  so a finished video has a plain bar.
- **Ring on the labels button** while the item on screen is queued or being
  analysed: it fills with the scan's progress on a video and spins on a
  photo. In the overflow menu there is no ring; the menu's status line still
  tells.
- **Menu status line** gives the percentage in words.
- The Tag species sheet keeps its own progress line.
- Colours come from the theme and must read on the viewer's dark surface.

### Screens that change (for the PR's screenshots)

Photo viewer (labels in Names and All life, menu open, panel with many
species), video viewer (scrub bar tint, All life, many labels, panel with
many species), and the dive's Marine life card (Check again). Phone and
desktop widths.

## Calls the builder made (not picked by the maintainer)

- Approach A, and one pull request for all the app parts.
- The labels action takes Info's exact rank, so in the Media library's
  viewer on a phone it sits in the overflow menu, as Info does there today.
- An accepted photo detection the app could not suggest and the diver did
  not name draws like an unnamed one (the guarded dot in Names, a dot in All
  life), not nothing.
- All life shows `isPending` tracks and drops both dot guards. It cannot
  mark a video track the scan does not store.
- The labels action is offered on a locked item and in a read-only browser.
- A request made by hand ignores the "identify on open" switch.
- No confirmation for the viewer's action; a confirmation for Check again on
  a dive.
- A fresh run reopens dismissed detections and marks them, rather than
  deleting them, so auto-apply can tell them apart for good.
- A claim on a photo is carried by box overlap alone.
- Locked, "+N" opens a read-only list.
- The scrub bar tint shows only while a scan is incomplete.
- The label mode is one preference shared by photos and videos.

## Left to the builder

- Names of the new widgets, functions and providers; where the one-line
  overflow widget lives.
- The toolbar icon, and how the priorities are renumbered to give the rank
  section 3 describes.
- How the one-line row measures what fits.
- How the photo layer gets the zoom, as long as labels keep their on-screen
  size and move with the page on a swipe.
- How label taps get past the page-level tap catcher, as long as a tap off a
  label behaves as it does today.
- Wording of the new strings, in the app's current marine life voice.
- The tint and ring colours, within the theme.
- How the pull request's screenshots are produced, within the project's
  rules for them.
- Tests: the label rules, the carry rules and the fresh-run rules as pure
  unit tests; the painter, both layers, the menu, the one-line row, the scrub
  bar tint and the dive card as widget tests.
