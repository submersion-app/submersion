# Cylinder Passports 3: The Newest Fill on the Tag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The diver's own app writes the cylinder's newest fill into the NFC tag's passport link, every phone that taps the tag sees it (stored for an own cylinder, shown for a foreign one), and the trimix blender can fill in a chosen cylinder and log the blend it produced.

**Architecture:** The fill rides inside the existing `/c` passport link as `f`-prefixed keys (`fi`, `ft`, `fo`, `fh`, `fp`, `fc`, `fb`, `fa`, reserved `fs`), carried by a new optional `TagFill` on `CylinderPassportPayload`. Old apps ignore the keys; printed labels never carry them; small tags drop them first. Every tag the app opens goes through `openScannedTag`, which now stores an own cylinder's tag fill once (keyed on the fill id, skipping a deleted one). Nothing is signed: no crypto, no new table, no schema rung.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Riverpod 3, go_router 17, Drift, `nfc_manager` 4.2.1 through the existing `NfcTagService` seam.

**Spec:** `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md` sections 2 (Fill handoff row), 6.2 (fill keys), 6.4 (drop order), 11 (the newest fill on the tag), 16 and the rescoped "3 Fill on the tag" row of section 17. Issue #2337, umbrella #2333.

## Global Constraints

- Branch `ericgriffin/cylinder-passports-3-2337` from `origin/main`; the PR body says `Closes #2337` and `Refs #2333`.
- No schema change: `cylinder_fills` already holds everything a tag fill needs; `station_key` and `signed_record` stay unused (reserved for signing, spec section 18).
- Tag format version stays `1`: the fill keys are optional and unknown keys are already ignored (spec section 6.3).
- A printed label never carries a fill (`currentPayloadFor` and `payloadForItem` never set one).
- Nothing is called verified or signed. A fill read from a tag shows "From tag", who filled it, and "Analyse before you dive".
- Every value with a unit goes through `UnitFormatter`; dates through `formatDate` / `formatDateTime` (guard `preference_aware_date_format_test.dart`); typed numbers through `parseDecimal` in `log_fill_sheet.dart` (guard `number_parsing_single_source_test.dart`).
- A provider that reads a repository subscribes to its change tick (`provider_change_tick_test.dart`).
- l10n: every new key in all 11 ARBs, then `flutter gen-l10n`; prefixes `passport_fill_*`, `passport_nfc_*`, `gasCalculators_blender_*`.
- No em dashes and no en dashes as punctuation anywhere; no mention of the tool that wrote the code in commits or PR text.
- Files under 800 lines; `dart format .` and `flutter analyze` clean before every commit.

## Review Focus

