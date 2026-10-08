# Data Quality Assistant

Dive data arrives from computers, files, and other apps, and it arrives
imperfect. A computer's clock was never set after a flight. A pressure sensor
dropped out for ninety seconds. The same dive got downloaded twice from two
different devices. A surface interval got logged as two dives instead of one.

The **Data Quality Assistant** finds these problems and offers to fix them. It
is a review inbox, not an autocorrect: it never changes your data on its own,
and every repair it offers is one you tap deliberately.

> [!TIP]
> <strong>Open it from the Dives list's overflow menu: Data quality review.</strong>
> The menu item carries a badge with the number of open findings, so you can
> ignore it completely until there is something to look at.

## How Findings Appear

Submersion checks dives in two ways:

- **Automatically, in the background**, whenever dives change: after an
  import (dive computer, file, or Apple Health), after you edit and save a dive,
  and after you combine, split, or consolidate dives. These targeted scans also
  look at neighbouring dives within 12 hours, because problems like duplicates
  and accidental splits are only visible in pairs.
- **On demand**, with **Scan library** (the radar icon in the inbox), which
  sweeps your whole logbook in batches with a progress bar you can cancel at any
  time.

There is no scan at app startup, and nothing runs while you are diving.

> [!TIP]
> <strong>Run <em>Scan library</em> once after importing a back catalogue.</strong>
> Automatic scans cover dives as they change; a full sweep is how you check
> everything that was already there. Dives that structurally cannot produce a
> finding are skipped, so the sweep is faster than the dive count suggests.

## Where Findings Show Up

| Surface | Shows |
|---------|-------|
| **Dives** overflow menu, **Data quality review** | The full inbox, with a badge count |
| The **Data quality** chip on the [Dashboard](dashboard.md) | The full inbox |
| The **Review** chip on a dive's detail page | That dive's findings only |
| **Review** on an import's summary | Just the dives from that import |

Each of these opens the same inbox, pre-filtered.

## What It Checks

Thirteen checks run over each dive. Each finding is **informational**, a
**warning**, or **critical**, and says exactly what it saw: "Depth spike to 47 m
at 12:31", not "profile problem".

### Time

| Check | Flags |
|-------|-------|
| **Clock & timezone** | A dive dated in the future, dated before 1950, a source clock offset by a whole number of hours (1 to 14, the classic unset-timezone signature), or a dive that overlaps another dive in time |

### Duplicates and splits

| Check | Flags |
|-------|-------|
| **Likely duplicate** | Two dives within 15 minutes of each other that match closely enough to be the same dive downloaded twice |
| **Accidental split** | The same computer resuming within about 10 minutes at shallow depth: one dive recorded as two |

### Profile

| Check | Flags |
|-------|-------|
| **Sample gaps** | Gaps of 30 s or more that are also well above the profile's own sampling interval |
| **Depth spike** | Depth changing faster than 3 m/s, negative depths, or a logged max depth that disagrees with the profile |
| **Impossible rate** | A vertical rate of 30 m/min or more sustained for at least 30 s |

### Temperature and pressure

| Check | Flags |
|-------|-------|
| **Temperature anomaly** | Water temperature outside &minus;2&nbsp;°C to 40&nbsp;°C, a jump of more than 5&nbsp;°C between adjacent samples, or values whose pattern indicates a unit conversion bug |
| **Pressure anomaly** | End pressure above start pressure, a tank record that disagrees with the sensor series by more than 10 bar, pressure rising mid-dive with no gas switch, or an implied surface consumption rate that is not physically plausible |

### Gas and cylinders

| Check | Flags |
|-------|-------|
| **Gas/MOD inconsistency** | ppO<sub>2</sub> reaching 1.6 bar (warning) or 1.8 bar (critical) and sustained, a hypoxic mix shown in use at the surface, or a gas switch deeper than that gas's MOD |
| **Wrong cylinder** | A cylinder losing most of its pressure while the gas timeline says it was not in use, or two cylinders carrying a near-identical pressure series |

### Multiple sources

| Check | Flags |
|-------|-------|
| **Conflicting sources** | Two computers on the same dive disagreeing on max depth, duration, or temperature. When depths differ by a consistent ratio, the finding also points out that a salt/fresh water setting difference would explain it |

### Gear and transmitters

| Check | Flags |
|-------|-------|
| **Shared gear on overlapping dives** | The same piece of gear on two divers' dives at overlapping times, when gear is shared between [diver profiles](diver-profile.md) |
| **Unassigned transmitter** | A dive with pressure from an air-integrated transmitter that is not assigned to any cylinder |

