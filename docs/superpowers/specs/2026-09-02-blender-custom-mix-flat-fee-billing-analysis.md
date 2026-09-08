# Analysis: custom-mix billing line + per-gas flush flat fee

Reference: submersion-app/submersion#1335. Analysis only, no implementation.
Branched from `upstream/main` at `60998f4e6`, independent of the still-open
trimix-mixer follow-up (submersion-app/submersion#1359 /
`claude/issue-1359-followup-20260829`), which has not merged to `main` yet.

## 1. Current billing architecture

### The "individual amount" line today

`BlenderInvoiceCard` (`lib/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart`)
keeps a running bill as `List<BilledFill>` (`blenderBilledFillsProvider`).
Each `BilledFill` (`lib/features/gas_calculators/domain/blending/billed_fill.dart`)
is either:

- a **computed** fill: `lines` holds one `BilledGasLine` per gas actually
  blended (`gas` label, `addedBar`, `cost`), saved via
  `BlenderBillingCard._saveFill`, or
- a **manual** entry: `lines` is empty (`BilledFill.isManual`), `label` and
  `total` are free text/number, entered through `_LineEditDialog` in
  `blender_invoice_card.dart` — a plain `AlertDialog` with exactly two
  fields, description and amount. This dialog is the "individual amount"
  option the task refers to; it has no notion of a gas mix or a cylinder at
  all today.

`BilledFill`s are stored oldest-first and only ever appended
(`appendCapped`), capped at `kMaxBilledFills = 100`.

### Computed cost path

`BlenderBillingCard` (same folder) owns the cylinder-volume field (free
text, or a preset picked from `blenderTankChoices()`), a currency picker,
and one price field per **configured bank** (`blenderGasPricesProvider`,
`List<double?>` of length 3). Prices are positional against
`blenderFillGas1/2/3Provider`, not tied to a gas's identity — a diver who
reassigns bank 2 from helium to something else is pricing that bank, not
"helium" (see the `PR #1215` comment on `computeBlendCost` in
`blend_billing.dart`).

`computeBlendCost` only prices a `BlendResult` produced by `computeBlend()`
(`lib/features/gas_calculators/domain/gas_blender.dart`), which solves the
full partial-pressure fill procedure from a start mix/pressure to a target
mix/pressure through up to three banks. There is currently **no path** that
prices a mix without going through that solver — a manually typed mix has
no bank index to look its price up under.

## 2. What the two requested features need

### a) Custom mix on a manual bill line

Requested: cylinder selection (default value or manual litre entry, same as
the costing card) plus O2/He/Luft shares, attached to what is today the
plain "individual amount" entry.

- The cylinder picker is a straight lift of
  `BlenderBillingCard._cylinderRow` (text field seeded from
  `blenderCylinderLitersProvider`, plus a `PopupMenuButton` over
  `blenderTankChoices()`). No new logic needed there.