1. A fill the diver deleted must not come back from their own tag on the next tap. Pinned in Task 3 (`a deleted fill stays deleted`).
2. Tapping the tag right after writing it (the diver's own fill, same id) must not duplicate the fill, on this device or a synced one. Pinned in Task 3 (`the same fill twice is stored once`).
3. A tag written by a newer app with a malformed fill (a bad time, O2 plus He over 100) must still open the passport, without the fill. Pinned in Task 1.
4. An NTAG213 (144 bytes) must still get the full identity when a fill is present: the fill is the first thing dropped. Pinned in Task 1 (drop order) and Task 2 (plan on 144 bytes).
5. The blender's fields must show a chosen cylinder's values immediately, in imperial units too, and survive the next reopen. Pinned in Task 7.

---

## File Structure

**Created**

| File | Responsibility |
| --- | --- |
| `lib/features/cylinder_passports/domain/entities/tag_fill.dart` | The fill a tag carries: value, `fromFill`, `gasMix` |
| `lib/features/cylinder_passports/data/services/tag_fill_importer.dart` | Stores an own cylinder's tag fill once |
| `lib/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart` | The "Write it to the tank's tag?" step and `tagPayloadProvider` |
| `lib/features/gas_calculators/presentation/widgets/blender/blender_cylinder_picker.dart` | Choose cylinder (your tanks or Scan tag), shared by both blender actions |
| `docs/design/specs/2026-09-28-cylinder-passports-3-device-checklist.md` | Device checks CI cannot run |

**Modified** (main ones): `cylinder_passport_payload.dart`, `passport_payload_codec.dart`, `ndef_fit.dart`, `nfc_write_sheet.dart` (`tagFieldLabel`, success line), `passport_tag_card.dart` (`fullPayloadFor` takes the newest fill), `cylinder_fill_repository.dart` (`wasDeleted`), `scan_cylinder_tag.dart`, `tank_editor.dart`, `passport_current_fill_card.dart`, `passport_fill_history_card.dart`, `foreign_passport_page.dart`, `log_fill_sheet.dart` (initial values), `blender_cylinder_card.dart`, `blender_procedure_card.dart`, the 11 ARBs, `docs/import-formats/cylinder-passport-tag.md`, and in the website repo `passport/tag.js`, `passport/display.js`, `c.html` and tests.

---

## Task 1: The fill keys in the tag codec and the small-tag fitter

**Files:**
- Create: `lib/features/cylinder_passports/domain/entities/tag_fill.dart`
- Modify: `lib/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart` (`fill`, `copyWith(fill:, clearFill:)`, `props`)
- Modify: `lib/features/cylinder_passports/domain/services/passport_payload_codec.dart` (`keyOrder`, `encode`, `decode`)
- Modify: `lib/features/cylinder_passports/domain/services/ndef_fit.dart` (`dropOrder`, `drop`)
- Modify: `lib/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart` (`tagFieldLabel` for the new drop keys), all 11 ARBs
- Test: `test/features/cylinder_passports/domain/services/passport_payload_codec_test.dart`, `ndef_fit_test.dart`, `test/features/cylinder_passports/domain/entities/tag_fill_test.dart`

**Interfaces:**
- Produces:
  - `class TagFill extends Equatable` with `String id` (lower-case UUID), `DateTime filledAt` (UTC), `double o2Percent`, `double hePercent`, `double? pressureBar`, `double? temperatureC`, `String? filledBy`, `String? analyzer`; `GasMix get gasMix`; `factory TagFill.fromFill(CylinderFill fill)`; `copyWith({bool clearFilledBy, bool clearAnalyzer, bool clearTemperatureC})`; `static const int maxTextLength = 40`.
  - `CylinderPassportPayload.fill` (`TagFill?`), and `copyWith(TagFill? fill, bool clearFill = false)`.
  - `PassportPayloadCodec.keyOrder` ends `..., 'oc', 'fi', 'ft', 'fo', 'fh', 'fp', 'fc', 'fb', 'fa'`.
  - `NdefFit.dropOrder` starts `'fa', 'fb', 'fc', 'fill', 'n', ...`.

New English strings: `passport_nfc_fieldFillAnalyzer` "Fill analyzer", `passport_nfc_fieldFilledBy` "Filled by", `passport_nfc_fieldFillTemperature` "Fill temperature", `passport_nfc_fieldFill` "Newest fill".

- [ ] **Step 1: Write the failing tests**

In `passport_payload_codec_test.dart`, a new group:

```dart
  group('the newest fill', () {
    final fill = TagFill(
      id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
      filledAt: DateTime.utc(2026, 9, 28, 9, 30),
      o2Percent: 32.1,
      hePercent: 0,
      pressureBar: 232,
      temperatureC: 24.5,
      filledBy: 'Blue Hole',
      analyzer: 'Divesoft',
    );
    final base = CylinderPassportPayload(
      passportId: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
      writtenOn: DateTime(2026, 9, 28),
    );

    test('encodes after the cylinder keys, in order', () {
      expect(
        PassportPayloadCodec.encode(base.copyWith(fill: fill)),
        'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-09-28'
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09%3A30%3A00Z'
        '&fo=32.1&fh=0&fp=232&fc=24.5&fb=Blue+Hole&fa=Divesoft',
      );
    });

    test('round trips', () {
      final url = PassportPayloadCodec.httpsUrl(base.copyWith(fill: fill));
      final decoded = PassportPayloadCodec.decode(url) as PassportDecoded;
      expect(decoded.payload.fill, fill);
    });

    test('a tag without fill keys has no fill', () {
      final decoded = PassportPayloadCodec.decode(PassportPayloadCodec.httpsUrl(base)) as PassportDecoded;
      expect(decoded.payload.fill, isNull);
    });

    test('a malformed fill is dropped and the tag still opens', () {
      const p = 'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
      for (final bad in [
        '&fi=nope&ft=2026-09-28T09:30:00Z&fo=32',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=yesterday&fo=32',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00&fo=32',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z&fo=80&fh=30',
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z',
      ]) {
        final r = PassportPayloadCodec.decode('$p$bad') as PassportDecoded;
        expect(r.payload.fill, isNull, reason: bad);
      }
    });

    test('out-of-range fill details are dropped, the fill kept', () {
      final r = PassportPayloadCodec.decode(
        'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab'
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z&fo=21&fp=900&fc=300',
      ) as PassportDecoded;
      expect((r.payload.fill!.o2Percent, r.payload.fill!.pressureBar, r.payload.fill!.temperatureC), (21.0, null, null));
    });

    test('the reserved signature key is ignored', () {
      final r = PassportPayloadCodec.decode(
        'f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab'
        '&fi=3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11&ft=2026-09-28T09:30:00Z&fo=21&fs=abc',
      ) as PassportDecoded;
      expect(r.payload.fill, isNotNull);
    });
  });
```

In `ndef_fit_test.dart`:

```dart
  test('a small tag drops the fill before any cylinder key', () {
    final withFill = fullPayload.copyWith(fill: fill); // the fixtures above
    final fitted = NdefFit.fit(withFill, NdefFit.ntag213Bytes)!;
    expect(fitted.fill, isNull);
    expect(NdefFit.dropOrder.take(4), ['fa', 'fb', 'fc', 'fill']);
  });

  test('an NTAG215 keeps everything, the fill included', () {
    expect(NdefFit.fit(fullPayload.copyWith(fill: fill), NdefFit.ntag215Bytes), fullPayload.copyWith(fill: fill));
  });
```

`tag_fill_test.dart`: `TagFill.fromFill` copies the id, the time in UTC, the mix, pressure, temperature, `stationName` as `filledBy` and `analyzer`, cutting both texts to 40 characters by whole characters.

The existing test `every key a small tag can drop has a readable name` in `nfc_write_sheet_test.dart` fails until the four new labels exist; that is part of this red state.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports/domain test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`
Expected: FAIL to compile (`TagFill`, `fill` do not exist).

- [ ] **Step 3: Implement `TagFill`**

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' show GasMix;

/// The cylinder's newest fill as its NFC tag carries it (spec section 11):
/// written by the diver's own app, unsigned, and shown for what it is.
class TagFill extends Equatable {
  const TagFill({
    required this.id,
    required this.filledAt,
    required this.o2Percent,
    this.hePercent = 0,
    this.pressureBar,
    this.temperatureC,
    this.filledBy,
    this.analyzer,
  });

  static const int maxTextLength = 40;

  /// The fill row's id: reading the tag back never duplicates the fill.
  final String id;
  final DateTime filledAt;
  final double o2Percent;
  final double hePercent;
  final double? pressureBar;
  final double? temperatureC;
  final String? filledBy;
  final String? analyzer;

  GasMix get gasMix => GasMix(o2: o2Percent, he: hePercent);

  factory TagFill.fromFill(CylinderFill fill) {
    String? cap(String? text) => text == null || text.trim().isEmpty
        ? null
        : PassportPayloadCodec.capCharacters(text.trim(), maxTextLength);
    return TagFill(
      id: fill.id,
      filledAt: fill.filledAt.toUtc(),
      o2Percent: fill.o2Percent,
      hePercent: fill.hePercent,
      pressureBar: fill.pressureBar,
      temperatureC: fill.temperatureC,
      filledBy: cap(fill.stationName),
      analyzer: cap(fill.analyzer),
    );
  }

  TagFill copyWith({
    bool clearFilledBy = false,
    bool clearAnalyzer = false,
    bool clearTemperatureC = false,
  }) => TagFill(
    id: id,
    filledAt: filledAt,
    o2Percent: o2Percent,
    hePercent: hePercent,
    pressureBar: pressureBar,
    temperatureC: clearTemperatureC ? null : temperatureC,
    filledBy: clearFilledBy ? null : filledBy,
    analyzer: clearAnalyzer ? null : analyzer,
  );

  @override
  List<Object?> get props => [
    id, filledAt, o2Percent, hePercent, pressureBar, temperatureC, filledBy, analyzer,
  ];
}
```

Add `final TagFill? fill;` to `CylinderPassportPayload` (constructor `this.fill`), `TagFill? fill` and `bool clearFill = false` to `copyWith` (`fill: clearFill ? null : fill ?? this.fill`), and `fill` to `props`.

- [ ] **Step 4: Encode and decode the keys**

Append `'fi', 'ft', 'fo', 'fh', 'fp', 'fc', 'fb', 'fa'` to `keyOrder`. In `encode`, add to `values`:

```dart
      'fi': f?.id,
      'ft': f == null ? null : _rfc3339(f.filledAt),
      'fo': f == null ? null : _number(f.o2Percent),
      'fh': f == null ? null : _number(f.hePercent),
      'fp': f?.pressureBar == null ? null : _number(f!.pressureBar!),
      'fc': f?.temperatureC == null ? null : _number(f!.temperatureC!),
      'fb': f?.filledBy,
      'fa': f?.analyzer,
```

with `final f = p.fill;` at the top, and the helpers:

```dart
  /// Up to one decimal, no trailing zero: 32.1, 0, 232.
  static String _number(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }

  static String _rfc3339(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${formatDate(u)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }
```

In `decode`, after the cylinder fields, build the fill (`pairs` is the split query):

```dart
  /// The fill keys, or null when `fi`, `ft` or `fo` is missing or invalid:
  /// a bad fill is dropped, never the tag (spec section 6.2).
  static TagFill? _fill(Map<String, String> pairs) {
    final id = pairs['fi']?.toLowerCase();
    final at = pairs['ft'];
    final o2 = double.tryParse(pairs['fo'] ?? '');
    final he = double.tryParse(pairs['fh'] ?? '') ?? 0;
    if (id == null || !_uuid.hasMatch(id)) return null;
    if (at == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(at)) return null;
    final filledAt = DateTime.tryParse(at);
    if (filledAt == null || o2 == null) return null;
    if (o2 <= 0 || he < 0 || o2 + he > 100) return null;
    final p = double.tryParse(pairs['fp'] ?? '');
    final c = double.tryParse(pairs['fc'] ?? '');
    String? text(String? v) => v == null || v.trim().isEmpty
        ? null
        : capCharacters(v.trim(), TagFill.maxTextLength);
    return TagFill(
      id: id,
      filledAt: filledAt.toUtc(),
      o2Percent: o2,
      hePercent: he,
      pressureBar: p != null && p > 0 && p <= 400 ? p : null,
      temperatureC: c != null && c >= -40 && c <= 80 ? c : null,
      filledBy: text(pairs['fb']),
      analyzer: text(pairs['fa']),
    );
  }
```

and pass `fill: _fill(pairs)` to the payload `decode` builds.

- [ ] **Step 5: The drop order**

In `ndef_fit.dart`, prepend `'fa', 'fb', 'fc', 'fill'` to `dropOrder` and extend `drop`:

```dart
        'fa' => p.fill == null ? p : p.copyWith(fill: p.fill!.copyWith(clearAnalyzer: true)),
        'fb' => p.fill == null ? p : p.copyWith(fill: p.fill!.copyWith(clearFilledBy: true)),
        'fc' => p.fill == null ? p : p.copyWith(fill: p.fill!.copyWith(clearTemperatureC: true)),
        'fill' => p.copyWith(clearFill: true),
```

Update the class doc: the fill's details go first, then the whole fill, then the cylinder keys. In `tagFieldLabel` (`nfc_write_sheet.dart`) add `'fa' => l10n.passport_nfc_fieldFillAnalyzer`, `'fb' => l10n.passport_nfc_fieldFilledBy`, `'fc' => l10n.passport_nfc_fieldFillTemperature`, `'fill' => l10n.passport_nfc_fieldFill`.

- [ ] **Step 6: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/cylinder_passports test/l10n`
Expected: PASS, including the existing codec, label-length and small-tag tests (a payload without a fill encodes exactly as before).

```bash
git add lib/features/cylinder_passports lib/l10n test/features/cylinder_passports
git commit -m "feat(passports): carry the newest fill in the tag's passport link"
```

## Task 2: The newest fill in every NFC write

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_tag_card.dart` (`fullPayloadFor(..., CylinderFill? newestFill)`; watch `newestFillProvider`)
- Create: `lib/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart` (`tagPayloadProvider` only in this task)
- Modify: `nfc_write_sheet.dart` (success line), all 11 ARBs
- Test: `passport_tag_card_test.dart`, `nfc_write_sheet_test.dart`, `test/features/cylinder_passports/presentation/utils/write_fill_to_tag_test.dart`, `passport_ndef_test.dart`

**Interfaces:**
- Consumes: Task 1 `TagFill.fromFill`, `CylinderPassportPayload.fill`.
- Produces: `fullPayloadFor(item, {passportId, clocks, records, now, CylinderFill? newestFill})` (sets `fill: newestFill == null ? null : TagFill.fromFill(newestFill)`); `currentPayloadFor` unchanged (never a fill); `tagPayloadProvider` (`FutureProvider.autoDispose.family<CylinderPassportPayload?, String>`, keyed by equipment id).

New English strings: `passport_nfc_fillIncluded` "The newest fill is on the tag too", and the existing dropped-fields line names "Newest fill" when it did not fit.

- [ ] **Step 1: Write the failing tests**

- `passport_ndef_test.dart`: `planPassportMessage(payloadWithFill, maxMessageBytes: 496)!.payload.fill` equals the fill; with `144` it is null and `droppedKeys` contains `'fill'`, while the identity keys `f`, `p`, `w` are intact.
- `write_fill_to_tag_test.dart`: with a tank, its passport id, no clocks, and a newest fill, `tagPayloadProvider(equipmentId)` resolves to a payload whose `fill.id` is the newest fill's id; with no fills, `fill` is null.
- `passport_tag_card_test.dart`: with a newest fill, tapping Write NFC tag opens the sheet with a payload that has that fill (read it from the pumped `NfcWriteSheet`'s `payload`); the QR label's payload still has no fill.
- `nfc_write_sheet_test.dart`: a written payload with a fill shows `The newest fill is on the tag too`; one without shows neither that nor a dropped-fill note.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports`
Expected: FAIL on the new cases.

- [ ] **Step 3: Implement**

`fullPayloadFor` gains `CylinderFill? newestFill` and passes `.copyWith(fill: ...)` onto the `payloadForItem` result. `PassportTagCard.build` adds `final newest = ref.watch(newestFillProvider(equipment.id)).value;` and passes `newestFill: newest` to `fullPayloadFor` only (the label uses `labelPayloadOf(fullPayloadFor(...))` built without the fill, so compute the label payload from a second `fullPayloadFor` call without `newestFill`, or strip it with `.copyWith(clearFill: true)` before `labelPayloadOf`).

`write_fill_to_tag.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// What an NFC write for [equipmentId] carries right now: the full payload
/// with the newest fill, as the Tag card builds it.
final tagPayloadProvider = FutureProvider.autoDispose
    .family<CylinderPassportPayload?, String>((ref, equipmentId) async {
      final item = await ref.watch(equipmentItemProvider(equipmentId).future);
      if (item == null) return null;
      return fullPayloadFor(
        item,
        passportId: await ref.watch(passportIdProvider(equipmentId).future),
        clocks: await ref.watch(serviceClockStatusesProvider(equipmentId).future),
        records: await ref.watch(serviceRecordsForEquipmentProvider(equipmentId).future),
        now: DateTime.now(),
        newestFill: await ref.watch(newestFillProvider(equipmentId).future),
      );
    });
```

(Check `equipmentItemProvider`'s exact name and nullability in `equipment_providers.dart`; the passport page uses it.)

In `NfcWriteSheet`'s success view, add `if (written.plan.payload.fill != null) Text(l10n.passport_nfc_fillIncluded)`.

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/cylinder_passports test/architecture test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(passports): every NFC write carries the cylinder's newest fill"
```

## Task 3: Reading a tag's fill: store it once for an own cylinder

**Files:**
- Modify: `lib/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart` (`wasDeleted`)
- Create: `lib/features/cylinder_passports/data/services/tag_fill_importer.dart`
- Modify: `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart` (`tagFillImporterProvider`)
- Modify: `lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart` (`openScannedTag`)
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (`_fillFromTag`), all 11 ARBs
- Test: `tag_fill_importer_test.dart`, `cylinder_fill_repository_test.dart`, `scan_cylinder_tag_test.dart` (or the existing test of `openScannedTag`), `tank_editor_scan_test.dart`

**Interfaces:**
- Consumes: Task 1 `CylinderPassportPayload.fill`, `TagFill`.
- Produces: `CylinderFillRepository.wasDeleted(String id)`; `class TagFillImporter` with `Future<CylinderFill?> importIfNew({required CylinderPassportPayload tag, required String equipmentId, required String? diverId})` (the stored fill, or null when there was none to add); `tagFillImporterProvider`.

New English string: `passport_fill_addedFromTag` "Fill from the tag added: {mix}, {pressure}".

- [ ] **Step 1: Write the failing tests**

`tag_fill_importer_test.dart` (the in-memory database from `setUpTestDatabase`, a diver `d1`, a tank `tank-1` with passport `pp-1`):

```dart
  final fill = TagFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    filledAt: DateTime.utc(2026, 9, 28, 9, 30),
    o2Percent: 32,
    pressureBar: 232,
    filledBy: 'Blue Hole',
  );
  final tag = CylinderPassportPayload(passportId: 'pp-1', fill: fill);

  test('a new fill is stored under the cylinder, as from a tag', () async {
    final stored = await importer.importIfNew(tag: tag, equipmentId: 'tank-1', diverId: 'd1');
    expect(stored!.id, fill.id);
    expect((stored.passportId, stored.equipmentId, stored.source), ('pp-1', 'tank-1', FillSource.nfc));
    expect((stored.o2Percent, stored.pressureBar, stored.stationName), (32.0, 232.0, 'Blue Hole'));
  });

  test('the same fill twice is stored once', () async {
    await importer.importIfNew(tag: tag, equipmentId: 'tank-1', diverId: 'd1');
    expect(await importer.importIfNew(tag: tag, equipmentId: 'tank-1', diverId: 'd1'), isNull);
    expect(await db.select(db.cylinderFills).get(), hasLength(1));
  });

  test('a deleted fill stays deleted', () async {
    final stored = await importer.importIfNew(tag: tag, equipmentId: 'tank-1', diverId: 'd1');
    await CylinderFillRepository().delete(stored!.id);
    expect(await importer.importIfNew(tag: tag, equipmentId: 'tank-1', diverId: 'd1'), isNull);
    expect(await db.select(db.cylinderFills).get(), isEmpty);
  });

  test('a tag without a fill adds nothing', () async {
    expect(
      await importer.importIfNew(tag: const CylinderPassportPayload(passportId: 'pp-1'), equipmentId: 'tank-1', diverId: 'd1'),
      isNull,
    );
  });
```

`cylinder_fill_repository_test.dart`: `wasDeleted` is false for an unknown id and a live fill, true after `delete`.

`openScannedTag` test (find the existing file with `grep -rln openScannedTag test`): an own cylinder's tag URL carrying a new fill stores it and shows `Fill from the tag added: EAN32, 232 bar` before pushing the passport; a foreign cylinder's tag stores nothing.

`tank_editor_scan_test.dart`: a foreign tag with a fill prefills the tank's mix from the fill; an own tag with a newer fill than the stored ones stores it and prefills from it.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`cylinder_fill_repository.dart`:

```dart
  /// Whether a fill with [id] was deleted (a tombstone exists), so a tag
  /// that still carries it does not bring it back.
  Future<bool> wasDeleted(String id) async {
    final row = await (_db.select(_db.deletionLog)
          ..where((t) => t.entityType.equals(entity) & t.recordId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }
```

(Check the table accessor name for `DeletionLog` in the generated database; it is `deletionLog` if the table class is `DeletionLog`.)

`tag_fill_importer.dart`:

```dart
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';

/// Stores the fill an own cylinder's tag carries (spec section 11), once:
/// the fill id is the row id, so a second tap, the diver's own write read
/// back, or a copy already synced from another device adds nothing, and a
/// fill the diver deleted stays deleted.
class TagFillImporter {
  TagFillImporter({CylinderFillRepository? fills})
    : _fills = fills ?? CylinderFillRepository();

  final CylinderFillRepository _fills;

  Future<CylinderFill?> importIfNew({
    required CylinderPassportPayload tag,
    required String equipmentId,
    required String? diverId,
  }) async {
    final f = tag.fill;
    if (f == null) return null;
    if (await _fills.getById(f.id) != null) return null;
    if (await _fills.wasDeleted(f.id)) return null;
    final now = DateTime.now();
    return _fills.create(
      CylinderFill(
        id: f.id,
        diverId: diverId,
        passportId: tag.passportId,
        equipmentId: equipmentId,
        filledAt: f.filledAt,
        o2Percent: f.o2Percent,
        hePercent: f.hePercent,
        pressureBar: f.pressureBar,
        temperatureC: f.temperatureC,
        analyzer: f.analyzer,
        stationName: f.filledBy,
        source: FillSource.nfc,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
```

`tagFillImporterProvider = Provider<TagFillImporter>((ref) => TagFillImporter(fills: ref.watch(cylinderFillRepositoryProvider)));`

`openScannedTag`, in the `OwnCylinder(:final equipmentId, :final tag)` arm before pushing:

```dart
        final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
        final added = await ref
            .read(tagFillImporterProvider)
            .importIfNew(tag: tag, equipmentId: equipmentId, diverId: diverId);
        if (added != null) {
          final units = UnitFormatter(ref.read(settingsProvider));
          messenger?.showSnackBar(SnackBar(content: Text(
            l10n.passport_fill_addedFromTag(added.gasMix.name, units.formatPressure(added.pressureBar)),
          )));
        }
```

Every tag the app opens (a tap with the app closed, a link, the scan sheet, NFC in the sheet) goes through `openScannedTag`, so this is the one place. `_fillFromTag` in `tank_editor.dart`: in the own arm call `importIfNew` the same way before reading `getForCylinder(...).first.gasMix`; in the foreign arm use `tag.fill?.gasMix` as the mix instead of none.

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/cylinder_passports test/features/dive_log test/architecture test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(passports): add the fill a cylinder's tag carries, once"
```

## Task 4: How a tag fill reads: the passport and the foreign passport

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart` (`FillSourceBadge`, the analyse note)
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart`
- Modify: `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart`
- Modify: all 11 ARBs (add two keys, remove `passport_fill_unsigned`)
- Test: `passport_current_fill_card_test.dart` (or `passport_page_test.dart`), `passport_fill_history_card_test.dart`, `foreign_passport_page_test.dart`

**Interfaces:**
- Consumes: Task 1 `CylinderPassportPayload.fill`; existing `tankFromPassport(tag, {mix})`.
- Produces: `FillSourceBadge({required CylinderFill fill})` shows "From tag" for `FillSource.nfc` and nothing otherwise.

New English strings: `passport_fill_fromTag` "From tag", `passport_fill_analyseBeforeDiving` "Analyse the gas yourself before you dive it", `passport_foreign_lastFill` "Last fill on the tag", `passport_foreign_fillSummary` "{mix} · {pressure} · {date}". Remove `passport_fill_unsigned` from all 11 ARBs: nothing is signed now, so "Unsigned" says nothing.

- [ ] **Step 1: Write the failing tests**

- A fill with `source: FillSource.nfc` renders a `From tag` chip and, on the current fill card, the analyse note; a manual fill renders neither.
- `ForeignPassportPage(tag: tagWithFill)` shows `Last fill on the tag`, the mix name, pressure through `UnitFormatter` (check both metric and imperial settings), the date through `formatDate`, and `Filled by Blue Hole` (the existing `passport_fill_station`); Use on a dive pushes `/dives/new` with a tank whose mix is the fill's.
- A foreign tag without a fill shows none of that, and Use on a dive keeps the default mix.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports/presentation`
Expected: FAIL on the new cases.

- [ ] **Step 3: Implement**

Replace `FillSourceBadge` (keep its name, so both cards change in one place):

```dart
/// Where a fill came from, when that matters (spec section 11): "From tag"
/// for a fill read from the cylinder's NFC tag. Nothing is signed, so
/// nothing claims to be verified; a fill the diver logged needs no badge.
class FillSourceBadge extends StatelessWidget {
  const FillSourceBadge({super.key, required this.fill});

  final CylinderFill fill;

  @override
  Widget build(BuildContext context) {
    if (fill.source != FillSource.nfc) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Semantics(
      label: l10n.passport_fill_fromTag,
      child: Chip(
        avatar: const Icon(Icons.nfc, size: 18),
        label: Text(l10n.passport_fill_fromTag),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
```

In `_FillSummary`, under the analysis line, when `fill.source == FillSource.nfc`, add `Text(l10n.passport_fill_analyseBeforeDiving, style: theme.textTheme.bodySmall)`.

`foreign_passport_page.dart`: when `tag?.fill case final f?`, a `Card` titled `passport_foreign_lastFill` with `passport_foreign_fillSummary(f.gasMix.name, units.formatPressure(f.pressureBar), units.formatDate(f.filledAt))`, `passport_fill_station(f.filledBy)` when set, and the analyse note. Use on a dive passes `mix: tag.fill?.gasMix ?? const GasMix()` to `tankFromPassport`. Nothing is stored: a buddy's or a rental's fill is not the diver's history.

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/cylinder_passports test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(passports): show a tag's fill as From tag, with a note to analyse it"
```

## Task 5: Log a fill, then Write it to the tank's tag

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart` (`offerWriteFillToTag`)
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart` (after Log a fill)
- Modify: all 11 ARBs
- Test: `write_fill_to_tag_test.dart`, `passport_current_fill_card_test.dart`

**Interfaces:**
- Consumes: Task 2 `tagPayloadProvider`, `showNfcWriteSheet`; existing `nfcPlatform()`, `nfcSupportProvider`.
- Produces: `Future<void> offerWriteFillToTag(BuildContext context, WidgetRef ref, {required String equipmentId, required CylinderFill fill})`.

New English strings: `passport_fill_writeToTagTitle` "Fill logged", `passport_fill_writeToTagBody` "Write it to the tank's tag?", `passport_fill_writeToTag` "Write to tag", `passport_fill_notNow` "Not now".

- [ ] **Step 1: Write the failing tests**

- On an NFC phone with NFC enabled (`FakeNfcTagService(supportValue: NfcSupport.enabled)`, `debugDefaultTargetPlatformOverride = TargetPlatform.android` restored in `addTearDown`), saving Log a fill shows the dialog with `Fill logged` and the saved fill's mix and pressure; Write to tag opens `NfcWriteSheet` whose payload's `fill.id` is the saved fill's id; Not now closes it and writes nothing.
- NFC disabled, unsupported, or a desktop platform: no dialog after saving.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports/presentation`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
/// After Log a fill (spec section 11): on a phone with NFC turned on, offer
/// to write the fill to the tank's tag straight away.
Future<void> offerWriteFillToTag(
  BuildContext context,
  WidgetRef ref, {
  required String equipmentId,
  required CylinderFill fill,
}) async {
  if (!nfcPlatform()) return;
  if (await ref.read(nfcSupportProvider.future) != NfcSupport.enabled) return;
  if (!context.mounted) return;
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final write = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.passport_fill_writeToTagTitle),
      content: Text(
        '${fill.gasMix.name} · ${units.formatPressure(fill.pressureBar)}\n\n'
        '${l10n.passport_fill_writeToTagBody}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.passport_fill_notNow)),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.passport_fill_writeToTag)),
      ],
    ),
  );
  if (write != true || !context.mounted) return;
  ref.invalidate(tagPayloadProvider(equipmentId));
  final payload = await ref.read(tagPayloadProvider(equipmentId).future);
  if (payload == null || !context.mounted) return;
  await showNfcWriteSheet(context, payload: payload);
}
```

In `PassportCurrentFillCard`, the Log fill button becomes:

```dart
onPressed: passportId == null
    ? null
    : () async {
        final saved = await showLogFillSheet(context, passportId: passportId!, equipmentId: equipmentId);
        if (saved != null && context.mounted) {
          await offerWriteFillToTag(context, ref, equipmentId: equipmentId, fill: saved);
        }
      },
