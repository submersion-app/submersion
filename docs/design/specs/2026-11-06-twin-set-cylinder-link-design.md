# Twin set cylinder link (issue #4242)

Status: draft for approval, 2026-11-06. Release v1.8.4.

## Intent

A diver who dives manifolded doubles owns single cylinders that are paired into
twin sets and re-paired over time: a cylinder fails a hydro, a replacement
arrives, a cylinder moves to another set. Each cylinder is a real object with
its own spec, production date, inspection and hydro dates, service clocks and
passport tag. That already works.

What does not work is filling. A fill goes through a manifold, so both
cylinders get the same gas at the same pressure at the same moment, yet a fill
is saved against one passport. Today the diver scans two tags and types the
same fill twice. A third tag for the pair is rejected (one more thing to stick
on and keep in sync), and so is a third "twin set" equipment item (one more
object to rebuild every time a pair changes).

So the link is a light, dated relationship between two cylinders, not a new
object. It gives three things:

1. **Fill once.** One entry saves the same fill on both cylinders; each
   cylinder's own history stays complete.
2. **Pick once.** Choosing a linked cylinder for a dive can give one Twin Set
   tank with the combined volume.
3. **Swap easily.** Re-pairing is quick, and it never moves, copies or deletes
   past fills or rewrites past dives.

## Goals

- Link two cylinders as a twin set from either cylinder's equipment page; the
  link shows on both.
- Keep a pairing history on each cylinder (partner and date range).
- Record one fill for both cylinders, with a one-cylinder option.
- Edit fills (new for every manual fill, twin or not) and keep a twin fill's
  two rows consistent on edit and delete when the diver wants that.
- Pick a linked cylinder for a dive as the pair or as the single cylinder.

## Non-goals

- A twin set equipment item, a third tag, or a tag for the pair.
- Changes to trip cylinder lists, trip fills, the dive planner, UDDF export or
  the foreign passport page.
- Copying imported fills (tag, QR, NFC, CSV, station link, trip mirror) to the
  partner. They describe one tag's record; copying would invent a fill.
- Editing fills that came from a signed record or an import.

## Anti-goals (failure even if it works)

- The link changes history: a past dive's tank, a fill appearing on a cylinder
  that was not filled, or a fill lost when a pair is swapped.
- A cylinder shown with two current partners.
- One cylinder of a twin fill silently left with a value the diver corrected
  on the other.

## Success

A diver with two doubles goes through a season of fills, swaps one cylinder
after a failed test, and never types a fill twice or edits an old dive.

## Decided with the user

### The link and its history

- Stored as **dated pairings**, not a bare partner field: each pairing names
  two cylinders, a start date and an end date (open while current). A cylinder
  has at most one open pairing. Pairing history ships in this feature.
- Each cylinder's equipment page (tanks only) gets a **Twin set** card.
  - Unlinked: says so and offers "Link to a twin set partner".
  - Linked: names the partner (tappable to its page) and offers **Replace
    partner** and **Unlink**. The same pairing shows on the partner's page.
  - History: past pairings on that cylinder, newest first, partner name and
    date range.
- The partner picker lists the diver's other cylinders. Cylinders that are
  retired, sold or lost are left out; spares are offered (a spare is what gets
  swapped in after a failed test).
- Linking to a cylinder that already has a partner asks rather than refuses,
  naming what ends: "Double 12 B is paired with Double 12 C. Pair it with
  Double 12 A instead? Double 12 C will be left on its own." If both cylinders
  have partners, the message names both pairings that end.
- The pairing start date defaults to today and can be changed (to backdate a
  pair owned for years). Unlinking asks for an end date the same way. Replacing
  a partner ends the old pairing on the new pairing's start date.
- A pairing made by mistake can be deleted from the history. Ending is the
  normal path; deleting is for errors.
- Retiring or selling a cylinder does not end its pairing; the partner's card
  shows the status so the diver can unlink or replace.
- Deleting a cylinder removes its pairings, as deleting gear removes its other
  links today. Fills already recorded on the partner stay.
- The link syncs across devices like the rest of the diver's gear.
- Nothing in linking touches fills or dives.

### Which pairing counts: the one in effect on the date

- The fill switch and the dive prompt use **the pairing in effect on the
  fill's date or the dive's date**, not today's pairing. A fill dated before a
  swap goes to the partner of that time; an old dive offers the pair it was
  dived with.
- The switch names the partner for the fill sheet's current date and follows
  the date as the diver changes it. With no pairing on that date, there is no
  switch. The dive prompt does the same with the dive's date.
