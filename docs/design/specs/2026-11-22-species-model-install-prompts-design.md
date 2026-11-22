# Species model install prompts: setup wizard step and Home banner

Release: v1.8.5. Builds on issue #4773 (the in-context download offers).

## Intent

A diver whose device can run species identification usually never learns the
feature exists. The model is a separate download (about 633 MB), and today the
only offers of it are passive: since #4773 they sit on a dive's Species card
(dives with photos or videos), in the photo and video viewer's species sheet,
and on the Species page. A diver who never opens those places never hears
about it, and the app has no "what's new" surface to tell someone who
upgrades.

The goal is that every eligible diver hears about the model at least once,
at a moment where it makes sense to them:

1. **At setup:** the first-run wizard offers the download on eligible devices.
2. **In normal use:** Home shows a banner offering it, once the log has photos
   or videos for it to work on.

## Goals

- An eligible diver meets the offer during setup and can start the download
  there, with the size and a Wi-Fi note shown before they commit.
- An eligible diver who skipped setup's offer, set up before v1.8.5, or came
  in through restore or open-folder (which have no set-up steps) meets the
  offer on Home once their log has photos or videos.
- One rule decides who is offered it everywhere: the facts behind the
  existing `speciesDownloadPromptProvider` (feature on,
  `VisionAvailability.available`, no pack installed, offer not dismissed).
  Home uses the provider itself; the wizard reads the same facts once (see
  below).

## Non-goals

- No change to the download itself (resume, install, Core ML compile, the
  Windows ML fetch). The wizard and banner drive the existing
  `SpeciesPackController`.
- No change to the three #4773 offers or the Settings > Species identification
  page.
- No change to the Settings "Set up this device" card or its step count.
- No new "what's new" or release-notes surface.

## Anti-goals

- Never shown on a device that cannot run the model (under the 8 GB floor,
  no engine, a browser). A diver must never be offered a download that ends
  in "not supported on this device".
- Never a modal or a dialog that interrupts launch or blocks Home.
- No nagging: one dismissal on Home ends every species download offer on
  this device, as #4773's dismiss already does.
- The banner never shows to a diver with no photos or videos in their log;
  the feature has nothing to work on for them.

## Approaches considered

For the wizard there was one sensible shape: a step of its own, after the
Photos step. A checkbox on Finish would hide the size and the Wi-Fi note,
which a 633 MB download must state before the diver commits.

For normal use, three were considered:

| Approach | Trade-off |
| --- | --- |
| A. Home banner, shown once the log has photos or videos | Reaches upgraders, wizard skippers and restored logbooks; visible without interrupting; quiet for divers with no photos. **Chosen.** |
| B. Chip in Home's status-lights row | Fits the dashboard's look, but a small chip is easy to read past, which is the problem being solved. |
| C. One-time dialog on the first launch of v1.8.5 | Unmissable, but interrupts whatever the diver opened the app for, and the app uses no such pattern elsewhere. |

Eric picked the wizard step as sketched and approach A.

## Design

### 1. Setup wizard: Species identification step

**Where it sits.** A new wizard step, `SetupStepId.speciesModel`, placed right
after the four Set up this device steps and before Finish, on every path that
has those steps:

- first run, fresh path (not when the diver chose Skip on the welcome fork,
  which jumps straight to Profile and Finish);
- first run, existing data via cloud sync;
- the wizard run again from Settings (`SetupWizardMode.settings`).

Restore and open-folder have no set-up steps, so they get no species step;
the Home banner covers them.

It is a wizard step only, not a fifth step of the shared Set up this device
flow: `SetUpStep`, the Settings card's progress and its "n of 4" count stay
as they are. (Our call: the card's count assumes the same steps on every
device, and this step exists only on some.)