```

`tagPayloadProvider` reads `newestFillProvider`, which already holds the saved fill once the fills tick fires; invalidating first makes sure the write carries it.

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/cylinder_passports test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(passports): after logging a fill, offer to write it to the tank's tag"
```

## Task 6: The blender's Log this fill

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart` (initial values)
- Create: `lib/features/gas_calculators/presentation/widgets/blender/blender_cylinder_picker.dart`
- Modify: `lib/features/gas_calculators/presentation/widgets/blender/blender_procedure_card.dart`
- Modify: all 11 ARBs
- Test: `log_fill_sheet_test.dart`, `test/features/gas_calculators/blender_log_fill_test.dart`, `gas_blender_calculator_widget_test.dart` (its pump gains the new overrides)

**Interfaces:**
- Consumes: Task 5 `offerWriteFillToTag`; existing `activeEquipmentProvider`, `EquipmentType.tank`, `resolveScannedTag`, `passportScanLauncherProvider`, `CylinderPassportRepository.ensurePassportId`, `blenderTargetMixProvider`, `blenderTargetPressureProvider`, `blenderSettledTempProvider`, `blenderResultProvider`.
- Produces:
  - `showLogFillSheet(context, {required passportId, required equipmentId, GasMix? initialMix, double? initialPressureBar, double? initialTemperatureC, bool mixFromPlan = false})`; `mixFromPlan` shows the hint "Enter your analysed values" under O2 and He.
  - `Future<EquipmentItem?> showBlenderCylinderPicker(BuildContext context, WidgetRef ref)`: the diver's tanks, or Scan tag (an own cylinder resolves to its item; a foreign one or a non-tag says so and returns null).

New English strings: `gasCalculators_blender_logFill` "Log this fill", `gasCalculators_blender_chooseCylinder` "Choose cylinder", `gasCalculators_blender_scanTag` "Scan tag", `gasCalculators_blender_notYourCylinder` "That cylinder is not in your gear", `passport_logFill_analysedHint` "Enter your analysed values".

- [ ] **Step 1: Write the failing tests**

- `log_fill_sheet_test.dart`: `LogFillSheet(..., initialMix: GasMix(o2: 21, he: 35), initialPressureBar: 232, initialTemperatureC: 30, mixFromPlan: true)` shows `21`, `35`, `232` (metric) and `30`, plus the hint; in imperial settings the pressure field shows the psi value `units.convertPressure(232)` formats and the temperature the Fahrenheit one.
- `blender_log_fill_test.dart` (tank editor scan test's setup: a real test database, one tank with a passport id, `activeEquipmentProvider` overridden with it, `passportScanLauncherProvider` overridden):
  - a valid blend shows Log this fill in the procedure card; an invalid one (target pressure below start) does not;
  - Log this fill, then choosing the tank, opens the sheet prefilled with the target mix, the target pressure and the settled temperature;
  - Scan tag with the tank's tag URL picks the same tank; a foreign tag shows `That cylinder is not in your gear` and opens nothing;
  - saving stores a fill under the tank's passport id with the entered values (the diver may have changed them).

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/gas_calculators test/features/cylinder_passports/presentation/widgets/log_fill_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 3: Initial values in the sheet**

Add the four optional parameters to `showLogFillSheet` and `LogFillSheet`, and in `initState` (the sheet already builds a `UnitFormatter` in `_save`):

```dart
    final units = UnitFormatter(ref.read(settingsProvider));
    if (widget.initialMix case final mix?) {
      _o2.text = formatDecimalForInput(mix.o2);
      _he.text = formatDecimalForInput(mix.he);
    }
    if (widget.initialPressureBar case final bar?) {
      _pressure.text = formatRoundedForInput(units.convertPressure(bar), 0);
    }
    if (widget.initialTemperatureC case final c?) {
      _temperature.text = formatRoundedForInput(units.convertTemperature(c), 1);
    }
