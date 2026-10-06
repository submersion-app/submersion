# Dashboard: replace the urgent banner with hardened gauge chips

Date: 2026-09-02

## Problem

The dashboard opens with `UrgentBanner`, a full-width `errorContainer` slab
pinned above every other card. With four overdue service clocks it occupies
roughly 350px before the diver sees their own greeting: a title, up to four
rows each floored at a 48px tap target around a `bodySmall` label, and a
chevron per row. It reads as a stack of full-width buttons in a red box.

It is also largely redundant. `GaugeStrip`, rendered a hundred pixels below,
already renders every due gear clock as a chip and uses the identical
localized string (`dashboard_gauges_gearOverdue`), so an overdue regulator
appears twice on first paint.

## Why it is not a pure duplicate

The two surfaces disagree about granularity, and that is the load-bearing
detail for this change.

- `UrgentBanner` reads `DashboardAlerts.serviceClocksDue`, which is **per
  item**.
- `GaugeStrip` reads `DashboardGauges.gearGauges`, built by `dueGearGauges`,
  which runs `worstGaugePerType` first and collapses to **one gauge per
  `EquipmentType`**.

A diver with four lapsed regulators therefore sees four banner lines but one
chip. Deleting the banner without changing the provider would silently drop
three overdue items. The provider has to un-collapse overdue gear before the
banner can go.

## Design

### 1. Overdue gear is listed per item

`dueGearGauges` returns a record instead of a bare list:

```dart
({List<GearGauge> gauges, int overdueOverflow}) dueGearGauges(
  List<EquipmentClocks> clocks, {
  int cap = 6,
  int overdueCap = 4,
});
```

- Overdue clocks are collected **per item** (each item contributing its own
  worst clock), sorted by due date with undated last.
- Due-soon clocks keep the existing `worstGaugePerType` collapse, which keeps
  the strip short in the common case where nothing is actually lapsed. An
  item that is overdue makes its whole type overdue, so that type produces no
  due-soon chip.
- Overdue chips claim slots from `cap` first; `overdueOverflow` reports how
  many overdue items did not fit and renders as a single `+N more overdue`
  chip routing to `/equipment`.

The overflow count travels on `DashboardGauges.gearOverdueOverflow` so the
widget has one source of truth for both the chips and the overflow, rather
than a second function recomputing the same cap.

### 2. Chips carry their severity to the render step

`GaugeStrip` currently appends `Widget` values straight into a `List<Widget>`,
discarding the `_Tone` that `_chip` was given. Nothing downstream can then
sort or filter by severity.

The strip instead collects `_ChipSpec` records:

```dart
typedef _ChipSpec = ({
  HomeChipType type,
  _Tone tone,
  IconData icon,
  String label,
  VoidCallback onTap,
  VoidCallback? onLongPress,
});
```

Specs are rendered through the unchanged `_chip` builder at the end, after an
index-tagged stable sort that moves `_Tone.alert` specs to the front and
leaves every other chip in today's source order.

### 3. Safety-relevant alerts ignore the hidden-chips setting

Three chip types are dive-safety facts rather than habit nags, and stay
visible even when the diver has hidden their type:

```dart
static const _hardened = {
  HomeChipType.gear,
  HomeChipType.insurance,
  HomeChipType.flightWindow,
};

bool _visible(_ChipSpec s, Set<String> hidden) =>
    (s.tone == _Tone.alert && _hardened.contains(s.type)) ||
    !hidden.contains(s.type.name);
```

Only those three blocks build their specs unconditionally. Every other block
keeps its existing `_shown` guard: none of them can produce an alert tone, so
none can be forced, and leaving the sync block guarded keeps its
`isSyncingProvider` watch out of the tree when the chip is hidden.

Last-dive currency and backup age can also reach `_Tone.alert`, and they stay
hideable on purpose. A diver who hid the "last dive 400d ago" chip made a
deliberate choice about a nag, not about a safety gate.

### 4. The strip itself cannot be hidden out of a live safety alert

`HomeCardType.gaugeStrip` is user-hideable, so hardening individual chips is
not enough on its own. `DashboardPage` forces `gaugeStrip` into `visibleCards`
when `dashboardGaugesProvider` reports overdue gear, expired insurance, or a
closed/conflicting flight window. This keys off the provider the strip already
reads, so there is no second source of truth for what counts as urgent.

This preserves the guarantee that made the banner pinned in the first place.

### 5. Removals

- `urgent_banner.dart` and `urgent_banner_test.dart`.
- The `showUrgent` computation and both `UrgentBanner` render sites in
  `dashboard_page.dart`; the all-cards-hidden branch collapses back to a bare
  `_AllCardsHiddenState`.
- `dashboardAlertsProvider` and `DashboardAlerts`, whose only remaining
  consumer was `showUrgent`, plus their tests.
- The stale "urgent banner is deliberately absent" comment in `home_cards.dart`.
- `dashboard_urgent_title` from all 11 ARB files.

### 6. Localization

One new key, translated in all 11 locales:

```json
"dashboard_gauges_gearOverdueMore": "+{count} more overdue"
```

## Testing

Provider (`gauge_providers_test.dart`):

- overdue items are listed individually rather than collapsed per type
- due-soon still collapses to the worst clock per type
- an overdue item suppresses the due-soon chip for its own type
- an item with several clocks contributes its worst clock once
- overdue chips are capped and the overflow count is reported
- overdue chips claim cap slots ahead of due-soon chips

Widget (`gauge_strip_test.dart`):

- alert-tone chips render before every other chip
- gear, insurance, and flight-window alert chips render while their type is in
  `hiddenHomeChips`
- a 400-day last-dive chip and a 45-day backup chip still hide when their type
  is hidden
- the `+N more overdue` chip renders and routes to `/equipment`

Page (`dashboard_page_test.dart`):

- `HeroHeader` is the topmost widget when alerts are live (replaces the three
  urgent-banner placement tests)
- the gauge strip renders when its card is hidden but a safety alert is live

## Result

The red slab is gone, the greeting is the first thing on the page, and four
overdue regulators become four red chips at the front of a strip that already
existed, instead of one chip plus a duplicated 350px banner.