**When it is in the step list.** When there is an offer to make, by the same
facts the #4773 offers use, read once: `marineLifeIdEnabled`,
`visionAvailabilityProvider` resolves to `VisionAvailability.available`,
`installedSpeciesPackProvider` resolves to no pack, and the
`speciesIdDownloadPromptDismissed` preference is false. On a first run the
last two always hold; on a run from Settings they leave the step out for a
diver who has the model, dismissed the offer, or removed the model (removal
sets the dismissed flag, issue #4773). The controller's state is not part of
this rule.

`computeSteps` stays a pure function of the draft, so the draft carries the
answer (for example a `speciesModelOffered` flag). The flag is set once, when
those reads resolve, and never recomputed for the rest of the wizard:
tapping Download turns `speciesDownloadPromptProvider` off, and a live flag
would pull the step out of the list behind the diver and shift the indexes
Back navigates by. Until the reads resolve the step is left out; it can be
added only before the diver reaches Finish, never inserted behind them. A
browser never has it (`marineLifeIdEnabled` is false there).

**Progress indicator.** The step lights the same "Data" dot as the Set up this
device steps, so the indicator row keeps its width on a phone.

**What it shows**, by `SpeciesPackController` state (the step calls `refresh()`
when it opens):

| State | Body | Buttons |
| --- | --- | --- |
| `PackChecking` | Intro, spinner where the size goes | Skip, Download (disabled until known) |
| `PackNotInstalled` | Intro, "Download: <size>", and on iPhone/iPad/Android "Wi-Fi recommended"; when `downloadFetchesHardwareEngine()` is true, a new line saying the download also fetches Windows ML (the Settings confirmation has this only inside `settings_speciesId_downloadConfirmBodyHardware`, a full sentence with the size) | Skip, **Download** |
| `PackDownloading` / `PackInstalling` | Intro, progress line | Next |
| `PackInstalled` | "Installed" line | Next |
| `PackFailed` (offline, server error) | "Can't reach the download right now. You'll find it later in Settings > Data > Photos & videos > Species identification." | Next |
| `PackNotPublished`, `PackNotForThisDevice`, `PackNeedsAppUpdate`, `PackUnsupported` | Not reached in practice; if it is, the same "you'll find it later in Settings" line | Next |

Intro text: what it does (suggests the species in your dive photos and videos,
or "photos" alone where video scanning does not run, matching #4773's title
split) and that it runs on the device with nothing uploaded. Back goes to the
Photos step.

**Download** starts `SpeciesPackController.download()` without awaiting it
and moves to the next step at once. The step's size line is the confirmation;
no extra dialog. The controller is app-wide (not auto-disposed), so the
download carries on after Finish, and Settings > Species identification shows
its progress. A download cut off by quitting resumes from Settings, as today.

**Skip** moves on and records nothing. It does not dismiss the Home banner or
the #4773 offers: those appear in a later context (photos in the log), where
a diver who skipped at setup may now want it. (Our call; see "Calls made".)

### 2. Home: species model banner

**Where.** At the top of Home's scroll view, in the slot the demo-mode card
uses (below it when both show), above the panel grid. It is not a Home panel:
it cannot be reordered or hidden from the layout editor, and it does not
count toward the grid.

**What.** The existing `SpeciesDownloadPrompt(banner: true)`: fish icon, the
#4773 title ("Identify species in your photos and videos", or the photos-only
title), subtitle, tap opens Settings > Species identification, close button
dismisses. No new strings.

**When it shows.** All of:

- `speciesDownloadPromptProvider` is true (eligible, no pack, not dismissed,
  controller not downloading or ruled out);
- the library has at least one photo or video (any media row of type photo
  or video, whatever it is attached to, the count Set up this device's
  Photos step already uses: `MediaRepository.countPhotosAndVideos()`);
- demo mode is not active (`demoModeActiveProvider` is false). Demo mode
  shares the device's preferences and support directory with the real log,
  so a dismissal or download made from the sample logbook would carry into
  the diver's own setup.

The photo condition needs a cheap "has any photo or video" read; Home's
`recentMediaProvider` is watched only when the photo ribbon is shown, so it
cannot be relied on.

Home does not call `SpeciesPackController.refresh()`: the prompt provider
asks nothing of the network and counts `PackChecking` (the state at every
launch) as "offer it", exactly as the #4773 offers do. Eligibility itself
(`VisionAvailability.available`) is a local check, so the banner never shows
on a device that cannot run the model. The remaining gap, a device whose
engine has no published pack, exists only in builds with
`MARINE_LIFE_ID_ONNX` on before that pack is published, and the #4773 offers
share it.

**Dismissing.** The close button sets the existing per-device
`speciesIdDownloadPromptDismissed` preference, which already hides every
#4773 offer. One dismissal, every offer gone. Installing a model hides it too
(the provider already says so). Removing the model keeps every offer off:
Settings sets the dismissed flag on removal (issue #4773), and this design
leaves that as it is.

## Testing

- `computeSteps`: the species step appears after Photos and before Finish on
  the fresh, cloud-sync and settings paths when the draft says it is offered,
  and never on skip, restore, open-folder or a browser.
- The offer flag: set from the four facts, left out when a pack is installed
  or the offer was dismissed, and unchanged once set even when the controller
  moves to `PackDownloading`.
- Wizard widget test: the step's states from the table above, Download starts
  the controller (a fake) and advances without waiting, Back from Finish
  returns to the step after a download started, Skip advances and leaves the
  dismissed preference unset.
- Home widget test: the banner shows only when the prompt provider is true,
  the log has a photo or video, and demo mode is off; dismiss hides it and
  sets the preference.
- Screenshots: the wizard step (phone and desktop, light and dark) and Home
  with the banner (phone and desktop, light and dark), before and after.

## Left to the builder

- The draft field's name and how the wizard notifier learns availability.
- The exact query behind "has any photo or video" (an exists query on the
  media table is enough).
- Widget structure of the step, reusing `SetUpStepScaffold` if it fits.
- New l10n strings for the wizard step (title, intro, size line, Wi-Fi note,
  unavailable line), added to every ARB file the project keeps.

## Calls made (not asked)

- The wizard step is wizard-only, not a fifth Set up this device step.
- Skip at setup does not dismiss later offers.
- The step's size line counts as the download confirmation; no dialog.
- "Wi-Fi recommended" shows on phones and tablets only, as static text (no
  network-type check).
- The Home banner shares #4773's dismiss preference rather than having its own.
- The wizard step follows the #4773 offer rule (no pack, not dismissed), read
  once per wizard run, so a run from Settings skips it for a diver who has
  the model, dismissed the offer, or removed the model.
- Removing the model keeps the offers off, as today.
- Home shows the banner without a manifest check, as the #4773 offers do.
- No banner in demo mode.