```

(`formatDecimalForInput` and `formatRoundedForInput` are in `lib/core/utils/number_input.dart`.) When `mixFromPlan` is true, the O2 field's `helperText` is `passport_logFill_analysedHint`.

- [ ] **Step 4: The picker**

```dart
/// Which of the diver's cylinders a blend is for: a tank from their gear, or
/// its tag scanned. Only an own cylinder can be logged or filled in.
Future<EquipmentItem?> showBlenderCylinderPicker(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final tanks = [
    for (final e in await ref.read(activeEquipmentProvider.future))
      if (e.type == EquipmentType.tank) e,
  ];
  if (!context.mounted) return null;
  final choice = await showModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      children: [
        ListTile(title: Text(l10n.gasCalculators_blender_chooseCylinder)),
        for (final tank in tanks)
          ListTile(
            leading: const Icon(Icons.propane_tank_outlined),
            title: Text(tank.name),
            onTap: () => Navigator.pop(sheetContext, tank),
          ),
        ListTile(
          key: const Key('blender-scan-tag'),
          leading: const Icon(Icons.qr_code_scanner),
          title: Text(l10n.gasCalculators_blender_scanTag),
          onTap: () => Navigator.pop(sheetContext, 'scan'),
        ),
      ],
    ),
  );
  if (choice is EquipmentItem) return choice;
  if (choice != 'scan' || !context.mounted) return null;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null) return null;
  switch (await resolveScannedTag(ref, text)) {
    case OwnCylinder(:final equipmentId):
      return ref.read(equipmentRepositoryProvider).getEquipmentById(equipmentId);
    case ForeignCylinder():
      messenger?.showSnackBar(SnackBar(content: Text(l10n.gasCalculators_blender_notYourCylinder)));
      return null;
    case NotACylinderTag():
      messenger?.showSnackBar(SnackBar(content: Text(l10n.passport_tag_linkInvalid)));
      return null;
  }
}
```

- [ ] **Step 5: Log this fill**

At the end of the success branch's `Column` in `BlenderProcedureCard`, following the billing card's button style:

```dart
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('blender-log-fill'),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: Text(l10n.gasCalculators_blender_logFill),
                onPressed: () async {
                  final tank = await showBlenderCylinderPicker(context, ref);
                  if (tank == null || !context.mounted) return;
                  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
                  final passportId = await ref
                      .read(cylinderPassportRepositoryProvider)
                      .ensurePassportId(tank.id, diverId: diverId);
                  if (!context.mounted) return;
                  final saved = await showLogFillSheet(
                    context,
                    passportId: passportId,
                    equipmentId: tank.id,
                    initialMix: ref.read(blenderTargetMixProvider),
                    initialPressureBar: ref.read(blenderTargetPressureProvider),
                    initialTemperatureC: ref.read(blenderSettledTempProvider),
                    mixFromPlan: true,
                  );
                  if (saved != null && context.mounted) {
                    await offerWriteFillToTag(context, ref, equipmentId: tank.id, fill: saved);
                  }
                },
              ),
            ),
