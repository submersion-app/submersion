# Marine life identification: release gate

What has to be true before `MARINE_LIFE_ID` is on for divers, and the
decisions taken on 2026-11-18 to get there. Refs #4668. It completes the
three conditions in the
[program overview](2026-11-17-marine-life-identification-program-design.md#the-pieces-in-order):
a cleared detector licence, measured bars (done), and the maintainer
satisfied with the results.

## Decided by the maintainer

1. **The first published pack carries both detectors** (the Community Fish
   Detector and FathomNet Megalodon), built as pack `2026.11.18.0356` was
   (`build_pack.py --detectors both`), with the bars measured for that set.
   It is the only set that clears the 70% floor in every group measured.
   This accepts two licence risks: the Community Fish Detector's weights
   carry no licence (its authors leave the terms to the user,
   filippovarini/community-fish-detector#8), and Ultralytics' AGPL claim on
   models trained with its code is unsettled for Megalodon, whose weights
   MBARI licenses CC BY 4.0. If either is ever challenged, a Megalodon-only
   pack replaces it; the app switches packs without an update.
2. **At launch the feature needs 8 GB of memory.** The iPhone and iPad
   memory floor (`minimumMemoryBytes`, now `MemoryFloor` in
   `MemoryReading.swift`) rises from 5 GiB to 6.5 GiB, so 8 GB devices
   pass and every 6 GB iPhone (the 12 Pro to the 15 Plus) shows the
   existing "not supported on this device" state. A device reports a little
   less than it is sold with, and a 6 GB device can never report more than
   6 GiB, so 6.5 GiB sits between the two with room on both sides. Macs
   have no floor. On the iPhone 17 Pro Max the app's
   limit was 3,376 MiB and identification peaked at 2,432 MiB with a 50 MP
   photo open; a 6 GB phone's limit is unmeasured. The floor comes back down
   to 5 GiB in a later release once the media memory fix has landed and a
   6 GB phone has been measured.

## Proposed (the maintainer's to correct)

3. **Credits say what is true.** The fish detector's entry in
   `DETECTOR_CREDITS` (`tool/species_pack/build_pack.py`), shown in the
   app's "Credits and licences", changes from "Redistribution awaiting the
   authors' permission" to "No licence stated; its authors leave the terms
   to the user", with the issue link. BioCLIP 2 stays MIT, as its authors
   ship it. The GBIF entry names what the pack uses: species names and
   counts of where each species has been recorded.
4. **On everywhere it can run, in one step** (the maintainer's call: "I
   just want to turn it on everywhere"). No beta stage, no private check
   first, and macOS goes with iOS. The flag's default becomes on for
   iPhone, iPad and Mac, the platforms with an engine. On the web, Android,
   Windows and Linux it stays hidden, since a setting that can only say
   "not available" helps no one; piece 3 turns those on. A build passing
   `--dart-define=MARINE_LIFE_ID=false` still turns it off everywhere.
5. **The pack is published before the flag change merges.** The measured
   pair pack's manifest is regenerated over its files so it carries the new
   credits (a rebuild fetches GBIF again and, if anything differs by a byte,
   falls back to provisional bars), checked for `"provisional": false`, then
   uploaded to a `species-pack` release. That makes the weights public,
   so it waited for the maintainer's go, given on 2026-11-18; the release
   is a pre-release, since the app's update check reads
   `releases/latest`. Merging the flag change before it would put a download
   that finds nothing in every beta built from main. The first release
   with the flag on carries App Review notes, on the iOS and the Mac App
   Store submissions alike, saying where the download is
   (Settings, Data, Photos and videos, Marine life identification) and that
   it is about 633 MB. The pair pack has not been run on an iPhone; on the
   Mac it adds about 130 MB at its peaks, which the 8 GB floor absorbs.
6. **The program overview's "Open risks"** records the pack chosen, the
   risks accepted and the 8 GB floor.

## Approaches considered for the pack

- **Megalodon only:** the only weights with a written licence from their
  owner, but it names 17% fewer fish (252 against 304 on the full list) and
  boxes crabs in 65% of photos, under the 70% floor on a thin sample of 26.
- **Both detectors (chosen):** best on fish and clears the floor
  everywhere; carries the fish detector's missing licence.
- **A fish detector trained on permissively licensed data:** the clean
  answer, left to "Training later"; a pack can swap it in.

## Not in this

- Training a detector, Android, Windows and Linux, auto-apply and review,
  live naming.
- The media memory fix (its own session and PR) and lowering the floor.
- The 1 GB of disk writes while installing a pack, and measuring turtles
  and marine mammals. Neither blocks release.

## Still open

- Nothing in this design. The flag goes on in whichever release follows the
  merge.
