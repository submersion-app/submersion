# Safety

Submersion's safety suite is four independent tools that pick up where the dive
itself leaves off:

| Tool | Answers |
|------|---------|
| **[Post-dive safety review](#post-dive-safety-review)** | What happened on that profile that is worth noticing? |
| **[Flying after diving](#flying-after-diving)** | When is it safe to get on a plane? |
| **[Emergency card](#emergency-card)** | Who do I call, right now, with no signal? |
| **[Near-miss log](#near-miss-log)** | What almost went wrong, and what would help next time? |

They share one design rule: **observe, don't scold.** Findings are worded
neutrally, drawn in the same colors as the rest of the app rather than alarm
red, and every one of them can be dismissed. Nothing here grades you, and
nothing is sent anywhere.

> [!WARNING]
> <strong>None of this is medical or decompression advice.</strong> The review
> describes a dive you have already done; the no-fly countdown reproduces
> published guideline intervals, not a physiological model of your body. Your
> dive computer, your training, and a diving physician outrank all of it.

---

## Post-Dive Safety Review

When a dive has a recorded depth profile, Submersion replays it through the same
Bühlmann engine used elsewhere in the app and notes anything the rules flag. The
result is a short, quiet list on the dive &mdash; not a score.

### What it looks at

| Rule | Flags | Severity |
|------|-------|----------|
| **Rapid ascents** | Ascent faster than 9 m/min (caution) or 12 m/min (significant) | Caution / Significant |
| **Missed or shortened deco stops** | Depth shallower than the required ceiling while under a decompression obligation | Significant |
| **Omitted safety stops** | The recommended stop was skipped or cut short on a non-deco dive deeper than 10 m | Caution over 25 m, otherwise informational |
| **Sawtooth profiles** | Three or more repeated up-and-down depth changes of at least 3 m | Caution |
| **High surfacing gradient factor** | Surfaced above your own configured GF-high | Informational |

Each finding records *when* in the dive it happened and *by how much*, so the
list reads like "Ascent exceeded 11 m/min for 40 s" rather than a bare label.
Short blips are filtered out as sample noise, and the shortfalls are measured
against a small tolerance, so ordinary depth wobble does not produce findings.

> [!TIP]
> <strong>The thresholds are fixed on purpose.</strong> The rapid-ascent rule uses
> 9 and 12 m/min regardless of the ascent-rate alarm you configured for the
> profile chart. If findings tracked your alarm settings, changing a preference
> would silently rewrite the history of dives you had already reviewed.

### Where findings appear

- **On the dive** &mdash; a **Safety review** section in dive detail, listing each
  observation with its time range and value.
- **In the dive list** &mdash; a small dot next to dives that have observations.
  Hovering (or a long press) shows the count. There is no badge on dives with
  nothing to report.

### Dismissing

Any finding can be **dismissed** &mdash; useful when you know the context (a
free-flow ascent you had to make, a sawtooth profile that was the point of the
dive). Dismissed findings are hidden behind a **Show dismissed** toggle and can
be restored at any time. Dismissals sync to your other devices along with
everything else.

### Settings

**Settings &rarr; Safety** controls the review:

- **Post-dive safety review** &mdash; the master switch.
- **Rules** &mdash; turn individual rules on or off. Visibility is applied when
  findings are *displayed*, so turning a rule back on immediately reveals the
  findings it already produced rather than requiring a re-analysis.
- **Analyze all dives** &mdash; sweeps your logbook and analyzes every dive with a
  profile that has not been reviewed yet, with a progress bar. Already-analyzed
  dives are skipped cheaply. If a dive cannot be analyzed (a corrupt profile,
  for instance), the sweep continues and reports how many were skipped.

> [!TIP]
> <strong>Reviews are computed on first view.</strong> You do not have to run
> anything: opening a dive analyzes it if needed and stores the result. Use
> <em>Analyze all dives</em> when you want the whole logbook done at once &mdash;
> for example right after importing years of dives.

### Honest re-grading

Each stored review records the version of the rules that produced it. When the
rules or thresholds change in a future release, older reviews are recomputed the
next time you look at them rather than being left to quietly disagree with the
current engine. What you see always reflects today's rules.

### Dives without a profile

The review needs a recorded profile &mdash; it is analysis of a depth-versus-time
series, not of your logged max depth and duration. Manually entered dives with
no profile simply have no review section.

> [!NOTE]
> **Altitude:** if a dive site records an altitude but the dive itself does not,
> dive detail shows a note explaining that the decompression analysis assumed sea
> level. Set the dive's altitude to have the analysis &mdash; and therefore the
> review &mdash; account for it.

---

## Flying After Diving

Submersion tracks a **no-fly countdown** from your most recent dives, using the
published DAN/UHMS guideline intervals.

### The intervals

Your last 48 hours of dives are classified into one of three cases, and the
matching interval is counted from the **end of the most recent dive**:

| Your last dives | Standard | Strict |
|-----------------|----------|--------|
| A single no-decompression dive | 12 h | 18 h |
| Repetitive dives | 18 h | 24 h |
| Any dive with a decompression obligation | 24 h | 48 h |

Choose between **Standard** and **Strict** in **Settings &rarr; Safety &rarr;
Flying after diving**. Strict is the more conservative reading of the same
guidance &mdash; sensible if you are older, dehydrated, cold, tired, or simply
prefer margin.

### Where it appears

- **Planning &rarr; Flying after diving** &mdash; the full readout: time remaining,
  the exact clock time you are clear, which case applied, and the guideline
  behind it. The countdown ticks while the page is open.
- **Dashboard** &mdash; an optional home chip showing either the remaining time or
  **No-fly 0:00** when you are clear. Toggle it under Home appearance settings.

> [!WARNING]
> <strong>This is a guideline clock, not a tissue model.</strong> Submersion
> deliberately does <em>not</em> compute no-fly time from the decompression engine,
> because no diving medical body endorses model-derived flying times. It is also
> not a substitute for the no-fly time your dive computer shows &mdash; if the two
> disagree, take the longer one.

---

## Emergency Card

A single screen with everything you would need in an emergency, built entirely
from data already on your device. **No network, no location permission, no
sign-in** &mdash; it works on a boat with no signal, which is the only condition
that matters.

Open it from the **dashboard quick actions** (*Emergency card*) or **Settings
&rarr; Diver Profile &rarr; Emergency card**.

### What it shows

1. **The diver emergency hotline for your region**, as a one-tap call. This is
   the primary action on purpose: the hotline coordinates evacuation and chamber
   referral, which is a decision you should not be making yourself.
2. **Local emergency services number** for the same region.
3. **Your medical summary** &mdash; blood type, allergies, medications &mdash; from
   your diver profile.
4. **Emergency contacts** and **dive insurance** policy details.
5. **Hyperbaric chambers**, nearest first, each with its contact details and the
   date its details were last verified.

### How your region is chosen

The card uses the country of your **most recent dive's site**. You can override
this in settings &mdash; useful the day before you travel. If neither is known,
it falls back to the worldwide hotline and says so.

### Chambers

Submersion bundles a starter chamber directory that ships with the app, so it is
available offline from first launch. On top of that you can:

- **Add a chamber** you know about locally.
- **Hide** a bundled entry that is wrong or no longer operating (with an undo).

> [!WARNING]
> <strong>Verify before you rely on it.</strong> Chamber availability changes
> constantly &mdash; facilities close, staffing varies, and a chamber listed as
> operating may not be able to take you. Every entry carries a "verified" date so
> you can see how fresh it is. Always call the diver emergency hotline first; they
> know which chamber is actually accepting patients tonight.

> [!TIP]
> Fill in your medical details, contacts and insurance under <strong>Settings
> &rarr; Diver Profile</strong>. The card tells you when there is nothing to show
> &mdash; and the day you need it is not the day to discover it is empty.

---

## Near-Miss Log

A private log for the dives where something *almost* went wrong. Aviation has
had non-punitive incident reporting for decades, and it works for the same
reason it would work here: patterns are only visible if the small things get
written down.

Open it from **Settings &rarr; Manage &rarr; Near-miss log**, or from a dive's
overflow menu (**Log near-miss**) to link the report to that dive.

### What a report holds

| Field | Notes |
|-------|-------|
| **When it happened** | Defaults to today; a near-miss need not be tied to a logged dive |
| **Category** | Buoyancy, gas supply, equipment, buddy separation, marine life, boat/surface, medical, planning, other |
| **Severity** | Minor, moderate, serious &mdash; your own judgment |
| **What happened** | The narrative. Just the facts, in your own words |
| **What contributed** | Optional &mdash; conditions, fatigue, time pressure, an unfamiliar rig |
| **What would help next time** | Optional &mdash; the part that actually changes behavior |

Reports linked to a dive show as a quiet chip on that dive's detail page. If you
later delete the dive, the report survives and simply loses the link &mdash;
deleting a dive should never destroy the lesson.

> [!TIP]
> <strong>Privacy is the point.</strong> Near-miss reports sync between your own
> devices and are included in your backups, but they are <strong>never</strong>
> included in exports or shared logbook pages. A log you might have to show
> someone is a log you will not write honestly.

---

## Where Everything Lives

| Feature | Path |
|---------|------|
| Safety review settings, rules, backfill | Settings &rarr; Safety |
| No-fly preset | Settings &rarr; Safety &rarr; Flying after diving |
| No-fly countdown | Planning &rarr; Flying after diving, plus an optional dashboard chip |
| Findings for one dive | Dive detail &rarr; Safety review |
| Emergency card | Dashboard quick actions, or Settings &rarr; Diver Profile &rarr; Emergency card |
| Medical details, contacts, insurance | Settings &rarr; Diver Profile |
| Near-miss log | Settings &rarr; Manage &rarr; Near-miss log, or a dive's overflow menu |

## What the Suite Does Not Do

- **It is not real-time.** Nothing here runs during a dive. Your computer is the
  instrument you dive; this is what you look at afterwards.
- **It does not judge.** There is no safety score, no streak, no comparison to
  other divers, and nothing leaves your devices.
- **It does not replace training.** A rule can tell you an ascent was fast; only
  training and honest reflection tell you why it happened.

## See also

- [Dive Profiles & Deco](dive-profiles.md) &mdash; the gradient factors and profile analysis the review builds on
- [Planning & Calculators](planning.md) &mdash; where the no-fly countdown lives
- [Diver Profile & Multi-Diver](diver-profile.md) &mdash; medical details, contacts and insurance
- [Settings](settings.md) &mdash; the full settings reference
- [Glossary](glossary.md) &mdash; gradient factors, ceilings, and other terms used above