```

In `gas_blender_calculator_widget_test.dart`'s `_pump`, add `activeEquipmentProvider.overrideWith((ref) async => const [])` to the overrides; the new button sits after the step table, so the tests that pick fields by index are unaffected.

- [ ] **Step 6: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/gas_calculators test/features/cylinder_passports test/architecture test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(blender): log the blended fill for one of your cylinders"
```

## Task 7: The blender's Choose cylinder

**Files:**
- Modify: `lib/features/gas_calculators/presentation/widgets/blender/blender_cylinder_card.dart`
- Modify: all 11 ARBs
- Test: `test/features/gas_calculators/blender_choose_cylinder_test.dart`

**Interfaces:**
- Consumes: Task 6 `showBlenderCylinderPicker`; existing `blenderCylinderLitersProvider`, `blenderStartMixProvider`, `blenderResetEpochProvider`, `saveBlenderPreferences`, `newestFillProvider`.
- Produces: a Choose cylinder action beside "In the cylinder".

New English string: `gasCalculators_blender_filledFrom` "{name}: {mix}".

- [ ] **Step 1: Write the failing test**

With one tank (12 L) whose newest fill is Tx 21/35: tapping Choose cylinder and the tank sets `blenderCylinderLitersProvider` to 12 and `blenderStartMixProvider` to 21/35; after the pump the start O2 and He fields show `21` and `35` and the billing card's cylinder field shows `12` (metric) or its cubic-feet water capacity (`litersToDisplayVolume(12, settings)`, imperial); a new `GasBlenderCalculator` built after `saveBlenderPreferences` still shows them. A tank with no fills sets only the volume and leaves the start mix.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/gas_calculators/blender_choose_cylinder_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Wrap the "In the cylinder" title (line 51) as the target fill header is wrapped (lines 77 to 94):

