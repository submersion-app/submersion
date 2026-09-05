# Trimix Blender Invoice: Volume, Date, Tariff, Export/Pay (issue #1335) — Analysis

Date: 2026-09-02
Issue: [#1335](https://github.com/submersion-app/submersion/issues/1335)
Branch: `fix/issue-1335-abrechnung-erweiterung`

Analysis only. No code, migration, or UI changes in this phase.

## Scope

Four requests against the gas-blender "Kosten" (billing) and "Abgerechnet"
(invoice) cards:

1. Saving a fill should record/show the delivered **volume**, not the
   pressure.
2. The configured **gas tariff** (price per gas) should be visible at the
   top of the invoice, so it can be checked at a glance.
3. The "Abgerechnet" heading should become an editable **invoice date**
   ("Rechnung vom xy").
4. **Export** (PDF/Image/Excel) and **Pay** actions at the end of the
   section.

All four touch `lib/features/gas_calculators/presentation/widgets/blender/
blender_billing_card.dart` (the live "Kosten" card, where a fill is priced
and saved) and `blender_invoice_card.dart` (the "Abgerechnet" running bill),
plus the shared model in `lib/features/gas_calculators/domain/blending/
billed_fill.dart` and `blender_preferences.dart`.

## 1. Volume instead of pressure when a fill is saved

**Current state:**

- `blend_billing.dart::computeBlendCost()` already computes both figures per
  line: `GasCostLine.addedBar` (bar delivered) and `GasCostLine.freeGasLiters`
  (`waterLiters * addedBar`, the ideal free-gas volume — see the doc comment
  there on why pressure is deliberately the *commercial* truth for pricing).
- The live "Kosten" card (`blender_billing_card.dart::_costLine`) already
  shows **both** columns: `+X bar` and the litre figure
  (`units.formatVolume(line.freeGasLiters)`).
- `BilledFill`/`BilledGasLine` (`billed_fill.dart`), the structure that
  actually gets **persisted** when "Save fill" is pressed
  (`blender_billing_card.dart::_saveFill`), only carries `gas`, `addedBar`,
  `cost`. `freeGasLiters` is computed but dropped at save time.
- The invoice ("Abgerechnet") line (`blender_invoice_card.dart::_fillLine`)
  therefore can only show pressure
  (`units.formatPressure(line.addedBar, ...)`) — there is no volume to show
  even if it wanted to.

**Gap:** the volume is available at save time but never stored, so the
saved/invoiced fill line is pressure-only.

**Straightforward fix path (no migration needed):**

- Add `freeGasLiters` to `BilledGasLine` (`toJson`/`fromJson`, following the
  existing per-field-independent-fallback pattern already used there and in
  `BlenderPreferences`). Since this is a JSON blob in the `settings` KV
  table (see §3 of `blender_preferences.dart`), adding a field is a pure
  additive JSON change — no Drift schema version bump.
- `_saveFill` passes `freeGasLiters: line.freeGasLiters` through.
- `blender_invoice_card.dart::_fillLine` switches its display from
  `units.formatPressure(line.addedBar, decimals: decimals)` to
  `units.formatVolume(line.freeGasLiters)`.

**What should NOT change:** the pricing formula itself
(`cost = freeGasLiters / 100 * unitPricePer100`) stays pressure-driven
internally — `blend_billing.dart` explains this is intentional (a fill
station meters and charges by gauge pressure drop, so bar is the "commercial
truth" even though it is not the physical one). The request reads as
changing what is **shown/recorded on the saved line**, not the underlying
cost math. `addedBar` should probably stay in the persisted structure too
(cheap, and the existing "Kosten" card still wants to show pressure live) —
only the invoice display needs to switch to volume. This is a judgment call
worth confirming before implementation.

## 2. Gas tariff visible at the top of the invoice

**Current state:** the per-gas price (`gasCalculators_blender_unitPrice`,
price per 100 L/cu ft) is only entered/shown in the "Kosten" card
(`_priceField`, one field per configured bank, labelled with the gas name
via `formatPreciseGasName`). `blender_invoice_card.dart` shows fill labels
and totals but never the tariff that produced them — there is no way to
audit "was this billed at the current price" from the invoice section
alone.

**Data already available for this:** `blenderFillGas1/2/3Provider` (gas
identity per bank), `blenderGasPricesProvider` (`List<double?>`, positional
per bank), `blenderCurrencyProvider` — exactly what `_priceField` already
reads. A summary row/line such as "O₂ 1.20/100 L · He 4.50/100 L · Air
0.10/100 L" at the top of `BlenderInvoiceCard.build()` (before or beside the
"Billed to" field) can be assembled from the same three providers with
`formatPreciseGasName` + `formatMoney`/price formatting already used
elsewhere in this file's sibling.

**Caveat:** prices are **positional per bank**, not per gas identity (see
`blend_billing.dart` doc comment, and the earlier PR #1215 review note about
air being billed at helium's rate when this was conflated). A tariff summary
must therefore be built the same way `_priceField` builds its labels — by
zipping bank index to the *currently configured* fill gas for that bank —
not by grouping "all O2 lines" from historical invoice lines, which may have
been filled from a bank that has since been reconfigured to a different gas.

## 3. "Abgerechnet" → editable invoice date

**Current state:** `BlenderSectionTitle(context.l10n.gasCalculators_blender_billed)`
("Abgerechnet") is a static heading
(`blender_invoice_card.dart:88`). There is no date field anywhere in
`BlenderPreferences`/`blenderBilledFillsProvider`; `billedFills` is a single
flat, append-only list with no concept of "session" or "invoice date" — it's
one running bill, not a history of dated invoices.

**Existing conventions to reuse:**

- `lib/shared/widgets/app_date_picker.dart::showAppDatePicker()` — the
  app-wide date picker wrapper that honors the diver's
  `DateFormatPreference` (already used by `course_edit_page.dart`,
  `service_record_dialog.dart`, `equipment_attribute_form_section.dart`,
  `download_step_widget.dart`). This should be reused rather than a bare
  `showDatePicker`.
- `UnitFormatter.formatDate()` (`core/utils/unit_formatter.dart`) for
  displaying the chosen date in the diver's preferred format.

**Implementation shape:** add `billedDate` (`DateTime?`, defaulting to "now"
when first shown) to `BlenderPreferences` + a `blenderBilledDateProvider`,
persisted/loaded the same way `billedTo` already is (same JSON blob, no
migration). Replace the static heading with a row: "Rechnung vom
{formatted date}" plus an edit affordance (icon button) opening
`showAppDatePicker`, following the same `onEditingComplete`/
`saveBlenderPreferences(ref)` save pattern used by every other field in
this card.

**Open question:** since `billedFills` is one running list with no
"invoice" grouping, a single `billedDate` is a property of the *whole*
current bill, not of an individual fill line. That matches the request
("Rechnung vom xy" as one heading), but means "Clear billed"
(`_confirmClear`) is presumably also where a new invoice date would get
reset/re-seeded to today — worth confirming during implementation.

## 4. Export (PDF/Image/Excel) and Pay, at the end of the section

**Export — the app already has first-class services for all three formats,**
none of it blender-specific yet:

- **PDF:** package `pdf` (+ `printing`), service class pattern in
  `lib/core/services/export/pdf/pdf_export_service.dart`
  (`pw.Document()`-based), with a swappable template system under
  `lib/core/services/pdf_templates/`. An options sheet
  (`lib/features/transfer/presentation/widgets/pdf_export_dialog.dart`,
  shown via `showModalBottomSheet`, returns a `PdfExportOptions?`) is the UI
  pattern to copy for "Export as PDF".
- **Image:** two established patterns — `certification_card_renderer.dart`
  draws directly to a `ui.PictureRecorder`/`Canvas` (no live widget needed),
  while `dive_profile_chart.dart` / `dive_detail_page.dart` wrap a widget in
  `RepaintBoundary` and call `boundary.toImage(pixelRatio: 2.0)` to snapshot
  what's already on screen — the latter is the simpler fit for "export this
  card as it looks now". `certification_share_sheet.dart` is the matching
  share-sheet UI (writes to a temp file, then `SharePlus.instance.share`).
- **Excel:** package `excel_community` (fork of `excel`), service class
  pattern in `lib/core/services/export/excel/excel_export_service.dart`.
- All three are normally reached through the facade
  `lib/core/services/export/export_service.dart`, and all file writes/shares
  go through the shared helpers in
  `lib/core/services/export/shared/file_export_utils.dart`
  (`saveAndShareFile`, `exportImageAsPng`, `sharePdfBytes`, ...) on top of
  `share_plus`. A blender-invoice export should follow the same
  facade/helper split rather than talking to `share_plus` directly.

**Pay — no existing precedent.** A repo-wide search for
`isPaid`/`paidAt`/`markPaid`/`PaymentStatus`/any "invoice" concept outside
the gas blender itself turned up nothing: no dive-center invoice, course
payment, or service-cost record has a paid/unpaid status anywhere in the
app. This means:

- There is no boolean-toggle-on-an-entity pattern to copy for this
  specifically (the closest structural analogue is an unrelated plain
  checkbox in `pdf_export_dialog.dart`).
- "Pay" needs its own, new, small decision before implementation: is it (a)
  a local status flag ("mark this running bill as paid", stored the same
  way as `billedTo`/`billedDate`, with no external payment processing —
  there is no indication anywhere in the app of a payment-gateway
  integration), or (b) something that also clears/archives `billedFills`
  once marked paid (closer to what `_confirmClear` already does)? Given
  `billedFills` is a single running list rather than a history of past
  invoices, (b) seems more consistent with the existing model, but this is
  a product decision, not a technical constraint, and should be confirmed
  before implementation.

## Summary of implementation shape (for the follow-up task)

No Drift migration needed anywhere in this scope — `BlenderPreferences` is
one JSON blob (`settings` KV table), so every new field (`freeGasLiters` per
line, `billedDate`, a future `paid` flag) is an additive JSON key with a
fallback default on read, exactly like `billedTo`/`gasPrices` already work.
The tariff summary (§2) needs no persistence at all — it's derived live from
providers that already exist. Export (§4) is the only piece that pulls in
genuinely new files, and only because nothing blender-specific exists yet —
the underlying PDF/Image/Excel/share machinery is all already in place and
should be reused rather than re-implemented.
