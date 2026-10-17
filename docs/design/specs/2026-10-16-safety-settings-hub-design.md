# Safety settings hub: Decompression under Safety, one sub-page per section

Issue: #3395. Release: v1.8.3.

## Intent

Gradient factors, oxygen toxicity limits, narcosis and ICD warnings are safety
settings, but Settings shows Decompression and Safety as two separate top-level
entries. The Safety page itself is one long page mixing the safety review rules,
no-fly mode, two logbook sweeps and a link to Equipment condition. The goal is
one place for safety concerns, where each concern has its own page and the
entry point tells the diver what is currently set without opening anything.

## Goals

- Settings > Safety becomes a hub with three rows, each opening its own page:
  1. **Safety review**
  2. **Decompression**
  3. **Equipment condition**
- Each hub row's subtitle shows live state, not a fixed description.
- The top-level Decompression entry is removed.
- Old Decompression links keep working by redirecting to the new location.
- On desktop (master-detail layout) the sub-pages open inside the settings
  detail pane, with the settings list still visible on the left.

## Non-goals

- No change to what any setting does, its default, or how it is stored.
- No change to the contents of the Decompression page or the Equipment
  condition page beyond moving them.
- No new settings.

## Anti-goals

- A sub-page in the desktop pane must never show two stacked app bars.
- A deep link must never land on the generic `/settings/section/:id` wrapper
  for a page that has its own Scaffold.
- The Safety review sweeps (Analyze all dives, Dismiss all) must keep their
  existing lock and their existing cancel-on-leave semantics.

## The hub (Settings > Safety)

A `ListView` of three rows. Each row: leading icon, title, live subtitle,
trailing chevron, in the style of the Settings root list rows.

| Row | Icon | Subtitle when on | Subtitle when off |
| --- | --- | --- | --- |
| Safety review | `Icons.fact_check_outlined` (builder's call) | "On, 5 of 6 rules, no-fly Standard" | "Off, no-fly Standard" |
| Decompression | `Icons.timeline` (the icon the top-level entry used) | "GF 30/70" | n/a |
| Equipment condition | `Icons.build_circle_outlined` (as today) | "On, 4 of 5 rules" | "Off" |

- Safety review counts enabled rules as `SafetyRuleId.values` minus
  `safetyReviewDisabledRules`. The no-fly preset is shown in both states
  because no-fly applies whether or not the review runs. (My call, approved
  in chat as a guess.)
- Decompression shows gradient factors only: `gfLow`/`gfHigh`. (My call.)
- Equipment condition counts `ConditionRuleId.values` minus
  `conditionDisabledRules`, gated on `conditionEngineEnabled`.
- All strings are localized ARB entries with placeholders (counts as plural-
  safe ICU where the count drives grammar). New keys get English values;
  other locales follow the repo's normal translation flow.
- The hub has no sweep, so it has no busy lock.

The top-level Safety row subtitle changes from "Review rules & flying after
diving" to "Review rules, decompression & equipment" (wording is the
builder's call).

## Sub-pages

- **Safety review:** everything on today's `SafetySettingsPage` except the
  Equipment condition row: master toggle, rules, no-fly Standard/Strict,
  Analyze all dives, Dismiss all, with the existing `_busy` lock and progress
  UI unchanged. Title "Safety review".
- **Decompression:** the current `_DecompressionSectionContent` from
  `settings_page.dart`, moved into its own page file unchanged in content.
  Title "Decompression".
- **Equipment condition:** the existing `EquipmentConditionSettingsPage`,
  unchanged in content.

Moving Decompression out of `settings_page.dart` (4,103 lines) is part of
this work; its private helpers (CNS method picker, data-source segmented
controls, GTR reserve tile) move with it.

## Navigation

### Phone (and any width below the master-detail breakpoint)

| Route | Page |
| --- | --- |
| `/settings/safety` | hub |
| `/settings/safety/review` | Safety review |
| `/settings/safety/decompression` | Decompression |
| `/settings/safety/equipment-condition` | Equipment condition (existing) |

Hub rows `push` their route (push, not go, so system back returns to the hub;
see #647).

### Desktop (master-detail)

The URL drives the pane, consistent with how master-detail selection already
works through `goInPlace`:

- `/settings?selected=safety` shows the hub in the detail pane.
- `/settings?selected=safety&safetyPage=<review|decompression|equipment-condition>`
  shows that sub-page in the detail pane.
- Clicking a hub row on desktop does `goInPlace` to add `safetyPage`.
- Each sub-page shown in the pane has a back arrow that removes `safetyPage`
  (returning to the hub). Selecting Safety in the left list also shows the hub.
- An unknown `safetyPage` value shows the hub.
- Sub-pages are their own Scaffolds with AppBars; they are rendered directly in
  the pane (as the Safety page is today), never inside
  `SettingsSectionDetailPage`.

How a sub-page knows which back behaviour to use (pop on phone, drop the
parameter on desktop) is the builder's call; the hub decides by the same
breakpoint the settings page uses.

### Redirects for old links

| Old link | Goes to |
| --- | --- |
| `/settings/section/decompression` | `/settings/safety/decompression` |
| `/settings?selected=decompression` on phone | `/settings/safety/decompression` |
| `/settings?selected=decompression` on desktop | `/settings?selected=safety&safetyPage=decompression` |

`settingsSectionDedicatedRoutes` gains `'decompression': '/settings/safety/decompression'`
so both the list tile path and the `/settings/section/:id` redirect stay in
one table. The desktop rewrite of `selected=decompression` is a real URL
rewrite (`goInPlace`), not just a render-time mapping, so the left list
highlights Safety. (Builder-check call.)

On phone, `/settings?selected=safety` (with or without `safetyPage`) today
falls into the generic `SettingsSectionDetailPage` wrapper and would show two
app bars. It redirects to `/settings/safety` or `/settings/safety/<page>`
instead. This also covers a desktop window narrowed below the breakpoint while
a sub-page is open. (Builder-check call.)

The moved Decompression content is a bare scroll view today; its new page
wraps it in its own Scaffold and AppBar titled "Decompression".

## Sweeps and leaving a page

Leaving the Safety review page (back to the hub, or switching sub-page or
section on desktop) unmounts it and ends a running sweep, exactly as leaving
the Safety page does today: Analyze all is lossless and resumes next time;
Dismiss all keeps what it had already written. Equipment condition's rebuild
sweep already cancels on unmount the same way. No new behaviour here.

## Testing

- Hub: renders three rows; each subtitle reflects settings (on/off, rule counts,
  no-fly preset, GF values) and updates when settings change.
- Phone: each row pushes the right route; back returns to the hub.
- Desktop: each row swaps the pane content via `safetyPage`; the back arrow
  returns to the hub; the left list keeps Safety selected.
- Redirects: all three old-link cases.
- Settings root list no longer contains Decompression.
- Existing Safety, Decompression (CNS picker, ICD toggle), and Equipment
  condition tests keep passing after their harness locations are updated.

## Left to the builder

- File names and widget names for the hub and the two new pages.
- Exact icon for Safety review, and exact English wording of subtitles.
- How sub-pages choose their back behaviour on phone vs desktop.
- Whether the pane switch animates.