```dart
        Row(
          children: [
            Expanded(
              child: BlenderSectionTitle(
                context.l10n.gasCalculators_blender_startCylinder,
                bottomPadding: 0,
              ),
            ),
            TextButton.icon(
              key: const Key('blender-choose-cylinder'),
              icon: const Icon(Icons.propane_tank_outlined, size: 18),
              label: Text(context.l10n.gasCalculators_blender_chooseCylinder),
              onPressed: () async {
                final tank = await showBlenderCylinderPicker(context, ref);
                if (tank == null) return;
                final newest = await ref.read(newestFillProvider(tank.id).future);
                if (tank.volumeL case final litres?) {
                  ref.read(blenderCylinderLitersProvider.notifier).state = litres;
                }
                if (newest != null) {
                  ref.read(blenderStartMixProvider.notifier).state = newest.gasMix;
                }
                await saveBlenderPreferences(ref);
                // Every field keeps its own controller, seeded once: a new
                // epoch rebuilds the blender so they show the new values.
                ref.read(blenderResetEpochProvider.notifier).state++;
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
```

The start pressure is left alone: the newest fill's pressure is what the cylinder held after filling, not what is in it now.

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n` then `flutter test test/features/gas_calculators test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(blender): choose one of your cylinders to fill in its size and last mix"
```

## Task 8: Docs, the device checklist and the website's `/c` page

**Files:**
- Modify: `docs/import-formats/cylinder-passport-tag.md` (the fill keys, the drop order, the NFC layout)
- Create: `docs/design/specs/2026-09-28-cylinder-passports-3-device-checklist.md`
- Website repo (`submersion-app/submersion-website`, its own branch and PR): `passport/tag.js`, `passport/display.js`, `passport/render.js`, `c.html`, `tests/passport-tag.test.mjs`, `tests/passport-render.test.mjs`

- [ ] **Step 1: The tag document**

Add the fill rows of spec section 6.2 to the payload table, a paragraph saying the fill appears only on NFC tags and is dropped first on a small tag, an example URL with a fill, and in the NFC layout section replace the second-record paragraph with "the newest fill rides in the passport link itself".

- [ ] **Step 2: The device checklist**

`docs/design/specs/2026-09-28-cylinder-passports-3-device-checklist.md`, like the phase 2 checklist:

- iPhone and Android: Log a fill, Write to tag, then tap the tag with the app closed on a second phone with its own library: the passport opens and says "Fill from the tag added"; tap again: nothing is added.
- The same tag on the first phone: nothing is added (the fill is already its own).
- Delete that fill, tap the tag: it stays deleted.
- A buddy's tank (not in your gear): the foreign passport shows Last fill on the tag; Use on a dive prefills the mix.
- NTAG213: the write succeeds without the fill, and the sheet names "Newest fill" as left off; NTAG215 carries it.
- Blender: Choose cylinder fills in the size and last mix; Log this fill, save, Write to tag; the tag carries the blend's fill.
- An older app build (before this PR) reading a tag with a fill: the passport opens normally.

- [ ] **Step 3: The website shows a tag's fill**

In the website worktree, test first: `parsePassportTag` returns `fill` (id, time, mix, pressure, temperature, filled by, analyzer) with the app's rules from Task 1 (a malformed fill is null, the tag still ok; `fs` ignored), and the render test shows a "Last fill on the tag" block with the mix, pressure and date, and the note "Analyse the gas yourself before you dive it". Then implement in `tag.js`, `display.js`, `render.js` and `c.html`, run `node --test tests/*.test.mjs`, and open a PR in that repo referencing `submersion-app/submersion#2337`.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "docs(passports): the fill keys on the tag, and the phase 3 device checklist"
```

## Final: whole-branch checks

- [ ] `dart format .`, `flutter analyze` (no issues, infos included), `flutter test` (the full suite; one run), `flutter test test/architecture`.
- [ ] The PR body: summary, `Closes #2337`, `Refs #2333`, screenshots of the From tag chip, the Write to tag dialog, the foreign passport's last fill, and the blender's Choose cylinder and Log this fill (light and dark, phone and desktop widths for the blender).
