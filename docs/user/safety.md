# Safety

Submersion's safety suite is four independent tools that pick up where the dive
itself leaves off:

| Tool | Answers |
|------|---------|
| **[Post-dive safety review](#post-dive-safety-review)** | What happened on that profile that is worth noticing? |
| **[Flying after diving](#flying-after-diving)** | When is it safe to get on a plane? |
| **[Emergency card](#emergency-card)** | Who do I call, right now, with no signal? |
| **[Near-miss log](#near-miss-log)** | What almost went wrong, and what would help next time? |

They share one design rule: observe, don't scold. Findings are worded
neutrally, drawn in the same colours as the rest of the app rather than alarm
red, and every one of them can be dismissed. Nothing here grades you, and
nothing is sent anywhere.

> [!WARNING]
> **None of this is medical or decompression advice.** The review describes a
> dive you have already done, and the no-fly countdown reproduces published
> guideline intervals, not a physiological model of your body. Your dive
> computer, your training, and a diving physician outrank all of it.

---

## Post-Dive Safety Review

When a dive has a recorded depth profile, Submersion replays it through the same
Bühlmann engine used elsewhere in the app and notes anything the rules flag. The
result is a short, quiet list on the dive, not a score.

### What it looks at

| Rule | Flags | Severity |
|------|-------|----------|
| **Rapid ascents** | An ascent faster than 9 m/min, over a rise of at least 3 m | Caution, or significant above 12 m/min |
| **Missed or shortened deco stops** | Shallower than the required ceiling while under a decompression obligation | Significant |
| **Omitted safety stops** | The recommended stop skipped or cut short on a no-deco dive deeper than 10 m | Caution deeper than 25 m, otherwise informational |
| **Sawtooth profiles** | Four or more repeated up-and-down depth changes of at least 6 m | Caution |
| **High surfacing gradient factor** | Surfacing above your configured GF high | Informational |
| **Late gas switch** | A deco gas switched to later than it could have been, or not at all | Significant when it added 5 minutes or more of deco, caution when it added any, otherwise informational |

Each finding records when in the dive it happened and by how much, so the list
reads like "Ascent exceeded 11 m/min for 40 s" rather than a bare label. Short
blips are filtered out as sample noise, and shortfalls are measured against a
small tolerance, so ordinary depth wobble does not produce findings.

> [!TIP]
> **The thresholds are fixed on purpose.** The rapid-ascent rule always uses 9
> and 12 m/min. If findings followed a preference, changing it would silently
> rewrite the history of dives you had already reviewed.

### Where findings appear

- **On the dive:** a **Safety review** section in the dive's details, listing
  each observation with its time range and value. **Details** highlights it on
  the profile.
- **In the dive list:** a small dot beside dives that have observations.
  Hovering (or a long press) shows the count. Dives with nothing to report have
  no mark.

### Dismissing

Any finding can be dismissed with **Dismiss**, which is useful when you know the
context: a free-flow ascent you had to make, or a sawtooth profile that was the
point of the dive. **Dismiss all** clears a whole dive. Dismissed findings are
hidden behind **Show N dismissed** and can be brought back with **Restore**.
Dismissals sync to your other devices along with everything else.

### Settings

**Settings > Safety** controls the review:

- **Post-dive safety review:** the master switch.
- **Rules:** turn individual rules on or off. Turning a rule back on immediately
  shows the findings it already produced; nothing has to be analysed again.
- **Analyze all dives:** analyses every dive with a profile that has not been
  reviewed yet, with a progress count. Dives already analysed are skipped. If a
  dive cannot be analysed (a damaged profile, for instance), the sweep carries on
  and reports how many were skipped.
- **Dismiss all observations:** marks every observation from the rules you have
  switched on as reviewed. Observations from rules you have switched off are
  left alone, and show again if you switch the rule back on. You can restore
  dismissed observations one dive at a time.

> [!TIP]
> **Reviews are computed on first view.** You do not have to run anything:
> opening a dive analyses it if needed and stores the result. Use **Analyze all
> dives** when you want the whole logbook done at once, for example right after
> importing years of dives.

### Honest re-grading

Each stored review records the version of the rules that produced it. When the
rules or thresholds change in a later release, older reviews are recomputed the
next time you look at them, so what you see always reflects the current rules.

### Dives without a profile

The review needs a recorded profile: it analyses a depth-over-time series, not
your logged maximum depth and duration. Dives entered by hand with no profile
have no review section.

> [!NOTE]
> **Altitude:** if a dive site records an altitude but the dive itself does not,
> the dive's details show a note that the decompression analysis assumed sea
> level. Set the dive's altitude so the analysis, and so the review, accounts for
> it.

---

## Flying After Diving

Submersion counts down a **no-fly** time from your most recent dives, using the
published DAN/UHMS guideline intervals.

### The intervals

Your last 48 hours of dives are classified into one of three cases, and the
matching interval is counted from the end of the most recent dive:

| Your last dives | Standard | Strict |
|-----------------|----------|--------|
| A single no-decompression dive | 12 h | 18 h |
| Repetitive dives | 18 h | 24 h |
| Any dive with a decompression obligation | 24 h | 48 h |

Choose **Standard (12/18/24 h)** or **Strict (18/24/48 h)** under **Flying
after diving** in **Settings > Safety**. Strict is the more conservative reading
of the same guidance, sensible if you are older, dehydrated, cold, tired, or
simply prefer margin.

### Where it appears

- **Planning > Flying after diving:** the full readout, with the time remaining,
  the clock time you are clear, which case applied, and the guideline behind
  it. The countdown ticks while the page is open.
- **The Dashboard:** the **No-fly** chip shows the time remaining, or
  "No-fly 0:00" when you are clear. See [The Dashboard](dashboard.md).

> [!WARNING]
> **This is a guideline clock, not a tissue model.** Submersion deliberately does
> not compute flying times from the decompression engine, because no diving
> medical body endorses model-derived flying times. It is also not a substitute
> for the no-fly time your dive computer shows: if the two disagree, take the
> longer one.

---

## Emergency Card

A single screen with what you would need in an emergency, built entirely from
data already on your device. No network, no location permission and no sign-in:
it works on a boat with no signal, which is the condition that matters.

Open it with **Emergency card** in the Dashboard's quick actions, or from
**Settings > Diver Profile > Emergency card**.

### What it shows

1. **Who to call first.** When your insurance details include a
   **24h Emergency Assistance Number**, the card leads with your insurer's line, because the insurer
   authorizes the evacuation and coordinates the chamber. The regional diver
   emergency hotline follows. Without an insurer number, the hotline comes first.
   Each is a one-tap call.
2. **Local emergency services** for the same region.
3. **Your details:** blood type, allergies and medications from your diver
   profile, your emergency contacts, and your dive insurance policy.
4. **Nearest chambers**, nearest first, each with its contact details and the
   date they were last verified. **View all** (with the number of chambers) lists the whole directory.

### How your region is chosen

The card uses the country of your most recent dive's site. When that is not
known, it uses the worldwide hotline and says so.

### Chambers

Submersion ships a chamber directory with the app, so it is available offline
from the first launch. On top of that you can:

- **Add chamber** for one you know about locally.
- Hide a bundled entry that is wrong or no longer operating (with an undo).

> [!WARNING]
> **Verify before you rely on it.** Chamber availability changes: facilities
> close, staffing varies, and a chamber listed as operating may not be able to
> take you. Every entry carries a verified date so you can see how fresh it is.
> Always call the diver emergency hotline first; they know which chamber is
> accepting patients tonight.

> [!TIP]
> Fill in your medical details, emergency contacts and insurance under
> **Settings > Diver Profile** (see [Diver Profile](diver-profile.md)). The card
> tells you when there is nothing to show, and the day you need it is not the
> day to find it empty.

---

## Near-Miss Log

A private log for the dives where something almost went wrong. Aviation has had
non-punitive incident reporting for decades, and it works for the same reason it
would work here: patterns only become visible if the small things get written
down.

Open it from **Settings > Manage > Near-miss log**, or choose **Log near-miss**
from a dive's menu to link the report to that dive.

### What a report holds

| Field | Notes |
|-------|-------|
| **When it happened** | Defaults to today; a near-miss need not be tied to a logged dive |
| **Category** | Buoyancy, gas supply, equipment, buddy separation, marine life, boat or surface, medical, planning, or other |
| **Severity** | Minor, moderate or serious: your own judgment |
| **Equipment involved** | Optional: an item of gear, from the dive's gear or from all your gear |
| **What happened** | The narrative: just the facts, in your own words |
| **What contributed (optional)** | Conditions, fatigue, time pressure, an unfamiliar rig |
| **What would help next time (optional)** | The part that actually changes behaviour |

Reports linked to a dive show as a quiet chip on that dive's details. If you
later delete the dive, the report survives and only loses the link: deleting a
dive should never destroy the lesson. A report that names an item of gear also
feeds that item's condition findings (see [Equipment](equipment.md)).

> [!TIP]
> **Privacy is the point.** Near-miss reports sync between your own devices and
> are included in your backups, but they are never included in exports or shared
> logbook pages. A log you might have to show someone is a log you will not
> write honestly.

---

## Where Everything Lives

| Feature | Where |
|---------|-------|
| Safety review settings, rules, analysing every dive | Settings > Safety |
| No-fly guideline choice | Settings > Safety > Flying after diving |
| No-fly countdown | Planning > Flying after diving, and the Dashboard's No-fly chip |
| Findings for one dive | The dive's details > Safety review |
| Emergency card | The Dashboard's quick actions, or Settings > Diver Profile > Emergency card |
| Medical details, contacts, insurance | Settings > Diver Profile |
| Near-miss log | Settings > Manage > Near-miss log, or a dive's menu |

## What the Suite Does Not Do

- **It is not real-time.** Nothing here runs during a dive. Your computer is the
  instrument you dive; this is what you look at afterwards.
- **It does not judge.** There is no safety score, no streak, no comparison with
  other divers, and nothing leaves your devices.
- **It does not replace training.** A rule can tell you an ascent was fast; only
  training and honest reflection tell you why it happened.

## See also

- [Dive Profiles & Deco](dive-profiles.md): the gradient factors and profile analysis the review builds on
- [Planning & Calculators](planning.md): where the no-fly countdown lives
- [Diver Profile & Multi-Diver](diver-profile.md): medical details, contacts and insurance
- [Settings](settings.md): the full settings reference
- [Glossary](glossary.md): gradient factors, ceilings, and other terms used above