- The domain model everywhere else in the app (`GasMix`, `MixTemplate`,
  `mix_template_dialog.dart`'s `_numberField` row) is **O2 + He only**; Luft
  is always the derived balance (`GasMix.n2 = 100 - o2 - he`, `isAir` when
  `o2` is 20–22 and `he == 0`). A literal third "Luft %" field would add a
  degree of freedom the rest of the app does not have and would need its
  own `O2 + He + Luft == 100` validation. Recommend keeping the same
  two-field (O2/He) entry as everywhere else rather than introducing a
  third field.
- **Open question — how is the line priced?** `computeBlendCost` needs a
  solved `BlendResult` keyed to bank order; a hand-typed mix was never
  solved and has no bank index. Two ways to close that gap, both needing a
  product decision before implementation:
  1. Keep pricing manual (today's free-typed total), and use the entered
     mix only to build the label/record — closest to today's behaviour,
     smallest change.
  2. Compute a price directly from `cylinderLiters × targetPressure ×
     (fraction of each gas)` against the existing bank prices, without
     running `computeBlend` at all (a custom mix, by definition, was not
     blended by this fill station's three banks in sequence, so the
     solver's fill-order logic does not apply to it).

### b) Per-gas flush/purge flat fee

Requested: a flat fee per gas (O2, He, Luft), each with its own volume,
configured in settings, shown as a lump-sum line at the top of the invoice
(example: "O2, 20 L, 1.50 Fr.").

- This is **identity**-keyed ("O2", "He", "Luft"), not bank-positional like
  `gasPrices`. That is a real mismatch with the existing pricing model,
  where a bank's identity is whatever `GasMix` the diver configured it
  with. A flush fee tied to "the gas actually connected to fill from",
  rather than to bank position, needs its own small model
  (`{gas, volumeLiters, price}` × 3) rather than reusing `gasPrices`.
- `BilledGasLine` (the type computed fills are saved as) shows gas name +
  `addedBar` (pressure) + cost — it has no litres field rendered anywhere
  in `BlenderInvoiceCard._fillLine`. `GasCostLine.freeGasLiters` exists on
  the *live* costing side but is dropped when a fill is frozen into a
  `BilledGasLine` for storage. Showing "20 L" verbatim (as in the example)
  is simplest as its own free-text manual-style entry (label ==
  `"O2, 20 L"`, `total == price`) rather than extending `BilledGasLine`
  with an optional litres field used by only one caller.
- **Open question — once per invoice, or once per fill?** "Pauschalposition
  am Anfang der Rechnung" (singular, at the *start* of the bill) reads as
  once per gas per session, not once per cylinder — a hose only needs
  purging once when a gas source is connected, not on every fill drawn from
  it. But `blenderBilledFillsProvider`/`appendCapped` is an append-only,
  oldest-first list; nothing in it is "first" by construction. Two ways to
  reconcile that, needing a product decision:
  1. Treat the flush lines as ordinary `BilledFill` entries but *inserted*
     at index 0 instead of appended, with de-duplication so re-saving a fill
     does not add "O2, 20 L" a second time.
  2. Keep them entirely outside `blenderBilledFillsProvider`: render them
     live in `BlenderInvoiceCard.build()`, ahead of the `for (final f in
     fills)` loop, computed from settings × which gases were used this
     session — the same "derived, not stored" shape `blenderBillingProvider`
     already uses for the live cost preview. This sidesteps the
     insert-at-0/de-dup problem entirely and reads closer to "once per
     invoice" than option 1 does.

## 3. Popup vs. alternative for the richer manual-line form

Today's `_LineEditDialog` is a small, non-scrolling `AlertDialog` (two text
fields). Adding a cylinder row (text field + preset menu, ~56dp) and an
O2/He row roughly doubles its height, and `mix_template_dialog.dart` already
shows that even a much simpler two-field dialog caps its content at
`width: 320` to stay inside the app's narrowest supported phone — an
`AlertDialog` does not resize for the keyboard the way a scrollable sheet
does, so a taller fixed dialog risks overflow once the keyboard is up on a
short device (particularly landscape, or a phone with a large keyboard/
predictive-text bar).

The codebase's established pattern for a form richer than two or three
fields is a `showModalBottomSheet(isScrollControlled: true, ...)` wrapped in
a `SingleChildScrollView`/`Column` with
`Padding(bottom: MediaQuery.of(context).viewInsets.bottom + ...)` for the
keyboard — see `checklist_item_edit_sheet.dart` (`isScrollControlled: true`,
`viewInsets.bottom` padding) and the equivalent shape in
`dive_filter_sheet.dart`/`itinerary_day_edit_sheet.dart`. `TankEditor`
(`lib/features/dive_log/presentation/widgets/tank_editor.dart`) is the
closest existing analogue in complexity (preset + volume/material row + O2/
He row), though it lives inline on a page rather than in an overlay.

**Recommendation:** move the manual-line entry from `AlertDialog` to a
scrollable, `isScrollControlled` bottom sheet once the cylinder + mix
fields are added, following the `checklist_item_edit_sheet.dart` shape.
Open question for the product owner: whether to keep the plain
"amount only" path as today's compact `AlertDialog` and only grow into the
sheet when "enter a mix" is toggled on (two code paths, smaller change for
the common case), or unify on the sheet for both (one code path, but the
simple case loses its quick centered-dialog feel). No preference recorded
here — flagging both as viable pending a decision.

## 4. Where a flush-fee settings UI would live

`gasPrices`/currency/cylinder are currently edited inline inside
`BlenderBillingCard` on `main`, because the dedicated "Blender settings
page" (`blender_settings_page.dart`) that the trimix-mixer follow-up built
does not exist on `main` yet — it only exists on the unmerged
`claude/issue-1359-followup-20260829` branch. Adding three more
gas/volume/price rows for the flush fee would make `BlenderBillingCard`
noticeably more crowded if it lands before that settings page merges.
Worth flagging, not deciding here: this feature may read more naturally
once it can live in that dedicated settings page rather than growing the
billing card further — but that is a sequencing question for the two
efforts, not a blocker for building the feature on `main` now.

## 5. Files a future implementation phase would touch

- `lib/features/gas_calculators/domain/blending/billed_fill.dart` — line
  modelling for a mix-carrying manual entry and/or the flush-fee line shape.
- `lib/features/gas_calculators/domain/blending/blend_billing.dart` —
  possible direct-pricing path for a custom mix that bypasses
  `computeBlend`.
- `lib/features/gas_calculators/domain/blending/blender_preferences.dart` —
  new persisted field(s) for the per-gas flush fee (volume + price), plus
  `copyWith`/`toJson`/`fromJson`.
- `lib/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart` —
  the manual-line entry point (dialog → sheet, mix fields).
- `lib/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart` —
  cylinder-row logic to reuse; possible flush-fee settings fields.
- `lib/features/gas_calculators/presentation/providers/gas_blender_providers.dart` —
  persistence load/save wiring.
- New l10n keys in all locale `.arb` files for the new fields/labels.

No code, tests, or migrations were changed in this pass, per the task.