- Pairings count **whole calendar days** (the diver's local dates). A pairing
  covers its start day through the day before its end day; on a swap day the
  new pairing counts, so replacing a partner ends the old pairing on the new
  pairing's start day.
- Pairings of one cylinder never overlap. A start or end date that would
  overlap another pairing of either cylinder is refused, with a message naming
  the clash. Replacing a partner is the one path that ends the clashing open
  pairing instead of refusing, as described above.

### Fills

- On a linked cylinder, the existing Log a fill sheet gets a switch: **"Both
  cylinders in the twin set (<partner name>)"**, on by default. Off records
  this cylinder only (a top-up with the isolator closed). This covers every way
  into the sheet: a tag scan (it opens the passport page), the passport page's
  Log a fill button, and the blender's log-this-fill step.
- Saving writes **two fill rows**, one per cylinder, with the same gas,
  pressure, temperature, date, analyzer, station and notes, in one transaction.
- If the partner has never had a passport id, it gets one on the spot, the way
  opening its passport page does.
- After saving, the app offers to write the fill to this cylinder's tag (as
  today), then offers the partner's tag. Either can be skipped.
- **Safety warnings (warn, never block):**
  - Linking two cylinders whose working pressures differ warns that the pair
    fills to one pressure.
  - A twin fill whose pressure is above either cylinder's working pressure
    warns before saving. It still saves: the log records what happened.
- **Tie between the two rows:** both rows of a twin fill carry the same
  "filled together" marker. It lives on the fills, not on the pairing, so
  unlinking or swapping later does not affect it. Each tied fill in the history
  shows "Filled with <partner name>".
- **Delete** of a tied fill asks "Delete from both cylinders, or only this
  one?", default both. If the other row is already gone, nothing is asked.

### Fill editing (new)

- Tapping a manual fill in the fill history opens the fill sheet in edit mode,
  prefilled. The twin switch does not appear in edit mode.
- Saving a tied fill asks "Apply to <partner name>'s fill too?", default Yes.
  If the other row is gone, nothing is asked.

### Dives

- Picking a linked cylinder in a dive's tank editor ("My cylinders", the
  cylinder dropdown, or a tag scan) **asks**: "Twin set (A + B, 24 L) or just
  A?".
  - **Twin set:** the tank gets role Twin Set, volume A + B, the lower of the
    two working pressures, material and gas from the newest fill of the
    cylinder picked (a computer-recorded gas is still kept, as today). The tank
    names both cylinders. Both join the dive's gear list.
  - **Just A:** exactly today's behaviour.
- The tank names both cylinders so each passport page's "Used on dives" counts
  the dive. Today a tank names one passport; it gains one more field for the
  partner.
- Past dives keep what they were logged with. A swap or unlink never rewrites
  them.

## Builder's calls (made in conversation, open to correction)

- Only fills with source `manual` and no signed record are editable. Signed and
  imported fills show no edit action (their values are the record).
- Fills copied from a trip fill are stored as `manual` but are not editable:
  the copy is rewritten whenever its trip fill is saved, so an edit would be
  lost. Their delete works as today. The builder picks how a trip copy is
  recognised (a marker or the derived id).
- **Shared gear (#2046):** a pairing is a fact about the two physical
  cylinders, not per diver profile. Every profile that can see either cylinder
  sees it. Anyone who can edit a cylinder can link, unlink, replace or delete
  its pairings, as with editing its specs. The partner picker offers cylinders
  the active diver owns or that are shared with them. A twin fill writes the
  partner's row the way a fill on that cylinder is written today.
- **Partner not in use:** when the partner's status is retired, sold, lost,
  loaned out or in service, the fill switch defaults to off and its label shows
  the status ("Double 12 B, sold"); the dive prompt notes the status too. The
  diver can still choose the pair.
- The passport page shows a short "Twin set with <partner>" line under its
  header, linking to the partner, so a scan lands somewhere that shows the
  pair.
- Schema: one new rung that adds
  - a synced `cylinder_pairings` table (two cylinder ids, paired-at, nullable
    unpaired-at, diver id, timestamps, hlc; both cylinder FKs cascade on
    equipment delete),
  - a nullable "filled together" group id on `cylinder_fills`,
  - a nullable partner passport id on `dive_tanks`, read by the usage query.
- Choosing the lower working pressure for the twin tank: the pair cannot hold
  more than its weaker cylinder.

## Left to the builder

- Table, column and class names; canonical ordering of the two cylinder ids.
- How concurrent links from two devices that leave a cylinder with two open
  pairings are resolved, as long as no screen ever shows two current partners
  and the result is deterministic on every device.
- How the twin fill's two rows are built (repository method shape, ids).
- Sync, change log, diver ownership and deletion registration for the new
  table, following the existing checklist and guard tests.
- Volume arithmetic in cubic feet: combine in liters, then convert, as the tank
  editor already does.
- Widget layout within the existing card and sheet patterns; every unit shown
  follows the diver's unit settings; every new string is localized.