> [!NOTE]
> Thresholds are stored in metric and displayed in **your** unit settings, so a
> depth-spike finding reads in feet if that is how you log. The gas checks apply
> to open-circuit dives only.

## Working Through the Inbox

Findings are grouped under the dive they belong to and can be narrowed with the
filter chips along the top: **All**, **Time**, **Profile**, **Gas**, **Tanks**,
**Duplicates**, **Sources**.

Each card shows a severity icon, a plain-language description of what was found,
and can be expanded for detail. Every card offers up to three kinds of response:

1. **A repair**: one tap, described below.
2. **Go to dive**: open the dive and deal with it yourself.
3. **Dismiss**: you looked, and it is fine.

### Dismissing, and what rescans do

Dismissal is a decision the app remembers:

- A **dismissed** finding stays dismissed through every future scan.
- A finding whose underlying problem you **fixed** disappears on the next scan of
  that dive; you do not have to tidy up after yourself.
- A finding that comes back because the problem came back is **reopened**.

## Repairs

Where a fix is unambiguous and loses no information, the assistant offers to do
it for you. Where it would require judgment, it explains and gets out of the
way.

| Finding | Offered |
|---------|---------|
| Clock offset | **Shift time by** the detected offset, or **Shift all dives from this import** |
| Likely duplicate | **Consolidate** the pair into one dive, or **Delete duplicate** |
| Accidental split | **Combine into one dive** |
| Sample gaps | **Fill gaps** |
| Depth spike | **Remove spike**, **Clamp above-surface depths** for negative depths, or **Recalculate from profile** when only the stored max depth is wrong |
| Impossible rate | **Smooth impossible rates** |
| Temperature anomaly | **Smooth temperature**, or **Convert temperature** when a unit bug is the likely cause |
| Pressure anomaly | **Swap start/end pressure**, or **Use sensor values** for the tank record |
| Wrong cylinder | **Swap tank series** or **Move series to another tank** |
| Conflicting sources | **Make this source primary**, **Split into separate dives**, or **Compare profiles** |
| Shared gear on overlapping dives | **Remove from** one diver's dive |
| Unassigned transmitter | **Assign transmitter** to a cylinder |
| Gas/MOD | Navigation only; what to change is your call |

> [!TIP]
> <strong>Most repairs can be undone.</strong> Applying one shows a confirmation
> with an <strong>Undo</strong> action. Repairs that route through an existing
> dialog (consolidating duplicates, combining a split pair) use that dialog's own
> confirmation instead.

Profile repairs (despiking, gap filling, temperature smoothing) never destroy
what your computer recorded. They work like editing a profile by hand: each one
is saved as a new profile revision labelled **Data quality repair**, and the
original download is kept as its own revision you can switch back to (see
[Editing a profile](dive-profiles.md#editing-a-profile)).

## Choosing Which Checks Run

**Settings > Data > Data Tools > Data quality** lists all thirteen checks with a
switch each. Turning one off stops it running on future scans and
leaves the findings it already produced untouched.

Useful if a check does not match how you dive: a gauge-mode diver with no gas
timeline, or a rebreather diver who does not want open-circuit gas checks.

## Findings Across Your Devices

Findings, and your dismissals of them, sync with the rest of your logbook. The
identity of a finding is derived from the dive and the check that produced it,
so two devices scanning the same library independently arrive at the same
findings rather than two copies of each. Dismiss something on your phone and it
is dismissed on your Mac.

## "New quality checks are available"

Each check records which version of itself produced a finding. When a Submersion
update improves a check, the inbox shows a banner offering a **Rescan** so your
findings reflect the current rules rather than an older release's. Nothing
rescans without you asking.

## What It Will Not Do

- **It will not change data behind your back.** Every write is a repair you
  tapped.
- **It will not grade your diving.** These are data problems (a broken clock, a
  dropped sensor), not judgments about the dive. For observations
  about how a dive was conducted, see [Safety](safety.md).
- **It cannot check what it cannot see.** Profile-based checks need a recorded
  profile; a manually entered dive with a depth and a duration has almost nothing
  to check.
- **It will not catch everything.** A dive computer that logs a plausible wrong
  number leaves no trace to detect.

## See also

- [Import & Export](import-export.md): where most flagged data comes from
- [Dive Computers](dive-computer.md): downloading dives, and multiple computers on one dive
- [Dive Profiles & Deco](dive-profiles.md): profile editing and restoring the original
- [Safety](safety.md): the post-dive safety review, which observes the dive rather than the data
- [Settings](settings.md): units, and the full settings reference
