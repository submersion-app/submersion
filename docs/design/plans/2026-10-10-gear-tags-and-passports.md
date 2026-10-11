# Gear Tags and Passports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let every non-cylinder equipment item carry an NFC tag or QR label (`https://submersion.app/g#...`) that opens a gear passport, and let a scan add gear to a dive or pack it for a trip.

**Architecture:** A new `lib/features/gear_passports/` feature holds the gear tag payload, codec, fitting, resolver, adoption service and pages. The cylinder passport stack (`lib/features/cylinder_passports/`) is generalised at four seams only: the passport id lookup searches every type, the NFC write path takes any tag plan, the link and NFC readers accept `/g`, and the scan opener routes by the holder's type. Cylinder-only scan points keep their cylinder-only resolver.

**Tech Stack:** Flutter, Riverpod (`core/providers/provider.dart`), Drift, go_router, `nfc_manager` via `NfcTagService`, `ndef_record`, `pdf`.

**Spec:** `docs/design/specs/2026-10-10-gear-tags-and-passports-design.md`

## Global Constraints

- No em-dashes (U+2014) anywhere: code, comments, docs, commits, ARB values.
- No AI tool attribution in any committed text.
- No schema rung, no new table. `passport_id` stays an `AttributeGroup.system` attribute.
- Gear tag URL: `https://submersion.app/g#<payload>`; custom scheme `submersion://g?<payload>` accepted, never written.
- Payload keys in emission order: `f`, `p`, `w`, `t`, `n`, `b`, `mo`, `sn`, `ls`. Required on read: `f` (defaults to 1), `p`, `t`.
- Caps: `n` 40 code points; `b`, `mo`, `sn` 24 code points.
- Small-tag drop order: `ls`, `mo`, `b`, `sn`, `n`. Never `f`, `p`, `w`, `t`.
- A `/g` tag with `t=tank` is rejected (`notGear`); a missing `t` is rejected (`missingType`).
- Passport id minting is unchanged: `Uuid().v5(kCylinderPassportNamespace, equipmentId)`.
- Every displayed unit goes through `UnitFormatter`; every date through `units.formatDate`.
- Every new user-visible string is an ARB key in `app_en.arb` and translated into all ten locale ARBs before the final `flutter gen-l10n`.
- Imports grouped dart, flutter, packages, local; `dart format .` before every commit.
- Platform-agnostic paths in tests (`p.join`, `Directory.systemTemp`).

## Deliberate departures from the spec's wording

Recorded in the spec in the same commit as this plan, so the two documents agree:

- `CylinderPassportRepository`, `kCylinderPassportNamespace` and `printPassportLabels` keep their names. Renaming them churns about twenty files for no behaviour; the generalisation is in their bodies.
- The foreign gear route is `/equipment/gear-tag?t=...`, beside the existing `/equipment/tag`, not a top-level `/gear-tag`.
- The scan sheet's title becomes the generic "Scan a tag" everywhere (new key `tagScan_title`); the old `passport_scan_title` key is removed.
- Follow-up found while planning: the clone form seed (`equipment_clone_seed.dart`) copies `passport_id`, so a clone shares its source's tag. Task 2 fixes it.

## Review Focus

1. A cylinder tag scanned in the dive tank editor or blender after this change must behave exactly as before; a gear tag there must say it is not a cylinder (Task 6 test pins `resolveScannedTag` to tanks).
2. A retyped item (tank to regulator) still holding its id: a `/c` scan opens the gear passport, a cylinder-only scan point rejects it, and linking that id to another tank is refused while the regulator is in service (Task 5 tests).
3. A tag scanned in the dive editor for an item already on the dive must not duplicate it, and a wishlist item must not be added (Task 13 tests).
4. An NFC write of a gear tag on a 144-byte NTAG213 with a long non-ASCII name must still write the identity and type (Task 3 test with a 40-character Hebrew name).
5. Android re-dispatching a gear tag the app just wrote must not open the passport a second time (Task 4 `RecentPassportTags` test with a `/g` link).

---

## File Structure

New, under `lib/features/gear_passports/`:

| File | Responsibility |
| --- | --- |
| `domain/entities/gear_tag_payload.dart` | `GearTagPayload`, the decoded tag |
| `domain/services/gear_tag_codec.dart` | encode, decode, URL forms, rejection reasons |
| `domain/services/gear_tag_fit.dart` | drop order and `drop` for small tags |
| `domain/services/gear_tag_ndef.dart` | `GearNdefPlan`, `planGearMessage` |
| `domain/services/tag_link_codec.dart` | one decoder for `/c` and `/g` |
| `domain/services/tag_resolver.dart` | own, foreign cylinder, foreign gear, unreadable |
| `domain/services/gear_tag_rules.dart` | payload for an item, last service date, staleness |
| `data/services/gear_adoption_service.dart` | Add to my gear |
| `presentation/providers/gear_passport_providers.dart` | adoption service provider |
| `presentation/utils/scan_owned_item.dart` | scan, resolve, message; returns an own item |
| `presentation/pages/gear_passport_page.dart` | the gear passport |
| `presentation/pages/foreign_gear_page.dart` | read-only snapshot with Add to my gear |
| `presentation/widgets/gear_passport_header.dart` | header card |
| `presentation/widgets/gear_recent_service_card.dart` | newest three service records |
| `presentation/widgets/gear_tag_card.dart` | QR, print, NFC write, link, stale hint |
| `presentation/widgets/gear_passport_entry_card.dart` | detail page doorway |

Modified: the catalog, `cylinder_passport_repository.dart`, `passport_ndef.dart`, `passport_tag_io.dart`, `nfc_write_sheet.dart`, `link_existing_tag_dialog.dart`, `recent_passport_tags.dart`, `passport_link_dispatcher.dart`, `scan_cylinder_tag.dart`, `scan_tag_menu_entries.dart`, `passport_scan_sheet.dart`, `print_passport_labels.dart`, `equipment_list_content.dart`, `equipment_detail_page.dart`, `service_record_dialog.dart`, `equipment_clone_seed.dart`, `app_router.dart`, `dive_edit_page.dart`, `trip_gear_add_sheet.dart`, `AndroidManifest.xml`, ARB files.

Tests mirror the paths under `test/features/gear_passports/` and beside existing tests.

### Task 1: Gear tag payload and codec

**Files:**
- Create: `lib/features/gear_passports/domain/entities/gear_tag_payload.dart`
- Create: `lib/features/gear_passports/domain/services/gear_tag_codec.dart`
- Test: `test/features/gear_passports/domain/services/gear_tag_codec_test.dart`

**Interfaces:**
- Consumes: `PassportPayloadCodec.capCharacters`, `formatDate`, `parseDate` (public statics in `passport_payload_codec.dart`).
- Produces: `GearTagPayload` (fields `formatVersion`, `passportId`, `typeCode`, `writtenOn`, `name`, `brand`, `model`, `serial`, `lastService`; getter `EquipmentType? type`; `copyWith` with `clear*` flags); `GearTagCodec.encode/httpsUrl/extractQuery/decode`; `GearTagDecoded(payload, newerFormat)`, `GearTagRejected(reason)`, `GearTagRejectReason { notATag, missingId, malformedId, missingType, notGear }`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

GearTagPayload _full() => GearTagPayload(
  passportId: _id,
  typeCode: 'firstStage',
  writtenOn: DateTime(2026, 10, 10),
  name: 'Apeks XTX50 primary',
  brand: 'Apeks',
  model: 'XTX50',
  serial: 'AB12345',
  lastService: DateTime(2026, 3, 2),
);

GearTagPayload _decoded(String text) {
  final r = GearTagCodec.decode(text);
  expect(r, isA<GearTagDecoded>());
  return (r as GearTagDecoded).payload;
}

GearTagRejectReason _rejected(String text) {
  final r = GearTagCodec.decode(text);
  expect(r, isA<GearTagRejected>());
  return (r as GearTagRejected).reason;
}

void main() {
  group('encode', () {
    test('emits keys in fixed order, values encoded', () {
      expect(
        GearTagCodec.encode(_full()),
        'f=1&p=$_id&w=2026-10-10&t=firstStage&n=Apeks+XTX50+primary'
        '&b=Apeks&mo=XTX50&sn=AB12345&ls=2026-03-02',
      );
    });

    test('leaves out absent keys', () {
      expect(
        GearTagCodec.encode(GearTagPayload(passportId: _id, typeCode: 'fins')),
        'f=1&p=$_id&t=fins',
      );
    });

    test('httpsUrl puts the payload in the fragment of /g', () {
      expect(
        GearTagCodec.httpsUrl(_full()),
        startsWith('https://submersion.app/g#f=1&p='),
      );
    });

    test('caps text by code points', () {
      final long = GearTagPayload(
        passportId: _id,
        typeCode: 'mask',
        name: 'n' * 50,
        brand: 'b' * 30,
        model: 'm' * 30,
        serial: 's' * 30,
      );
      final back = _decoded(GearTagCodec.httpsUrl(long));
      expect(back.name, 'n' * 40);
      expect(back.brand, 'b' * 24);
      expect(back.model, 'm' * 24);
      expect(back.serial, 's' * 24);
    });
  });

  group('decode', () {
    test('round trips every key', () {
      expect(_decoded(GearTagCodec.httpsUrl(_full())), _full());
    });

    test('round trips names with spaces, ampersands, hashes and non-ASCII', () {
      final p = _full().copyWith(name: 'Reg & #2 été');
      expect(_decoded(GearTagCodec.httpsUrl(p)).name, p.name);
    });

    test('accepts the custom scheme with a query', () {
      final q = GearTagCodec.encode(_full());
      expect(_decoded('submersion://g?$q'), _full());
    });

    test('accepts http, www, upper case and a trailing slash', () {
      final q = GearTagCodec.encode(_full());
      expect(_decoded('HTTP://WWW.Submersion.App/g/#$q'), _full());
    });

    test('accepts the payload in the query of the https form', () {
      final q = GearTagCodec.encode(_full());
      expect(_decoded('https://submersion.app/g?$q'), _full());
    });

    test('a cylinder link, a longer path or another host is not a gear tag', () {
      final q = GearTagCodec.encode(_full());
      expect(_rejected('https://submersion.app/c#$q'), GearTagRejectReason.notATag);
      expect(_rejected('https://submersion.app/g/x#$q'), GearTagRejectReason.notATag);
      expect(_rejected('https://example.com/g#$q'), GearTagRejectReason.notATag);
      expect(_rejected(q), GearTagRejectReason.notATag);
    });

    test('ignores unknown keys and reports a newer format', () {
      final r = GearTagCodec.decode(
        'https://submersion.app/g#f=2&p=$_id&t=bcd&zz=1',
      );
      expect(r, isA<GearTagDecoded>());
      expect((r as GearTagDecoded).newerFormat, isTrue);
      expect(r.payload.typeCode, 'bcd');
    });

    test('rejects a missing or malformed id', () {
      expect(
        _rejected('https://submersion.app/g#f=1&t=bcd'),
        GearTagRejectReason.missingId,
      );
      expect(
        _rejected('https://submersion.app/g#f=1&p=nope&t=bcd'),
        GearTagRejectReason.malformedId,
      );
    });

    test('rejects a missing type and a tank type', () {
      expect(
        _rejected('https://submersion.app/g#f=1&p=$_id'),
        GearTagRejectReason.missingType,
      );
      expect(
        _rejected('https://submersion.app/g#f=1&p=$_id&t=tank'),
        GearTagRejectReason.notGear,
      );
    });

    test('keeps an unknown type raw and maps it to no EquipmentType', () {
      final p = _decoded('https://submersion.app/g#f=1&p=$_id&t=jetpack');
      expect(p.typeCode, 'jetpack');
      expect(p.type, isNull);
    });

    test('maps a known type', () {
      expect(_decoded(GearTagCodec.httpsUrl(_full())).type, EquipmentType.firstStage);
    });

    test('drops a bad date, never the tag', () {
      final p = _decoded(
        'https://submersion.app/g#f=1&p=$_id&t=bcd&w=2026-02-30&ls=nope',
      );
      expect(p.writtenOn, isNull);
      expect(p.lastService, isNull);
    });

    test('bad percent-encoding is not a tag', () {
      expect(
        _rejected('https://submersion.app/g#f=1&p=$_id&t=bcd&n=%zz'),
        GearTagRejectReason.notATag,
      );
    });

    test('upper-case ids are lower-cased', () {
      final p = _decoded(
        'https://submersion.app/g#f=1&p=${_id.toUpperCase()}&t=bcd',
      );
      expect(p.passportId, _id);
    });
  });
}
```

Note: the `é` escapes above are typed as the literal accented characters when writing the file (the Write tool decodes escapes; write "Reg & #2 été" directly).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/gear_passports/domain/services/gear_tag_codec_test.dart`
Expected: FAIL, the imported files do not exist.

- [ ] **Step 3: Implement the payload**

`lib/features/gear_passports/domain/entities/gear_tag_payload.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// What a gear tag says about an item (gear tag spec section 6.2).
///
/// A snapshot written when the label was printed or the NFC tag written.
/// Only [passportId] identifies the item; the rest is what the diver's
/// record looked like on [writtenOn]. [typeCode] is kept as written so a
/// type added by a newer app still opens.
class GearTagPayload extends Equatable {
  static const int currentFormatVersion = 1;
  static const int maxNameLength = 40;
  static const int maxShortTextLength = 24;

  /// Type codes are enum names; the cap only stops a hostile tag from
  /// carrying an essay in a field the page prints.
  static const int maxTypeCodeLength = 32;

  final int formatVersion;
  final String passportId;
  final String typeCode;
  final DateTime? writtenOn;
  final String? name;
  final String? brand;
  final String? model;
  final String? serial;
  final DateTime? lastService;

  const GearTagPayload({
    this.formatVersion = currentFormatVersion,
    required this.passportId,
    required this.typeCode,
    this.writtenOn,
    this.name,
    this.brand,
    this.model,
    this.serial,
    this.lastService,
  });

  /// The type [typeCode] names, or null for one this app does not know.
  EquipmentType? get type {
    for (final t in EquipmentType.values) {
      if (t.name == typeCode) return t;
    }
    return null;
  }

  GearTagPayload copyWith({
    int? formatVersion,
    String? passportId,
    String? typeCode,
    DateTime? writtenOn,
    bool clearWrittenOn = false,
    String? name,
    bool clearName = false,
    String? brand,
    bool clearBrand = false,
    String? model,
    bool clearModel = false,
    String? serial,
    bool clearSerial = false,
    DateTime? lastService,
    bool clearLastService = false,
  }) => GearTagPayload(
    formatVersion: formatVersion ?? this.formatVersion,
    passportId: passportId ?? this.passportId,
    typeCode: typeCode ?? this.typeCode,
    writtenOn: clearWrittenOn ? null : (writtenOn ?? this.writtenOn),
    name: clearName ? null : (name ?? this.name),
    brand: clearBrand ? null : (brand ?? this.brand),
    model: clearModel ? null : (model ?? this.model),
    serial: clearSerial ? null : (serial ?? this.serial),
    lastService: clearLastService ? null : (lastService ?? this.lastService),
  );

  @override
  List<Object?> get props => [
    formatVersion,
    passportId,
    typeCode,
    writtenOn,
    name,
    brand,
    model,
    serial,
    lastService,
  ];
}
```

- [ ] **Step 4: Implement the codec**

`lib/features/gear_passports/domain/services/gear_tag_codec.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

/// Why a scanned or pasted string is not a gear tag.
enum GearTagRejectReason { notATag, missingId, malformedId, missingType, notGear }

sealed class GearTagDecodeResult {
  const GearTagDecodeResult();
}

class GearTagDecoded extends GearTagDecodeResult {
  final GearTagPayload payload;

  /// The tag's format is newer than this app knows; every known key was read.
  final bool newerFormat;
  const GearTagDecoded(this.payload, {this.newerFormat = false});
}

class GearTagRejected extends GearTagDecodeResult {
  final GearTagRejectReason reason;
  const GearTagRejected(this.reason);
}

/// The gear tag string (gear tag spec section 6): a query-string payload in
/// the fragment of `https://submersion.app/g` or the query of
/// `submersion://g`.
///
/// Total: [decode] never throws. Unknown keys are ignored, bad dates are
/// dropped, text is capped. Unlike the cylinder codec there is no bare
/// payload form: a bare query string is read as a cylinder tag.
abstract final class GearTagCodec {
  static const String httpsPrefix = 'https://submersion.app/g';
  static const String schemePrefix = 'submersion://g';

  /// Emission order. Two devices must produce the same string for one item.
  static const List<String> keyOrder = [
    'f',
    'p',
    'w',
    't',
    'n',
    'b',
    'mo',
    'sn',
    'ls',
  ];

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static const Set<String> _tagHosts = {'submersion.app', 'www.submersion.app'};

  static String? _cap(String? text, int max) => text == null || text.isEmpty
      ? null
      : PassportPayloadCodec.capCharacters(text, max);

  /// The bare query string, keys in [keyOrder], values percent-encoded.
  static String encode(GearTagPayload p) {
    final values = <String, String?>{
      'f': p.formatVersion.toString(),
      'p': p.passportId,
      'w': p.writtenOn == null
          ? null
          : PassportPayloadCodec.formatDate(p.writtenOn!),
      't': _cap(p.typeCode, GearTagPayload.maxTypeCodeLength),
      'n': _cap(p.name, GearTagPayload.maxNameLength),
      'b': _cap(p.brand, GearTagPayload.maxShortTextLength),
      'mo': _cap(p.model, GearTagPayload.maxShortTextLength),
      'sn': _cap(p.serial, GearTagPayload.maxShortTextLength),
      'ls': p.lastService == null
          ? null
          : PassportPayloadCodec.formatDate(p.lastService!),
    };
    return [
      for (final key in keyOrder)
        if (values[key] case final value? when value.isNotEmpty)
          '$key=${Uri.encodeQueryComponent(value)}',
    ].join('&');
  }

  static String httpsUrl(GearTagPayload p) => '$httpsPrefix#${encode(p)}';

  /// The payload part of [text] when it is a gear tag link in either URL
  /// form, else null. Parsed, not prefix-matched: scheme and host match in
  /// any case, `http` and a `www.` host are accepted, the path is exactly
  /// `/g`. The payload is cut from the raw text, because `Uri` repairs a
  /// stray '%' into '%25'.
  static String? extractQuery(String text) {
    final s = text.trim();
    if (!s.contains('://')) return null;
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path;
    final isWeb =
        (scheme == 'https' || scheme == 'http') &&
        _tagHosts.contains(host) &&
        (path == '/g' || path == '/g/');
    final isApp =
        scheme == 'submersion' &&
        host == 'g' &&
        (path.isEmpty || path == '/');
    if (!isWeb && !isApp) return null;
    final hash = s.indexOf('#');
    if (hash >= 0) return hash + 1 < s.length ? s.substring(hash + 1) : null;
    final q = s.indexOf('?');
    if (q >= 0) return q + 1 < s.length ? s.substring(q + 1) : null;
    return null;
  }

  static GearTagDecodeResult decode(String text) {
    final query = extractQuery(text);
    if (query == null) {
      return const GearTagRejected(GearTagRejectReason.notATag);
    }
    final Map<String, String> pairs;
    try {
      pairs = Uri.splitQueryString(query);
    } on FormatException {
      return const GearTagRejected(GearTagRejectReason.notATag);
    } on ArgumentError {
      // Bad percent-encoding throws ArgumentError, not FormatException.
      return const GearTagRejected(GearTagRejectReason.notATag);
    }
    final rawId = pairs['p'];
    if (rawId == null || rawId.isEmpty) {
      return const GearTagRejected(GearTagRejectReason.missingId);
    }
    final id = rawId.toLowerCase();
    if (!_uuid.hasMatch(id)) {
      return const GearTagRejected(GearTagRejectReason.malformedId);
    }
    final typeCode = _cap(pairs['t'], GearTagPayload.maxTypeCodeLength);
    if (typeCode == null) {
      return const GearTagRejected(GearTagRejectReason.missingType);
    }
    if (typeCode == EquipmentType.tank.name) {
      return const GearTagRejected(GearTagRejectReason.notGear);
    }
    final format =
        int.tryParse(pairs['f'] ?? '') ?? GearTagPayload.currentFormatVersion;
    return GearTagDecoded(
      GearTagPayload(
        formatVersion: format,
        passportId: id,
        typeCode: typeCode,
        writtenOn: PassportPayloadCodec.parseDate(pairs['w']),
        name: _cap(pairs['n'], GearTagPayload.maxNameLength),
        brand: _cap(pairs['b'], GearTagPayload.maxShortTextLength),
        model: _cap(pairs['mo'], GearTagPayload.maxShortTextLength),
        serial: _cap(pairs['sn'], GearTagPayload.maxShortTextLength),
        lastService: PassportPayloadCodec.parseDate(pairs['ls']),
      ),
      newerFormat: format > GearTagPayload.currentFormatVersion,
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/gear_passports/domain/services/gear_tag_codec_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/gear_passports test/features/gear_passports
git add lib/features/gear_passports test/features/gear_passports
git commit -m "feat(gear-passports): gear tag payload and codec"
```

### Task 2: Passport id on every type, and clones never copy it

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart:148-164` (move the `passportId` def into `universal`) and `:353-357` (remove it from the tank list)
- Modify: `lib/features/equipment/domain/services/equipment_clone_seed.dart:40-43`
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart:610-628`
- Test: the clone seed test (`grep -rl cloneFormSeed test`)

**Interfaces:**
- Produces: `EquipmentAttributeCatalog.attributesFor(t)` contains the `passport_id` def for every `t`; `cloneFormSeed` never carries a system attribute.

- [ ] **Step 1: Update the catalog test to the new rule**

Replace the test `'is a system attribute on tanks only'` with:

```dart
    test('is a system attribute on every type (issue #2652)', () {
      final def = EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.passportId,
      );
      expect(def, isNotNull);
      expect(def!.kind, AttributeKind.text);
      expect(def.group, AttributeGroup.system);
      for (final type in EquipmentType.values) {
        expect(
          EquipmentAttributeCatalog.attributesFor(type),
          contains(def),
          reason: type.name,
        );
      }
    });
```

- [ ] **Step 2: Add the clone test**

In the clone seed test file add:

```dart
  test('a clone never carries the source tag (issue #2652)', () {
    final source = EquipmentItem(
      id: 'src',
      name: 'Primary',
      type: EquipmentType.regulator,
      attributes: const [
        EquipmentAttribute.curated(
          equipmentId: 'src',
          key: EquipmentAttrKeys.passportId,
          valueText: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
        ),
      ],
    );
    final seed = cloneFormSeed(source, copyName: (n) => '$n copy');
    expect(
      seed.attributes.map((a) => a.key),
      isNot(contains(EquipmentAttrKeys.passportId)),
    );
  });
```

(Adjust the `EquipmentItem` and `EquipmentAttribute.curated` constructor arguments to the ones the existing tests in that file use.)

- [ ] **Step 3: Run to verify both fail**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart <clone seed test path>`
Expected: FAIL on regulator not containing the def, and on the clone carrying `passport_id`.

- [ ] **Step 4: Move the def and filter the clone**

In the catalog, cut this entry from the `EquipmentType.tank` list:

```dart
      EquipmentAttributeDef(
        key: EquipmentAttrKeys.passportId,
        kind: AttributeKind.text,
        group: AttributeGroup.system,
      ),
```

and append it as the last entry of `universal`, with the comment:

```dart
    // The item's tag identity (issues #2334, #2652). System: never rendered
    // by a form, exported or imported.
```

In `equipment_clone_seed.dart`, change the attribute filter to:

```dart
      for (final a in source.attributes)
        if (a.isCustom ||
            (!_perItemAttrKeys.contains(a.key) &&
                !EquipmentAttributeCatalog.isSystemKey(a.key)))
          a.copyWith(id: a.isCustom ? uuid.v4() : '', equipmentId: ''),
```

and extend the doc comment: "nor any system attribute: a passport id names one physical item, so a clone starts untagged (issue #2652)."

- [ ] **Step 5: Run the catalog, clone and equipment domain tests**

Run: `flutter test test/features/equipment/domain`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment test/features/equipment
git commit -m "feat(equipment): every item can hold a passport id, and a clone starts untagged"
```

### Task 3: Fitting a gear tag and writing any tag kind

**Files:**
- Create: `lib/features/gear_passports/domain/services/gear_tag_fit.dart`
- Create: `lib/features/gear_passports/domain/services/gear_tag_ndef.dart`
- Modify: `lib/features/cylinder_passports/domain/services/passport_ndef.dart` (extract the fit loop, add `TagNdefPlan`)
- Modify: `lib/features/cylinder_passports/data/services/passport_tag_io.dart` (`TagWritten.plan` becomes `TagNdefPlan`; add `writeTagTo`)
- Test: `test/features/gear_passports/domain/services/gear_tag_ndef_test.dart`
- Test: existing `test/features/cylinder_passports/domain/services/passport_ndef_test.dart` and `.../data/services/passport_tag_io_test.dart` stay green unchanged

**Interfaces:**
- Consumes: `GearTagPayload`, `GearTagCodec.httpsUrl` (Task 1); `uriRecord`, `androidApplicationRecord` (existing).
- Produces:
  - `abstract interface class TagNdefPlan { NdefMessage get message; String get url; List<String> get droppedKeys; bool get includesAndroidRecord; bool get includesFill; }`
  - `PassportNdefPlan implements TagNdefPlan` (keeps `payload`).
  - `({NdefMessage message, T payload, List<String> dropped, bool withAar})? fitUriMessage<T>(T payload, {required String Function(T) url, required List<String> dropOrder, required T Function(T, String) drop, required int maxMessageBytes})`
  - `GearTagFit.dropOrder`, `GearTagFit.drop(GearTagPayload, String)`.
  - `class GearNdefPlan implements TagNdefPlan { final GearTagPayload payload; ... }`, `GearNdefPlan? planGearMessage(GearTagPayload, {required int maxMessageBytes})`.
  - `Future<PassportTagWrite> writeTagTo(NdefTagHandle? tag, TagNdefPlan? Function(int maxMessageBytes) planFor)`; `writePassportTo` delegates to it.

- [ ] **Step 1: Write the failing gear NDEF tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_ndef.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

/// The NDEF message size a phone reports for each NTAG: user memory minus
/// the TLV wrapper and terminator.
int _reported(int bytes) => bytes - 3;

GearTagPayload _full({String name = 'Apeks XTX50 primary'}) => GearTagPayload(
  passportId: _id,
  typeCode: 'firstStage',
  writtenOn: DateTime(2026, 10, 10),
  name: name,
  brand: 'Apeks',
  model: 'XTX50',
  serial: 'AB12345',
  lastService: DateTime(2026, 3, 2),
);

void main() {
  test('drop order is ls, mo, b, sn, n', () {
    expect(GearTagFit.dropOrder, ['ls', 'mo', 'b', 'sn', 'n']);
    final p = _full();
    expect(GearTagFit.drop(p, 'ls').lastService, isNull);
    expect(GearTagFit.drop(p, 'mo').model, isNull);
    expect(GearTagFit.drop(p, 'b').brand, isNull);
    expect(GearTagFit.drop(p, 'sn').serial, isNull);
    expect(GearTagFit.drop(p, 'n').name, isNull);
    expect(GearTagFit.drop(p, 'zz'), p);
  });

  test('NTAG215 and NTAG216 keep everything, with the Android record', () {
    for (final size in [NdefFit.ntag215Bytes, NdefFit.ntag216Bytes]) {
      final plan = planGearMessage(_full(), maxMessageBytes: _reported(size))!;
      expect(plan.payload, _full());
      expect(plan.droppedKeys, isEmpty);
      expect(plan.includesAndroidRecord, isTrue);
      expect(plan.url, GearTagCodec.httpsUrl(_full()));
      expect(plan.includesFill, isFalse);
      expect(uriOf(plan.message.records.first), plan.url);
    }
  });

  test('NTAG213 keeps identity, type and name, dropping in order', () {
    final plan = planGearMessage(
      _full(),
      maxMessageBytes: _reported(NdefFit.ntag213Bytes),
    )!;
    expect(plan.payload.passportId, _id);
    expect(plan.payload.typeCode, 'firstStage');
    expect(plan.payload.writtenOn, DateTime(2026, 10, 10));
    expect(plan.payload.name, isNotNull);
    expect(plan.droppedKeys.first, 'ls');
    final order = GearTagFit.dropOrder;
    expect(
      plan.droppedKeys,
      order.sublist(0, plan.droppedKeys.length),
      reason: 'drops follow the fixed order',
    );
  });

  test('a long non-ASCII name still leaves identity and type on NTAG213', () {
    // Hebrew letters percent-encode to six characters each.
    final name = String.fromCharCodes(List.filled(40, 0x05D0));
    final plan = planGearMessage(
      _full(name: name),
      maxMessageBytes: _reported(NdefFit.ntag213Bytes),
    )!;
    expect(plan.payload.passportId, _id);
    expect(plan.payload.typeCode, 'firstStage');
    expect(plan.droppedKeys, contains('n'));
  });

  test('null when even the identity does not fit', () {
    expect(planGearMessage(_full(), maxMessageBytes: 40), isNull);
  });

  test('firstPassportUri finds a gear link', () {
    final plan = planGearMessage(_full(), maxMessageBytes: 500)!;
    expect(firstPassportUri(plan.message), plan.url);
  });
}
```

Leave the last test failing until Task 4 makes `firstPassportUri` accept `/g`: mark it `skip: 'Task 4'` now and remove the skip in Task 4.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/gear_passports/domain/services/gear_tag_ndef_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Generalise `passport_ndef.dart`**

Add, below `androidApplicationRecord`:

```dart
/// What a write puts on a tag, whatever kind of tag it is.
abstract interface class TagNdefPlan {
  NdefMessage get message;

  /// The link the identity record carries, after any drops.
  String get url;

  /// Keys the full payload had and the tag could not hold, in drop order.
  List<String> get droppedKeys;

  bool get includesAndroidRecord;

  /// Whether a cylinder's newest fill rode along (never for gear).
  bool get includesFill;
}

/// The fitting loop every tag kind shares (spec 6.4): the identity URI
/// record of [url] with keys dropped in [dropOrder] until it fits
/// [maxMessageBytes], then the Android Application Record when room
/// remains. Null when even the payload with every optional key dropped
/// does not fit.
({NdefMessage message, T payload, List<String> dropped, bool withAar})?
fitUriMessage<T>(
  T payload, {
  required String Function(T payload) url,
  required List<String> dropOrder,
  required T Function(T payload, String key) drop,
  required int maxMessageBytes,
}) {
  var current = payload;
  final dropped = <String>[];
  var i = 0;
  while (true) {
    final identity = uriRecord(url(current));
    if (identity.byteLength <= maxMessageBytes) {
      final aar = androidApplicationRecord();
      final withAar = identity.byteLength + aar.byteLength <= maxMessageBytes;
      return (
        message: NdefMessage(records: [identity, if (withAar) aar]),
        payload: current,
        dropped: List.unmodifiable(dropped),
        withAar: withAar,
      );
    }
    if (i >= dropOrder.length) return null;
    final key = dropOrder[i++];
    final next = drop(current, key);
    if (next != current) dropped.add(key);
    current = next;
  }
}
```

Make `PassportNdefPlan` implement it:

```dart
class PassportNdefPlan implements TagNdefPlan {
  const PassportNdefPlan({
    required this.message,
    required this.payload,
    required this.droppedKeys,
    required this.includesAndroidRecord,
  });

  @override
  final NdefMessage message;

  /// The payload the identity record carries, after any drops.
  final CylinderPassportPayload payload;

  @override
  final List<String> droppedKeys;

  @override
  final bool includesAndroidRecord;

  @override
  String get url => PassportPayloadCodec.httpsUrl(payload);

  @override
  bool get includesFill => payload.fill != null;
}
```

Replace the body of `planPassportMessage` with:

```dart
  final fitted = fitUriMessage<CylinderPassportPayload>(
    payload,
    url: PassportPayloadCodec.httpsUrl,
    dropOrder: NdefFit.dropOrder,
    drop: NdefFit.drop,
    maxMessageBytes: maxMessageBytes,
  );
  if (fitted == null) return null;
  return PassportNdefPlan(
    message: fitted.message,
    payload: fitted.payload,
    droppedKeys: fitted.dropped,
    includesAndroidRecord: fitted.withAar,
  );
```

- [ ] **Step 4: Gear fit and gear NDEF**

`gear_tag_fit.dart`:

```dart
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

/// Fits a gear tag into a small NFC tag (gear tag spec 6.4): optional keys
/// are dropped first to last; `f`, `p`, `w` and `t` never are.
abstract final class GearTagFit {
  static const List<String> dropOrder = ['ls', 'mo', 'b', 'sn', 'n'];

  static GearTagPayload drop(GearTagPayload p, String key) => switch (key) {
    'ls' => p.copyWith(clearLastService: true),
    'mo' => p.copyWith(clearModel: true),
    'b' => p.copyWith(clearBrand: true),
    'sn' => p.copyWith(clearSerial: true),
    'n' => p.copyWith(clearName: true),
    _ => p,
  };
}
```

`gear_tag_ndef.dart`:

```dart
import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';

/// What a gear tag write puts on the tag.
class GearNdefPlan implements TagNdefPlan {
  const GearNdefPlan({
    required this.message,
    required this.payload,
    required this.droppedKeys,
    required this.includesAndroidRecord,
  });

  @override
  final NdefMessage message;

  /// The payload the identity record carries, after any drops.
  final GearTagPayload payload;

  @override
  final List<String> droppedKeys;

  @override
  final bool includesAndroidRecord;

  @override
  String get url => GearTagCodec.httpsUrl(payload);

  @override
  bool get includesFill => false;
}

/// The message for [payload] on a tag whose NDEF message may take
/// [maxMessageBytes]; null when even the identity and type do not fit.
GearNdefPlan? planGearMessage(
  GearTagPayload payload, {
  required int maxMessageBytes,
}) {
  final fitted = fitUriMessage<GearTagPayload>(
    payload,
    url: GearTagCodec.httpsUrl,
    dropOrder: GearTagFit.dropOrder,
    drop: GearTagFit.drop,
    maxMessageBytes: maxMessageBytes,
  );
  if (fitted == null) return null;
  return GearNdefPlan(
    message: fitted.message,
    payload: fitted.payload,
    droppedKeys: fitted.dropped,
    includesAndroidRecord: fitted.withAar,
  );
}
```

- [ ] **Step 5: `writeTagTo` in `passport_tag_io.dart`**

Change `TagWritten.plan` to `final TagNdefPlan plan;` and replace `writePassportTo` with:

```dart
/// Writes the message [planFor] builds for [tag]'s capacity (spec 13.3),
/// whole, then reads it back to confirm. Never throws. A partial write is
/// not resumed; the caller's Retry writes the whole message again.
Future<PassportTagWrite> writeTagTo(
  NdefTagHandle? tag,
  TagNdefPlan? Function(int maxMessageBytes) planFor,
) async {
  if (tag == null) return const TagNotNdef();
  if (!tag.isWritable) return const TagReadOnly();
  final plan = planFor(tag.maxMessageBytes);
  if (plan == null) return TagTooSmall(tag.maxMessageBytes);
  try {
    await tag.write(plan.message);
    final back = await tag.read();
    if (back != plan.message) return const TagReadBackMismatch();
    return TagWritten(
      plan: plan,
      capacity: tag.maxMessageBytes,
      typeLabel: tag.typeLabel,
    );
  } catch (e) {
    return TagWriteFailed(e);
  }
}

/// [writeTagTo] for a cylinder passport.
Future<PassportTagWrite> writePassportTo(
  NdefTagHandle? tag,
  CylinderPassportPayload payload,
) => writeTagTo(
  tag,
  (max) => planPassportMessage(payload, maxMessageBytes: max),
);
```

Any test that reads `written.plan.payload` from a `TagWritten` casts: `(written.plan as PassportNdefPlan).payload`. `nfc_write_sheet.dart` is updated in Task 9; until then change its two uses to `plan.url` and `plan.includesFill` so the app compiles:

```dart
      TagWritten(:final plan) => plan.url,
```
(with the `written` local in `_noteHeld` becoming a `String?` url and `recent.note(written)`), and `if (written.plan.includesFill) ...`.

- [ ] **Step 6: Run the NDEF, tag IO and write sheet tests**

Run: `flutter test test/features/gear_passports test/features/cylinder_passports/domain/services/passport_ndef_test.dart test/features/cylinder_passports/data/services/passport_tag_io_test.dart test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`
Expected: PASS (one skipped test in the gear NDEF file).

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/gear_passports lib/features/cylinder_passports test/features/gear_passports test/features/cylinder_passports
git commit -m "feat(gear-passports): fit gear tags to NFC tags and write any tag kind"
```

### Task 4: One decoder for `/c` and `/g`, in links, NFC reads and repeat suppression

**Files:**
- Create: `lib/features/gear_passports/domain/services/tag_link_codec.dart`
- Modify: `lib/features/cylinder_passports/domain/services/passport_ndef.dart` (`firstPassportUri`)
- Modify: `lib/features/cylinder_passports/presentation/services/recent_passport_tags.dart` (`_passportIdOf`)
- Modify: `lib/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart:122`
- Test: `test/features/gear_passports/domain/services/tag_link_codec_test.dart`
- Test: add cases to the dispatcher and recent-tags tests (`grep -rl "PassportLinkDispatcher\|RecentPassportTags" test`); un-skip the Task 3 `firstPassportUri` test

**Interfaces:**
- Consumes: `GearTagCodec` (Task 1), `PassportPayloadCodec`.
- Produces:
  - `sealed class TagLinkResult`; `sealed class TagLinkDecoded extends TagLinkResult { String get passportId; bool get newerFormat; }`; `CylinderTagLink(CylinderPassportPayload payload, {bool newerFormat})`; `GearTagLink(GearTagPayload payload, {bool newerFormat})`; `TagLinkRejected()`.
  - `TagLinkCodec.decode(String) -> TagLinkResult`, `TagLinkCodec.isTagLink(String) -> bool`, `TagLinkCodec.passportIdOf(String) -> String?`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

void main() {
  final cylinder = PassportPayloadCodec.httpsUrl(
    const CylinderPassportPayload(passportId: _id, name: 'Steel 12'),
  );
  final gear = GearTagCodec.httpsUrl(
    const GearTagPayload(passportId: _id, typeCode: 'bcd', name: 'Wing'),
  );

  test('a /c link decodes as a cylinder tag', () {
    final r = TagLinkCodec.decode(cylinder);
    expect(r, isA<CylinderTagLink>());
    expect((r as CylinderTagLink).payload.name, 'Steel 12');
    expect(r.passportId, _id);
  });

  test('a /g link decodes as a gear tag', () {
    final r = TagLinkCodec.decode(gear);
    expect(r, isA<GearTagLink>());
    expect((r as GearTagLink).payload.typeCode, 'bcd');
    expect(r.passportId, _id);
  });

  test('a bare payload is read as a cylinder tag, as before', () {
    expect(
      TagLinkCodec.decode('f=1&p=$_id'),
      isA<CylinderTagLink>(),
    );
  });

  test('a /g link that fails to decode is rejected, not tried as /c', () {
    expect(
      TagLinkCodec.decode('https://submersion.app/g#f=1&p=$_id'),
      isA<TagLinkRejected>(),
    );
  });

  test('anything else is rejected', () {
    expect(TagLinkCodec.decode('https://example.com'), isA<TagLinkRejected>());
    expect(TagLinkCodec.isTagLink('hello'), isFalse);
  });

  test('isTagLink and passportIdOf accept both kinds', () {
    expect(TagLinkCodec.isTagLink(cylinder), isTrue);
    expect(TagLinkCodec.isTagLink(gear), isTrue);
    expect(TagLinkCodec.passportIdOf(gear), _id);
    expect(TagLinkCodec.passportIdOf('nope'), isNull);
  });
}
```

In `test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart` add:

```dart
  test('a gear tag opens too (issue #2652)', () async {
    const gearTag =
        'https://submersion.app/g#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&t=bcd';
    dispatcher.setReady(true);
    await send(gearTag);
    expect(opened, [gearTag]);
  });
```

In `test/features/cylinder_passports/presentation/services/recent_passport_tags_test.dart` add:

```dart
  test('a gear tag the app just wrote is dropped once (issue #2652)', () {
    const gear = 'https://submersion.app/g#f=1&p=$id&t=bcd';
    recent.note(gear);
    expect(recent.takeJustHandled('submersion://g?f=1&p=$id&t=bcd'), isTrue);
    expect(recent.takeJustHandled(gear), isFalse);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/gear_passports/domain/services/tag_link_codec_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Implement the decoder**

```dart
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

sealed class TagLinkResult {
  const TagLinkResult();
}

/// A tag string that names an item: a cylinder (`/c`) or other gear (`/g`).
sealed class TagLinkDecoded extends TagLinkResult {
  const TagLinkDecoded();

  String get passportId;
  bool get newerFormat;
}

class CylinderTagLink extends TagLinkDecoded {
  const CylinderTagLink(this.payload, {this.newerFormat = false});

  final CylinderPassportPayload payload;
  @override
  final bool newerFormat;

  @override
  String get passportId => payload.passportId;
}

class GearTagLink extends TagLinkDecoded {
  const GearTagLink(this.payload, {this.newerFormat = false});

  final GearTagPayload payload;
  @override
  final bool newerFormat;

  @override
  String get passportId => payload.passportId;
}

class TagLinkRejected extends TagLinkResult {
  const TagLinkRejected();
}

/// Reads any Submersion tag string (gear tag spec 8.1): the path picks the
/// codec, and a bare query string is a cylinder payload, as it always was.
abstract final class TagLinkCodec {
  static TagLinkResult decode(String text) {
    if (GearTagCodec.extractQuery(text) != null) {
      return switch (GearTagCodec.decode(text)) {
        GearTagDecoded(:final payload, :final newerFormat) => GearTagLink(
          payload,
          newerFormat: newerFormat,
        ),
        GearTagRejected() => const TagLinkRejected(),
      };
    }
    return switch (PassportPayloadCodec.decode(text)) {
      PassportDecoded(:final payload, :final newerFormat) => CylinderTagLink(
        payload,
        newerFormat: newerFormat,
      ),
      PassportRejected() => const TagLinkRejected(),
    };
  }

  /// Whether [text] has the shape of a tag link of either kind, without
  /// judging its payload: incoming-link and NFC filters use this.
  static bool isTagLink(String text) =>
      GearTagCodec.extractQuery(text) != null ||
      PassportPayloadCodec.extractQuery(text) != null;

  /// The lower-case passport id [text] names, or null.
  static String? passportIdOf(String text) => switch (decode(text)) {
    TagLinkDecoded(:final passportId) => passportId.toLowerCase(),
    TagLinkRejected() => null,
  };
}
```

- [ ] **Step 4: Use it in the three readers**

- `passport_ndef.dart` `firstPassportUri`: `if (uri != null && TagLinkCodec.isTagLink(uri)) return uri;` and the doc comment says "The first tag URI, cylinder or gear".
- `recent_passport_tags.dart`: `static String? _passportIdOf(String text) => TagLinkCodec.passportIdOf(text);` (drop the codec import if unused).
- `passport_link_dispatcher.dart`: `if (!TagLinkCodec.isTagLink(text)) return;` and the class doc says "passport tags of either kind".

Remove the `skip:` from the Task 3 `firstPassportUri` test.

- [ ] **Step 5: Run**

Run: `flutter test test/features/gear_passports test/features/cylinder_passports`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features test/features
git commit -m "feat(gear-passports): read gear tags from links and NFC"
```

### Task 5: Passport id lookup across every type

**Files:**
- Modify: `lib/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart`
- Modify: `lib/features/cylinder_passports/data/services/csv_fill_importer.dart:69` (pass `type: EquipmentType.tank`)
- Test: `test/features/cylinder_passports/data/repositories/cylinder_passport_repository_test.dart`

**Interfaces:**
- Produces:
  - `typedef PassportHolder = ({String equipmentId, EquipmentType type});`
  - `Future<PassportHolder?> findHolderByPassportId(String passportId, {String? diverId, EquipmentType? type})`
  - `Future<String?> findEquipmentIdByPassportId(String passportId, {String? diverId, EquipmentType? type})` (any type when `type` is null)
  - `assignPassportId` and `ensurePassportId` unchanged in signature; any type may hold; fills move only for a tank.

- [ ] **Step 1: Rewrite the retype tests and add gear cases**

Give the seed helper a type: `Future<void> seedEquipment(String eq, {String diver = 'd1', String type = 'tank'})` and use `type: type` in the companion. Replace the three retype tests (`'an item retyped away from a cylinder no longer holds the tag'`, `'linking a tag a retyped item still carries moves it'`, keep `'a retype undone keeps the tag'`) with:

```dart
  test('an item retyped away from a cylinder still answers for its id', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retype('eq-1', 'regulator');
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd1'), 'eq-1');
    expect(
      (await repo.findHolderByPassportId(id, diverId: 'd1'))?.type,
      EquipmentType.regulator,
    );
    expect(
      await repo.findEquipmentIdByPassportId(
        id,
        diverId: 'd1',
        type: EquipmentType.tank,
      ),
      isNull,
    );
  });

  test('a retyped item in service keeps its id when a tank links it', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retype('eq-1', 'regulator');
    await expectLater(
      repo.assignPassportId(equipmentId: 'eq-2', passportId: id, diverId: 'd1'),
      throwsA(isA<PassportIdInUse>()),
    );
    expect(await repo.getPassportId('eq-1'), id);
    expect(await repo.getPassportId('eq-2'), isNull);
  });

  test('a retired retyped item gives its id up', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retype('eq-1', 'regulator');
    await (db.update(db.equipment)..where((t) => t.id.equals('eq-1'))).write(
      const EquipmentCompanion(status: Value('retired')),
    );
    await repo.assignPassportId(
      equipmentId: 'eq-2',
      passportId: id,
      diverId: 'd1',
    );
    expect(await repo.getPassportId('eq-2'), id);
    expect(await repo.getPassportId('eq-1'), isNull);
  });

  test('a regulator mints its id from its equipment id (issue #2652)', () async {
    await seedEquipment('reg-1', type: 'regulator');
    final minted = await repo.ensurePassportId('reg-1', diverId: 'd1');
    expect(minted, const Uuid().v5(kCylinderPassportNamespace, 'reg-1'));
    expect(
      await repo.findEquipmentIdByPassportId(minted, diverId: 'd1'),
      'reg-1',
    );
  });

  test('fills under an id never follow it onto other gear', () async {
    await seedEquipment('reg-1', type: 'regulator');
    final fills = CylinderFillRepository();
    final t = DateTime(2026, 9, 1);
    await fills.create(
      CylinderFill(
        id: 'a',
        passportId: id,
        filledAt: t,
        o2Percent: 21,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await repo.assignPassportId(
      equipmentId: 'reg-1',
      passportId: id,
      diverId: 'd1',
    );
    expect((await fills.getById('a'))!.equipmentId, isNull);
  });
```

Add imports: `package:uuid/uuid.dart` and `package:submersion/core/constants/enums.dart`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/cylinder_passports/data/repositories/cylinder_passport_repository_test.dart`
Expected: FAIL (no `findHolderByPassportId`, lookup still tank-only).

- [ ] **Step 3: Implement**

Replace `findEquipmentIdByPassportId` with:

```dart
  /// The one item holding [passportId], of any type unless [type] narrows
  /// it, limited to the gear [diverId] can see (owns or has been shared)
  /// when given; the whole library when null. An item keeps its id across a
  /// retype, and answers as what it is now (issue #2652).
  Future<PassportHolder?> findHolderByPassportId(
    String passportId, {
    String? diverId,
    EquipmentType? type,
  }) async {
    final attrs = _db.equipmentAttributes;
    final eq = _db.equipment;
    final query =
        _db.select(attrs).join([
          innerJoin(eq, eq.id.equalsExp(attrs.equipmentId)),
        ])..where(
          attrs.attrKey.equals(EquipmentAttrKeys.passportId) &
              attrs.isCustom.equals(false) &
              attrs.valueText.equals(passportId),
        );
    if (type != null) query.where(eq.type.equals(type.name));
    final visible = VisibilityFilter.equipmentVisibleTo(_db, eq, diverId);
    if (visible != null) query.where(visible);
    final holders = [for (final r in await query.get()) r.readTable(eq)];
    if (holders.isEmpty) return null;
    // One id should have one holder, but an old import could have written
    // two. Resolve the same way every time: in service, oldest, then id.
    final sorted = [...holders]
      ..sort((a, b) {
        final byFitted = (_isFitted(a) ? 0 : 1) - (_isFitted(b) ? 0 : 1);
        if (byFitted != 0) return byFitted;
        final byAge = a.createdAt.compareTo(b.createdAt);
        return byAge != 0 ? byAge : a.id.compareTo(b.id);
      });
    final row = sorted.first;
    return (equipmentId: row.id, type: _typeOf(row.type));
  }

  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
    EquipmentType? type,
  }) async => (await findHolderByPassportId(
    passportId,
    diverId: diverId,
    type: type,
  ))?.equipmentId;

  static EquipmentType _typeOf(String name) {
    for (final t in EquipmentType.values) {
      if (t.name == name) return t;
    }
    return EquipmentType.other;
  }
```

Add above the class: `typedef PassportHolder = ({String equipmentId, EquipmentType type});`.

Delete `_nonTankCarriers` and, in `assignPassportId`, delete the loop that releases non-tank carriers. Inside the transaction, before writing, read the target's type, and gate the fill moves on it:

```dart
      final target = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(equipmentId))).getSingleOrNull();
      // Fills belong to cylinders; other gear never collects them.
      final holdsFills = target?.type == EquipmentType.tank.name;
```

```dart
      if (holdsFills && previous != null && previous != passportId) {
        await _fills.rekeyPassport(
          from: previous,
          to: passportId,
          equipmentId: equipmentId,
        );
      }
      if (holdsFills) {
        await _fills.relinkToEquipment(
          passportId: passportId,
          equipmentId: equipmentId,
        );
      }
```

Update the transaction comment: "the holder check, releasing a holder no longer in service, writing the id and, for a cylinder, moving the fills". Update the class doc: "The passport id of any equipment item (cylinder spec 6.5, gear tag spec 7)".

In `csv_fill_importer.dart:69`, pass `type: EquipmentType.tank` (fills link only to cylinders).

- [ ] **Step 4: Run the repository, fill and adoption tests**

Run: `flutter test test/features/cylinder_passports/data`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/cylinder_passports test/features/cylinder_passports
git commit -m "feat(gear-passports): look passport ids up across every equipment type"
```

### Task 6: The tag resolver, and cylinder-only scans pinned to tanks

**Files:**
- Create: `lib/features/gear_passports/domain/services/tag_resolver.dart`
- Modify: `lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart` (`resolveScannedTag` passes `type: EquipmentType.tank`)
- Test: `test/features/gear_passports/domain/services/tag_resolver_test.dart`
- Test: `test/features/cylinder_passports/presentation/utils/` existing scan tests stay green

**Interfaces:**
- Consumes: `TagLinkCodec`, `TagLinkDecoded`, `CylinderTagLink`, `GearTagLink` (Task 4); `PassportHolder` (Task 5).
- Produces:
  - `sealed class TagResolution`; `OwnTaggedItem({required String equipmentId, required EquipmentType type, required TagLinkDecoded link})`; `ForeignCylinderTag(CylinderPassportPayload tag, {bool newerFormat})`; `ForeignGearTag(GearTagPayload tag, {bool newerFormat})`; `UnreadableTag()`.
  - `TagResolver({required Future<PassportHolder?> Function(String passportId) findHolder})` with `Future<TagResolution> resolve(String text)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_resolver.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
const _cylinder = 'https://submersion.app/c#f=1&p=$_id&n=Steel';
const _gear = 'https://submersion.app/g#f=1&p=$_id&t=bcd&n=Wing';

TagResolver _resolver(PassportHolder? holder) =>
    TagResolver(findHolder: (_) async => holder);

void main() {
  test('own gear resolves with its current type and the gear link', () async {
    final r = await _resolver(
      (equipmentId: 'eq', type: EquipmentType.bcd),
    ).resolve(_gear);
    expect(r, isA<OwnTaggedItem>());
    r as OwnTaggedItem;
    expect(r.equipmentId, 'eq');
    expect(r.type, EquipmentType.bcd);
    expect(r.link, isA<GearTagLink>());
  });

  test('a cylinder tag on an item now a regulator resolves as own', () async {
    final r = await _resolver(
      (equipmentId: 'eq', type: EquipmentType.regulator),
    ).resolve(_cylinder);
    expect((r as OwnTaggedItem).type, EquipmentType.regulator);
    expect(r.link, isA<CylinderTagLink>());
  });

  test('misses are foreign, by tag kind', () async {
    expect(await _resolver(null).resolve(_cylinder), isA<ForeignCylinderTag>());
    final g = await _resolver(null).resolve(_gear);
    expect(g, isA<ForeignGearTag>());
    expect((g as ForeignGearTag).tag.name, 'Wing');
  });

  test('text that is no tag is unreadable, and nothing is looked up', () async {
    var looked = false;
    final r = await TagResolver(
      findHolder: (_) async {
        looked = true;
        return null;
      },
    ).resolve('hello');
    expect(r, isA<UnreadableTag>());
    expect(looked, isFalse);
  });

  test('the newer-format flag rides along on a foreign gear tag', () async {
    final r = await _resolver(
      null,
    ).resolve('https://submersion.app/g#f=2&p=$_id&t=bcd');
    expect((r as ForeignGearTag).newerFormat, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/gear_passports/domain/services/tag_resolver_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';

/// What a scanned, pasted or opened tag string turns out to be (gear tag
/// spec 8.2), for either kind of tag.
sealed class TagResolution {
  const TagResolution();
}

/// A tag for an item the diver can see. [type] is what the item is now,
/// which picks the page; [link] is what the tag said.
class OwnTaggedItem extends TagResolution {
  const OwnTaggedItem({
    required this.equipmentId,
    required this.type,
    required this.link,
  });

  final String equipmentId;
  final EquipmentType type;
  final TagLinkDecoded link;
}

/// A cylinder tag no item the diver can see holds.
class ForeignCylinderTag extends TagResolution {
  const ForeignCylinderTag(this.tag, {this.newerFormat = false});

  final CylinderPassportPayload tag;
  final bool newerFormat;
}

/// A gear tag no item the diver can see holds.
class ForeignGearTag extends TagResolution {
  const ForeignGearTag(this.tag, {this.newerFormat = false});

  final GearTagPayload tag;
  final bool newerFormat;
}

/// Text that is no tag.
class UnreadableTag extends TagResolution {
  const UnreadableTag();
}

/// Decodes any tag string and looks its passport id up among the diver's
/// items of every type. The lookup is injected so the domain stays free of
/// the database.
class TagResolver {
  const TagResolver({required this.findHolder});

  final Future<PassportHolder?> Function(String passportId) findHolder;

  Future<TagResolution> resolve(String text) async {
    final link = TagLinkCodec.decode(text);
    if (link is! TagLinkDecoded) return const UnreadableTag();
    final holder = await findHolder(link.passportId);
    if (holder != null) {
      return OwnTaggedItem(
        equipmentId: holder.equipmentId,
        type: holder.type,
        link: link,
      );
    }
    return switch (link) {
      CylinderTagLink(:final payload, :final newerFormat) =>
        ForeignCylinderTag(payload, newerFormat: newerFormat),
      GearTagLink(:final payload, :final newerFormat) => ForeignGearTag(
        payload,
        newerFormat: newerFormat,
      ),
    };
  }
}
```

In `scan_cylinder_tag.dart` `resolveScannedTag`, pass the tank filter so the tank editor and blender keep resolving cylinders only:

```dart
    findEquipmentId: (passportId) => repository.findEquipmentIdByPassportId(
      passportId,
      diverId: diverId,
      type: EquipmentType.tank,
    ),
```

with the doc comment "Resolves [text] against the active diver's cylinders only: the tank editor and the blender take nothing else."

- [ ] **Step 4: Run**

Run: `flutter test test/features/gear_passports test/features/cylinder_passports test/features/dive_log/presentation/widgets test/features/gas_calculators`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features test/features
git commit -m "feat(gear-passports): resolve any tag against the diver's gear"
```

### Task 7: A gear item's tag: payload, last service, staleness

**Files:**
- Create: `lib/features/gear_passports/domain/services/gear_tag_rules.dart`
- Test: `test/features/gear_passports/domain/services/gear_tag_rules_test.dart`

**Interfaces:**
- Consumes: `GearTagPayload`, `GearTagCodec` caps (Task 1); `EquipmentItem` (`name`, `type`, `brand`, `model`, `serialNumber`); `ServiceRecord.serviceDate`.
- Produces:
  - `DateTime? lastServiceDate(Iterable<ServiceRecord> records)` (local calendar date of the newest record).
  - `GearTagPayload gearPayloadForItem({required EquipmentItem item, required String passportId, required DateTime now, DateTime? lastService})`.
  - `bool gearTagIsStale({required GearTagPayload tag, required EquipmentItem item, DateTime? lastService})`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_rules.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

EquipmentItem _item({String name = 'Primary', String? brand = 'Apeks'}) =>
    EquipmentItem(
      id: 'eq',
      name: name,
      type: EquipmentType.firstStage,
      brand: brand,
      model: 'XTX50',
      serialNumber: 'AB12345',
    );

ServiceRecord _record(DateTime date) => ServiceRecord(
  id: 'r${date.millisecondsSinceEpoch}',
  equipmentId: 'eq',
  serviceCategory: ServiceCategory.annual,
  serviceDate: date,
  createdAt: date,
  updatedAt: date,
);

void main() {
  test('last service is the newest record date, as a calendar date', () {
    expect(lastServiceDate(const []), isNull);
    expect(
      lastServiceDate([
        _record(DateTime(2025, 3, 1, 15)),
        _record(DateTime(2026, 3, 2, 9, 30)),
      ]),
      DateTime(2026, 3, 2),
    );
  });

  test('the payload carries the row and the date written', () {
    final p = gearPayloadForItem(
      item: _item(),
      passportId: _id,
      now: DateTime(2026, 10, 10, 14, 5),
      lastService: DateTime(2026, 3, 2),
    );
    expect(p.passportId, _id);
    expect(p.typeCode, 'firstStage');
    expect(p.writtenOn, DateTime(2026, 10, 10));
    expect(p.name, 'Primary');
    expect(p.brand, 'Apeks');
    expect(p.model, 'XTX50');
    expect(p.serial, 'AB12345');
    expect(p.lastService, DateTime(2026, 3, 2));
  });

  test('blank text fields are left off', () {
    final p = gearPayloadForItem(
      item: _item(brand: '  '),
      passportId: _id,
      now: DateTime(2026, 10, 10),
    );
    expect(p.brand, isNull);
  });

  group('staleness', () {
    final tag = gearPayloadForItem(
      item: _item(),
      passportId: _id,
      now: DateTime(2026, 10, 10),
      lastService: DateTime(2026, 3, 2),
    );

    test('a tag that matches the row is current', () {
      expect(
        gearTagIsStale(tag: tag, item: _item(), lastService: DateTime(2026, 3, 2)),
        isFalse,
      );
    });

    test('a service after the tag was written makes it stale', () {
      expect(
        gearTagIsStale(tag: tag, item: _item(), lastService: DateTime(2026, 10, 11)),
        isTrue,
      );
    });

    test('a service on the day it was written does not', () {
      expect(
        gearTagIsStale(tag: tag, item: _item(), lastService: DateTime(2026, 10, 10)),
        isFalse,
      );
    });

    test('a renamed item makes it stale; a field the tag left off does not', () {
      expect(
        gearTagIsStale(tag: tag, item: _item(name: 'Backup'), lastService: null),
        isTrue,
      );
      expect(
        gearTagIsStale(
          tag: tag.copyWith(clearBrand: true),
          item: _item(),
          lastService: DateTime(2026, 3, 2),
        ),
        isFalse,
      );
    });

    test('a retyped item makes it stale', () {
      final retyped = EquipmentItem(
        id: 'eq',
        name: 'Primary',
        type: EquipmentType.secondStage,
        brand: 'Apeks',
        model: 'XTX50',
        serialNumber: 'AB12345',
      );
      expect(
        gearTagIsStale(tag: tag, item: retyped, lastService: DateTime(2026, 3, 2)),
        isTrue,
      );
    });

    test('a long name capped on the tag is not a difference', () {
      final long = 'x' * 50;
      final capped = gearPayloadForItem(
        item: _item(name: long),
        passportId: _id,
        now: DateTime(2026, 10, 10),
      );
      expect(
        gearTagIsStale(tag: capped, item: _item(name: long), lastService: null),
        isFalse,
      );
    });
  });
}
```

(Use the `ServiceRecord` and `ServiceCategory` constructor arguments the entity requires; the fields above are the ones it defines.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/gear_passports/domain/services/gear_tag_rules_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

String? _text(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

String? _capped(String? s, int max) {
  final t = _text(s);
  return t == null ? null : PassportPayloadCodec.capCharacters(t, max);
}

/// The calendar date of the newest service record of any kind, or null.
DateTime? lastServiceDate(Iterable<ServiceRecord> records) {
  DateTime? newest;
  for (final r in records) {
    if (newest == null || r.serviceDate.isAfter(newest)) newest = r.serviceDate;
  }
  return newest == null ? null : _day(newest);
}

/// The tag [item] gets if one is written [now] (gear tag spec 6.2).
GearTagPayload gearPayloadForItem({
  required EquipmentItem item,
  required String passportId,
  required DateTime now,
  DateTime? lastService,
}) => GearTagPayload(
  passportId: passportId,
  typeCode: item.type.name,
  writtenOn: _day(now),
  name: _capped(item.name, GearTagPayload.maxNameLength),
  brand: _capped(item.brand, GearTagPayload.maxShortTextLength),
  model: _capped(item.model, GearTagPayload.maxShortTextLength),
  serial: _capped(item.serialNumber, GearTagPayload.maxShortTextLength),
  lastService: lastService == null ? null : _day(lastService),
);

/// Whether a scanned [tag] no longer describes [item] (gear tag spec 6.5):
/// a service recorded after the day it was written, another type, or a
/// name, brand, model or serial that differs from what the tag carries. A
/// field the tag left off (dropped to fit a small tag) is not a difference.
bool gearTagIsStale({
  required GearTagPayload tag,
  required EquipmentItem item,
  DateTime? lastService,
}) {
  final written = tag.writtenOn;
  if (written != null && lastService != null &&
      _day(lastService).isAfter(written)) {
    return true;
  }
  if (tag.typeCode != item.type.name) return true;
  final current = gearPayloadForItem(
    item: item,
    passportId: tag.passportId,
    now: written ?? DateTime.now(),
  );
  bool differs(String? onTag, String? now) => onTag != null && onTag != now;
  return differs(tag.name, current.name) ||
      differs(tag.brand, current.brand) ||
      differs(tag.model, current.model) ||
      differs(tag.serial, current.serial);
}
```

- [ ] **Step 4: Run**

Run: `flutter test test/features/gear_passports/domain/services/gear_tag_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/gear_passports test/features/gear_passports
git commit -m "feat(gear-passports): build and check a gear item's tag"
```

### Task 8: Add to my gear from a gear tag

**Files:**
- Create: `lib/features/gear_passports/data/services/gear_adoption_service.dart`
- Create: `lib/features/gear_passports/presentation/providers/gear_passport_providers.dart`
- Test: `test/features/gear_passports/data/services/gear_adoption_service_test.dart`

**Interfaces:**
- Consumes: `CylinderPassportRepository.findEquipmentIdByPassportId`, `assignPassportId`, `PassportIdInUse` (Task 5); `EquipmentRepository.transaction`, `createEquipment(item, notify: false)`, `getEquipmentById`; `ServiceScheduleRepository.getSchedulesForEquipment`, `updateSchedule(schedule.withBaseline(date, now:, picked: true), notify: false)`; `SyncEventBus.notifyLocalChange()`.
- Produces: `GearAdoptionService.adopt(GearTagPayload tag, {required String? diverId, required String fallbackName, DateTime? now}) -> Future<EquipmentItem>`; `gearAdoptionServiceProvider`.

- [ ] **Step 1: Write the failing tests**

Model the setup on `test/features/cylinder_passports/data/services/passport_adoption_service_test.dart` (same `setUpTestDatabase`, divers seeded). Cases:

```dart
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final tag = GearTagPayload(
    passportId: id,
    typeCode: 'regulator',
    writtenOn: DateTime(2026, 10, 1),
    name: 'Club reg 4',
    brand: 'Scubapro',
    model: 'MK25',
    serial: 'SP-4',
    lastService: DateTime(2026, 2, 14),
  );

  test('creates an item of the tag type with its fields and id', () async {
    final item = await service.adopt(tag, diverId: 'd1', fallbackName: 'Gear');
    expect(item.type, EquipmentType.regulator);
    expect(item.name, 'Club reg 4');
    expect(item.brand, 'Scubapro');
    expect(item.model, 'MK25');
    expect(item.serialNumber, 'SP-4');
    expect(await passports.getPassportId(item.id), id);
  });

  test('an unknown type becomes other, a missing name the fallback', () async {
    final item = await service.adopt(
      const GearTagPayload(passportId: id, typeCode: 'jetpack'),
      diverId: 'd1',
      fallbackName: 'Gear',
    );
    expect(item.type, EquipmentType.other);
    expect(item.name, 'Gear');
  });

  test('the last service date becomes every schedule baseline, no record', () async {
    final at = DateTime(2026, 10, 10, 12);
    final item = await service.adopt(
      tag,
      diverId: 'd1',
      fallbackName: 'Gear',
      now: at,
    );
    final schedules = await ServiceScheduleRepository()
        .getSchedulesForEquipment(item.id);
    expect(schedules, isNotEmpty, reason: 'a regulator gets default clocks');
    for (final s in schedules) {
      expect(s.anchorDate, DateTime(2026, 2, 14));
    }
    expect(
      await ServiceRecordRepository().getRecordsForEquipment(item.id),
      isEmpty,
    );
  });

  test('refuses, creating nothing, when an in-service item holds the id', () async {
    final first = await service.adopt(tag, diverId: 'd1', fallbackName: 'Gear');
    await expectLater(
      service.adopt(tag, diverId: 'd2', fallbackName: 'Gear'),
      throwsA(isA<PassportIdInUse>()),
    );
    final all = await EquipmentRepository().getAllEquipment();
    expect(all.where((e) => e.id != first.id), isEmpty);
  });
```

Use the repository method names the cylinder adoption test already uses for listing equipment and records; if a regulator gets no default schedules in the test database, attach one with `ServiceScheduleRepository().createSchedule(...)` before asserting, as the cylinder test does for `hydro`.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/gear_passports/data/services/gear_adoption_service_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

/// "Add to my gear" for a scanned gear tag (gear tag spec 10): an item of
/// the tag's type with its name, brand, model, serial and passport id, and
/// the tag's last service date as every attached clock's baseline, in one
/// transaction. A held id throws [PassportIdInUse] and nothing is created.
class GearAdoptionService {
  GearAdoptionService({
    EquipmentRepository? equipment,
    CylinderPassportRepository? passports,
    ServiceScheduleRepository? schedules,
  }) : _equipment = equipment ?? EquipmentRepository(),
       _passports = passports ?? CylinderPassportRepository(),
       _schedules = schedules ?? ServiceScheduleRepository();

  final EquipmentRepository _equipment;
  final CylinderPassportRepository _passports;
  final ServiceScheduleRepository _schedules;

  Future<EquipmentItem> adopt(
    GearTagPayload tag, {
    required String? diverId,
    required String fallbackName,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final item = await _equipment.transaction(() async {
      // Across the whole library: an item another diver still uses keeps
      // its tag. A retired or sold one (gear bought used) does not block.
      final holder = await _passports.findEquipmentIdByPassportId(
        tag.passportId,
      );
      if (holder != null &&
          ((await _equipment.getEquipmentById(holder))?.isFitted ?? false)) {
        throw PassportIdInUse(holder);
      }
      final created = await _equipment.createEquipment(
        EquipmentItem(
          id: '',
          diverId: diverId,
          name: tag.name ?? fallbackName,
          type: tag.type ?? EquipmentType.other,
          brand: tag.brand,
          model: tag.model,
          serialNumber: tag.serial,
        ),
        notify: false,
      );
      await _passports.assignPassportId(
        equipmentId: created.id,
        passportId: tag.passportId,
      );
      final last = tag.lastService;
      if (last != null) {
        for (final schedule in await _schedules.getSchedulesForEquipment(
          created.id,
        )) {
          await _schedules.updateSchedule(
            schedule.withBaseline(last, now: at, picked: true),
            notify: false,
          );
        }
      }
      return created;
    });
    SyncEventBus.notifyLocalChange();
    return (await _equipment.getEquipmentById(item.id)) ?? item;
  }
}
```

`gear_passport_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gear_passports/data/services/gear_adoption_service.dart';

final gearAdoptionServiceProvider = Provider<GearAdoptionService>(
  (ref) => GearAdoptionService(),
);
```

- [ ] **Step 4: Run**

Run: `flutter test test/features/gear_passports/data`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/gear_passports test/features/gear_passports
git commit -m "feat(gear-passports): add scanned gear to the diver's equipment"
```

### Task 9: English strings and the generic scan title

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (new keys after the last `passport_*` value key, metadata beside the `@passport_*` metadata block; remove `passport_scan_title`)
- Modify: the ten locale ARBs (remove `passport_scan_title` only; translations come in Task 18)
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart:166` and `scan_tag_menu_entries.dart:20` to use `tagScan_title`
- Test: `test/features/cylinder_passports/presentation/widgets/` scan sheet and menu tests that find the title text

**Interfaces:**
- Produces these generated getters (placeholders are `String` unless noted):

| Key | English |
| --- | --- |
| `tagScan_title` | Scan a tag |
| `gearPassport_title` | Gear passport |
| `gearPassport_entry_lastService` | Last serviced {date} |
| `gearPassport_entry_noService` | No service recorded |
| `gearPassport_recent_title` | Recent service |
| `gearPassport_recent_none` | No service recorded yet |
| `gearPassport_recent_seeAll` | See all |
| `gearPassport_unknownType` | Gear |
| `gearPassport_foreign_title` | Gear tag |
| `gearPassport_foreign_notInGear` | This gear is not in your library. |
| `gearPassport_foreign_addFailed` | Could not add the gear. Try again. |
| `gearPassport_field_lastService` | Last service date |
| `gearPassport_scan_action` | Scan |
| `gearPassport_scan_added` | Added {name} |
| `gearPassport_scan_alreadyOnDive` | {name} is already on this dive |
| `gearPassport_scan_alreadyOnTrip` | {name} is already on this trip |
| `gearPassport_scan_notYours` | Not in your gear |
| `gearPassport_scan_view` | View |
| `gearPassport_scan_wishlist` | {name} is on your wishlist |
| `trips_gear_add_scan` | Scan a tag |

Reused as they are: `passport_open`, `passport_tag_*`, `passport_nfc_*`, `passport_foreign_writtenOn`, `passport_foreign_addToGear`, `passport_foreign_serial`, `passport_scan_newerFormat`, `passport_trip_*`, `equipment_detail_brandLabel`, `equipment_detail_modelLabel`, `equipment_detail_serialNumberLabel`.

- [ ] **Step 1: Insert the keys with a script, by anchor line**

Write `$SCRATCH/add_gear_keys.py` (scratchpad) that, for `app_en.arb`, inserts the value lines after the line of `"passport_logFill_saveFailed"` and the `@` metadata for the six placeholder keys after the closing line of the `"@passport_trip_more"` block; builds each line as `'  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False))`; removes the `"passport_scan_title"` line (and its `@` block if present) from all eleven ARBs; and asserts `json.loads` succeeds on every file afterwards. `trips_gear_add_scan` goes after `"trips_gear_add_rental"` in `app_en.arb`. Metadata shape, one line each:

```json
  "@gearPassport_entry_lastService": {"placeholders": {"date": {"type": "String"}}},
```

Run it with `python3.14`, then:

```bash
git diff --numstat -- lib/l10n/arb
```

Expected: `app_en.arb` adds 26 lines and removes 1; each locale removes 1 and adds 0.

- [ ] **Step 2: Point the scan sheet and the menu at the new title**

`passport_scan_sheet.dart`: `l10n.passport_scan_title` becomes `l10n.tagScan_title`. `scan_tag_menu_entries.dart`: same. Update any test that finds `passport_scan_title` (`grep -rn passport_scan_title test lib`).

- [ ] **Step 3: Generate and analyze**

```bash
flutter gen-l10n
flutter analyze lib/features/cylinder_passports lib/l10n
```

Expected: no issues. (The locale files fall back to English for the new keys until Task 18 regenerates them.)

- [ ] **Step 4: Run the scan sheet and menu tests**

Run: `flutter test test/features/cylinder_passports/presentation test/features/equipment/presentation/pages/equipment_list_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n lib/features/cylinder_passports test/features
git commit -m "feat(gear-passports): strings for gear tags, and a generic scan title"
```

### Task 10: The NFC write sheet and Link an existing tag take any tag kind

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart`
- Modify: `lib/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart`
- Create: `lib/features/gear_passports/presentation/utils/gear_tag_write.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart` (unchanged API for cylinders; add a gear case)
- Test: `test/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog_test.dart` (if present; else create beside the sheet test)

**Interfaces:**
- Consumes: `TagNdefPlan`, `writeTagTo` (Task 3); `planGearMessage`, `GearTagCodec` (Tasks 1, 3).
- Produces:
  - `class TagWriteRequest { const TagWriteRequest({required String fullUrl, required TagNdefPlan? Function(int) planFor, required String Function(AppLocalizations, String) fieldLabel}); }`
  - `TagWriteRequest cylinderTagWriteRequest(CylinderPassportPayload payload)`
  - `Future<void> showTagWriteSheet(BuildContext context, {required TagWriteRequest request})`
  - `showNfcWriteSheet(context, payload:)` unchanged for cylinders, delegating.
  - `NfcWriteSheet({required TagWriteRequest request})`.
  - `TagWriteRequest gearTagWriteRequest(GearTagPayload payload)` and `String gearTagFieldLabel(AppLocalizations l10n, String key)` in `gear_tag_write.dart`.
  - `Future<String?> showLinkExistingTagDialog(BuildContext context, {required String equipmentId, String? diverId, String? Function(String text) passportIdOf = cylinderPassportIdOf})` resolving with the linked passport id; `String? cylinderPassportIdOf(String text)`; `String? gearPassportIdOf(String text)` in `gear_tag_write.dart`.

- [ ] **Step 1: Add the failing gear cases**

In `nfc_write_sheet_test.dart`, following the file's fake `NfcTagService` and `showNfcWriteSheet` harness, add a test that opens `showTagWriteSheet(context, request: gearTagWriteRequest(gear))` against a fake 137-byte tag and expects:
- the success text `l10n.passport_nfc_written`;
- the dropped-fields line naming `l10n.gearPassport_field_lastService` (the first key dropped);
- the fake tag's stored message's first URI equals `GearTagCodec.httpsUrl(plan payload)` and starts with `https://submersion.app/g#`.

For the link dialog, a test that pastes a gear link into the dialog opened with `passportIdOf: gearPassportIdOf` for a seeded regulator, taps Link, and expects `getPassportId(reg) == id`; and that pasting a cylinder link into that same dialog shows `l10n.passport_tag_linkInvalid`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`
Expected: FAIL (no `showTagWriteSheet`, no `gearTagWriteRequest`).

- [ ] **Step 3: Generalise the write sheet**

In `nfc_write_sheet.dart`:

```dart
/// Everything the write sheet needs about the tag it writes, whatever its
/// kind: the full link (noted as possibly on the tag when a write fails
/// part-way), how to fit it to a tag's capacity, and the readable name of a
/// key left off a small tag.
class TagWriteRequest {
  const TagWriteRequest({
    required this.fullUrl,
    required this.planFor,
    required this.fieldLabel,
  });

  final String fullUrl;
  final TagNdefPlan? Function(int maxMessageBytes) planFor;
  final String Function(AppLocalizations l10n, String key) fieldLabel;
}

/// A cylinder passport write: the full payload, never the label-bounded one.
TagWriteRequest cylinderTagWriteRequest(CylinderPassportPayload payload) =>
    TagWriteRequest(
      fullUrl: PassportPayloadCodec.httpsUrl(payload),
      planFor: (max) => planPassportMessage(payload, maxMessageBytes: max),
      fieldLabel: tagFieldLabel,
    );

Future<void> showNfcWriteSheet(
  BuildContext context, {
  required CylinderPassportPayload payload,
}) => showTagWriteSheet(context, request: cylinderTagWriteRequest(payload));

/// Writes [request]'s tag to an NFC tag (spec 13.3) and reports the tag
/// type, its capacity and which fields fit.
Future<void> showTagWriteSheet(
  BuildContext context, {
  required TagWriteRequest request,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (_) => NfcWriteSheet(request: request),
);
```

`NfcWriteSheet` takes `final TagWriteRequest request;`. In `_write`, `writePassportTo(tag, widget.payload)` becomes `writeTagTo(tag, widget.request.planFor)`. In `_noteHeld`:

```dart
    final written = switch (outcome) {
      TagWritten(:final plan) => plan.url,
      TagReadBackMismatch() || TagWriteFailed() => widget.request.fullUrl,
      TagNotNdef() || TagReadOnly() || TagTooSmall() => null,
    };
    if (written != null) recent.note(written);
```

In `build`, `.map((k) => tagFieldLabel(l10n, k))` becomes `.map((k) => widget.request.fieldLabel(l10n, k))`, and `written.plan.payload.fill != null` becomes `written.plan.includesFill`.

- [ ] **Step 4: Gear request and field labels**

`lib/features/gear_passports/presentation/utils/gear_tag_write.dart`:

```dart
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_ndef.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A readable name for a gear tag key left off a small tag.
String gearTagFieldLabel(AppLocalizations l10n, String key) => switch (key) {
  'ls' => l10n.gearPassport_field_lastService,
  'mo' => l10n.equipment_detail_modelLabel,
  'b' => l10n.equipment_detail_brandLabel,
  'sn' => l10n.equipment_detail_serialNumberLabel,
  'n' => l10n.passport_nfc_fieldName,
  _ => key,
};

TagWriteRequest gearTagWriteRequest(GearTagPayload payload) => TagWriteRequest(
  fullUrl: GearTagCodec.httpsUrl(payload),
  planFor: (max) => planGearMessage(payload, maxMessageBytes: max),
  fieldLabel: gearTagFieldLabel,
);

/// The passport id of a gear tag link, or null for anything else.
String? gearPassportIdOf(String text) => switch (TagLinkCodec.decode(text)) {
  GearTagLink(:final passportId) => passportId,
  _ => null,
};
```

- [ ] **Step 5: Generalise the link dialog**

In `link_existing_tag_dialog.dart` add:

```dart
/// The passport id of a cylinder tag link, or null for anything else.
String? cylinderPassportIdOf(String text) =>
    switch (PassportPayloadCodec.decode(text)) {
      PassportDecoded(:final payload) => payload.passportId,
      PassportRejected() => null,
    };
```

`showLinkExistingTagDialog` gains `String? Function(String text) passportIdOf = cylinderPassportIdOf`, returns `Future<String?>` (the linked id), and the state's `_link` reads:

```dart
    final passportId = widget.passportIdOf(_controller.text);
    if (passportId == null) {
      setState(() => _error = l10n.passport_tag_linkInvalid);
      return;
    }
```

then assigns `passportId` and pops it. The `fillsForEquipmentProvider` invalidation stays (harmless for gear). Update the doc comment: "Paste a tag's link to give this item that tag's passport id". Existing callers and tests that used the returned payload compare against the id instead.

- [ ] **Step 6: Run**

Run: `flutter test test/features/cylinder_passports/presentation test/features/gear_passports`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features test/features
git commit -m "feat(gear-passports): write and link gear tags"
```

### Task 11: Opening any scanned tag

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart` (`openScannedTag` routes every tag kind; `resolveScannedTag` stays cylinder-only)
- Create: `lib/features/gear_passports/presentation/utils/gear_routes.dart`
- Test: the existing `openScannedTag` test file (`grep -rl openScannedTag test`), plus gear cases

**Interfaces:**
- Consumes: `TagResolver`, `OwnTaggedItem`, `ForeignCylinderTag`, `ForeignGearTag`, `UnreadableTag` (Task 6); `CylinderPassportRepository.findHolderByPassportId` (Task 5); `importTagFill` (existing); `foreignPassportLocation` (existing).
- Produces:
  - `gear_routes.dart`: `String gearPassportLocation(String equipmentId) => '/equipment/$equipmentId/gear-passport';`, `String foreignGearLocation(GearTagPayload tag)`, `GearTagPayload? foreignGearTagFromQuery(String? t)`, `GearTagPayload? scannedGearTagFrom(Object? extra)`.
  - `Future<TagResolution> resolveAnyTag(WidgetRef ref, String text)` in `scan_cylinder_tag.dart`.
  - `openScannedTag` behaviour: own tank with a cylinder link imports the fill and opens `/equipment/<id>/passport` with the payload; own tank with a gear link opens the cylinder passport without extra; own non-tank opens `gearPassportLocation(id)` with the gear payload as extra (none for a cylinder link); foreign cylinder opens `foreignPassportLocation`; foreign gear opens `foreignGearLocation`; unreadable shows `passport_tag_linkInvalid`.

- [ ] **Step 1: Add the failing cases**

In the `openScannedTag` test file (it pumps a `GoRouter` with stub routes and records locations), add stub routes for `/equipment/:id/gear-passport` and `/equipment/gear-tag`, seed a regulator holding `id` through `CylinderPassportRepository().assignPassportId`, and assert:
- a `/g` link for it lands on `/equipment/reg/gear-passport` with a `GearTagPayload` extra;
- a `/g` link for an unknown id lands on a location starting with `/equipment/gear-tag?t=`;
- the existing cylinder cases are unchanged.

`gear_routes` unit tests: `foreignGearTagFromQuery(Uri.parse(foreignGearLocation(tag)).queryParameters['t'])` round trips `tag`; `foreignGearTagFromQuery('nope')` and `scannedGearTagFrom(42)` are null.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test <openScannedTag test file> test/features/gear_passports/presentation/utils/gear_routes_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the routes helper**

```dart
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

String gearPassportLocation(String equipmentId) =>
    '/equipment/$equipmentId/gear-passport';

/// Where a gear tag the diver does not hold opens. The tag rides in the
/// query so the page survives a restart; its payload is public by design.
String foreignGearLocation(GearTagPayload tag) => Uri(
  path: '/equipment/gear-tag',
  queryParameters: {'t': GearTagCodec.httpsUrl(tag)},
).toString();

GearTagPayload? foreignGearTagFromQuery(String? t) {
  if (t == null) return null;
  final decoded = GearTagCodec.decode(t);
  return decoded is GearTagDecoded ? decoded.payload : null;
}

/// The scanned gear tag a route carried, or null for any other extra.
GearTagPayload? scannedGearTagFrom(Object? extra) =>
    extra is GearTagPayload ? extra : null;
```

- [ ] **Step 4: Route every tag kind in `openScannedTag`**

```dart
/// Resolves [text] against every item the active diver can see.
Future<TagResolution> resolveAnyTag(WidgetRef ref, String text) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final repository = ref.read(cylinderPassportRepositoryProvider);
  return TagResolver(
    findHolder: (passportId) =>
        repository.findHolderByPassportId(passportId, diverId: diverId),
  ).resolve(text);
}
```

and the `switch` in `openScannedTag` becomes:

```dart
    final resolution = await resolveAnyTag(ref, text);
    if (!context.mounted) return;
    switch (resolution) {
      case OwnTaggedItem(:final equipmentId, :final type, :final link)
          when type == EquipmentType.tank:
        final tag = link is CylinderTagLink ? link.payload : null;
        if (tag != null) {
          // The fill the tag carries joins the history once (spec section 11).
          final added = await importTagFill(
            ref,
            tag: tag,
            equipmentId: equipmentId,
          );
          if (!context.mounted) return;
          if (added != null) {
            final units = UnitFormatter(ref.read(settingsProvider));
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n.passport_fill_addedFromTag(
                    fillSummary(added.gasMix, added.pressureBar, units),
                  ),
                ),
              ),
            );
          }
        }
        router.push('/equipment/$equipmentId/passport', extra: tag);
      case OwnTaggedItem(:final equipmentId, :final link):
        router.push(
          gearPassportLocation(equipmentId),
          extra: link is GearTagLink ? link.payload : null,
        );
      case ForeignCylinderTag(:final tag):
        router.push(foreignPassportLocation(tag));
      case ForeignGearTag(:final tag):
        router.push(foreignGearLocation(tag));
      case UnreadableTag():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.passport_tag_linkInvalid)),
        );
    }
```

Rename `scanAndOpenCylinderTag` to `scanAndOpenTag` (update `equipment_list_page.dart` and `equipment_list_content.dart` callers found by `grep -rn scanAndOpenCylinderTag lib test`).

- [ ] **Step 5: Run**

Run: `flutter test test/features/cylinder_passports test/features/gear_passports test/features/equipment/presentation`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features test/features
git commit -m "feat(gear-passports): open any scanned tag on the right page"
```

### Task 12: The gear passport page and its entry card

**Files:**
- Create: `lib/features/gear_passports/presentation/pages/gear_passport_page.dart`
- Create: `lib/features/gear_passports/presentation/widgets/gear_passport_header.dart`
- Create: `lib/features/gear_passports/presentation/widgets/gear_recent_service_card.dart`
- Create: `lib/features/gear_passports/presentation/widgets/gear_tag_card.dart`
- Create: `lib/features/gear_passports/presentation/widgets/gear_passport_entry_card.dart`
- Modify: `lib/features/equipment/presentation/widgets/service_record_dialog.dart` (add `showLogServiceDialog`)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:225-228, 801-818`
- Modify: `lib/core/router/app_router.dart` (child route `gear-passport` under `:equipmentId`)
- Test: `test/features/gear_passports/presentation/pages/gear_passport_page_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_passport_card_test.dart` (the regulator case flips)

**Interfaces:**
- Consumes: `passportIdProvider`, `cylinderPassportRepositoryProvider` (existing); `serviceRecordsForEquipmentProvider`, `serviceClockStatusesProvider`, `equipmentItemProvider`, `allServiceKindsByIdProvider`, `serviceKindsProvider` (existing); `gearPayloadForItem`, `lastServiceDate`, `gearTagIsStale` (Task 7); `GearTagCodec.httpsUrl` (Task 1); `showTagWriteSheet`, `gearTagWriteRequest`, `showLinkExistingTagDialog`, `gearPassportIdOf` (Task 10); `PassportQrView`, `nfcSupportProvider`, `nfcUnavailableReason`, `ServiceClocksCard`, `ExposureCard`, `EquipmentLocationCard`, `PassportTripCard`, `EquipmentOwnerChip` (existing); `scannedGearTagFrom`, `gearPassportLocation` (Task 11); `printPassportLabels` (Task 14 extends it to gear; until then the Print button is wired and prints nothing for gear).
- Produces: `GearPassportPage({required String equipmentId, GearTagPayload? scannedTag})`; `GearPassportEntryCard({required EquipmentItem equipment})`; `showLogServiceDialog(BuildContext, WidgetRef, {required String equipmentId, String? serviceKindId})`.

- [ ] **Step 1: Write the failing page tests**

Harness as in `equipment_detail_passport_card_test.dart` (base overrides, `GoRouter`, `locale: Locale('en')`), with the route `/equipment/:id/gear-passport` building `GearPassportPage(equipmentId: id, scannedTag: scannedGearTagFrom(state.extra))` and a stub `/equipment/:id` route. Overrides: `equipmentItemProvider(id)`, `passportIdProvider(id)` returning a fixed UUID, `serviceRecordsForEquipmentProvider(id)`, `serviceClockStatusesProvider(id)` (empty), `nfcSupportProvider` returning `NfcSupport.unsupported`. Cases:

```dart
  testWidgets('shows the header, cards and tag for a regulator', (tester) async {
    final l10n = await pump(tester, regulator, records: [record(DateTime(2026, 3, 2))]);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text(l10n.gearPassport_recent_title), findsOneWidget);
    expect(find.text(l10n.passport_tag_title), findsOneWidget);
    expect(find.byType(PassportQrView), findsOneWidget);
    expect(find.byType(ServiceClocksCard), findsOneWidget);
    expect(find.byType(ExposureCard), findsOneWidget);
    expect(find.byType(EquipmentLocationCard), findsOneWidget);
    expect(find.byType(PassportTripCard), findsOneWidget);
  });

  testWidgets('no service yet says so', (tester) async {
    final l10n = await pump(tester, regulator, records: const []);
    expect(find.text(l10n.gearPassport_recent_none), findsOneWidget);
  });

  testWidgets('a scanned tag older than the newest service is stale', (tester) async {
    final l10n = await pump(
      tester,
      regulator,
      records: [record(DateTime(2026, 10, 11))],
      scanned: GearTagPayload(
        passportId: pid,
        typeCode: 'regulator',
        writtenOn: DateTime(2026, 10, 1),
        name: 'Primary',
      ),
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
  });

  testWidgets('a wishlist item has no tag card', (tester) async {
    final l10n = await pump(
      tester,
      regulator.copyWith(status: EquipmentStatus.wanted),
      records: const [],
    );
    expect(find.text(l10n.passport_tag_title), findsNothing);
  });

  testWidgets('a tank id shows the cylinder passport', (tester) async {
    await pump(tester, tank, records: const []);
    expect(find.byType(PassportPage), findsOneWidget);
  });

  testWidgets('recent service lists at most three, newest first', (tester) async {
    await pump(tester, regulator, records: [
      for (var m = 1; m <= 5; m++) record(DateTime(2026, m, 1)),
    ]);
    expect(find.byKey(const Key('gearRecentService_row')), findsNWidgets(3));
  });
```

In `equipment_detail_passport_card_test.dart`, rename `'a regulator does not'` to `'a regulator shows the gear passport entry card'` and expect `find.byType(PassportEntryCard)` nothing and `find.byType(GearPassportEntryCard)` one, plus `find.text(l10n.gearPassport_entry_noService)`; add `serviceRecordsForEquipmentProvider(item.id).overrideWith((ref) async => [])` to the harness. Add a wishlist regulator case expecting no `GearPassportEntryCard`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/gear_passports/presentation/pages/gear_passport_page_test.dart test/features/equipment/presentation/pages/equipment_detail_passport_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: `showLogServiceDialog`**

Append to `service_record_dialog.dart`:

```dart
/// Logs a service for [equipmentId], fulfilling [serviceKindId]'s clock when
/// given: the detail page's Log service and the gear passport's share it.
Future<void> showLogServiceDialog(
  BuildContext context,
  WidgetRef ref, {
  required String equipmentId,
  String? serviceKindId,
}) => showDialog<void>(
  context: context,
  builder: (context) => ServiceRecordDialog(
    equipmentId: equipmentId,
    serviceKindId: serviceKindId,
    onSave: (record) => ref
        .read(serviceRecordNotifierProvider(equipmentId).notifier)
        .addRecord(record),
  ),
);
```

and make the detail page's `_showAddServiceDialogForKind` call it.

- [ ] **Step 4: Header and recent service**

`gear_passport_header.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Name, type, brand and model, serial, and the owner when shared.
class GearPassportHeader extends StatelessWidget {
  const GearPassportHeader({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final makeModel = [
      if (equipment.brand?.trim().isNotEmpty ?? false) equipment.brand!.trim(),
      if (equipment.model?.trim().isNotEmpty ?? false) equipment.model!.trim(),
    ].join(' ');
    final serial = equipment.serialNumber?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(equipment.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: Icon(equipmentTypeIcon(equipment.type), size: 18),
              label: Text(equipment.type.localizedName(l10n)),
              visualDensity: VisualDensity.compact,
            ),
            EquipmentOwnerChip(equipment: equipment),
          ],
        ),
        if (makeModel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(makeModel, style: theme.textTheme.titleMedium),
        ],
        if (serial != null && serial.isNotEmpty)
          Text(
            l10n.passport_foreign_serial(serial),
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}
```

(Check `EquipmentOwnerChip`'s constructor; it renders nothing for the diver's own gear. If it needs other arguments, pass what the detail page passes.)

`gear_recent_service_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest three service records, and See all on the detail page.
class GearRecentServiceCard extends ConsumerWidget {
  const GearRecentServiceCard({super.key, required this.equipmentId});

  static const int shown = 3;

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final records = [
      ...?ref.watch(serviceRecordsForEquipmentProvider(equipmentId)).value,
    ]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    final kindsById = <String, ServiceKind>{
      ...?ref.watch(allServiceKindsByIdProvider).value,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.gearPassport_recent_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (records.isNotEmpty)
                  TextButton(
                    onPressed: () => context.push('/equipment/$equipmentId'),
                    child: Text(l10n.gearPassport_recent_seeAll),
                  ),
              ],
            ),
            if (records.isEmpty)
              Text(l10n.gearPassport_recent_none)
            else
              for (final ServiceRecord r in records.take(shown))
                ListTile(
                  key: const Key('gearRecentService_row'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    kindsById[r.serviceKindId]?.name ??
                        r.serviceCategory.label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      units.formatDate(r.serviceDate),
                      if (r.provider?.trim().isNotEmpty ?? false)
                        r.provider!.trim(),
                    ].join(' · '),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
```

(`ServiceCategory.label(l10n)` is the extension the service history tile uses; import its file.)

- [ ] **Step 5: The gear Tag card**

`gear_tag_card.dart`, mirroring `PassportTagCard` without fills:

```dart
/// QR of the current gear tag, print and link actions, NFC write, and the
/// stale hint when a scanned tag no longer matches (gear tag spec 9).
class GearTagCard extends ConsumerWidget {
  const GearTagCard({
    super.key,
    required this.equipment,
    this.scannedTag,
    this.onPrintLabel,
  });

  final EquipmentItem equipment;
  final GearTagPayload? scannedTag;
  final Future<void> Function(BuildContext buttonContext)? onPrintLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
        const <ServiceRecord>[];
    final last = lastServiceDate(records);
    final payload = passportId == null
        ? null
        : gearPayloadForItem(
            item: equipment,
            passportId: passportId,
            now: DateTime.now(),
            lastService: last,
          );
    final nfc = ref.watch(nfcSupportProvider).value;
    final canWriteNfc = payload != null && nfc == NfcSupport.enabled;
    final scanned = scannedTag;
    final stale =
        scanned != null &&
        gearTagIsStale(tag: scanned, item: equipment, lastService: last);
    final warn = StatusColors.of(context).warn;
    void write() =>
        showTagWriteSheet(context, request: gearTagWriteRequest(payload!));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.passport_tag_title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (payload != null)
              Center(
                child: PassportQrView(
                  data: GearTagCodec.httpsUrl(payload),
                  semanticLabel: l10n.passport_tag_qrSemantics,
                  size: 200,
                ),
              ),
            if (scanned?.writtenOn case final written?) ...[
              const SizedBox(height: 8),
              Text(l10n.passport_tag_written(units.formatDate(written))),
            ],
            if (stale) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warn.container,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: warn.onContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.passport_tag_stale,
                            style: TextStyle(color: warn.onContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const Key('gearTag_rewrite'),
                          onPressed: canWriteNfc ? write : null,
                          child: Text(l10n.passport_nfc_rewrite),
                        ),
                        Builder(
                          builder: (b) => TextButton(
                            key: const Key('gearTag_reprint'),
                            onPressed: payload == null || onPrintLabel == null
                                ? null
                                : () => onPrintLabel!(b),
                            child: Text(l10n.passport_nfc_reprint),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Builder(
                  builder: (b) => FilledButton.tonalIcon(
                    onPressed: payload == null || onPrintLabel == null
                        ? null
                        : () => onPrintLabel!(b),
                    icon: const Icon(Icons.print),
                    label: Text(l10n.passport_tag_printLabel),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final diverId = await ref.read(
                      validatedCurrentDiverIdProvider.future,
                    );
                    if (!context.mounted) return;
                    final linked = await showLinkExistingTagDialog(
                      context,
                      equipmentId: equipment.id,
                      diverId: diverId,
                      passportIdOf: gearPassportIdOf,
                    );
                    if (linked != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passport_tag_linked)),
                      );
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: Text(l10n.passport_tag_linkExisting),
                ),
                OutlinedButton.icon(
                  key: const Key('gearTag_writeNfc'),
                  onPressed: canWriteNfc ? write : null,
                  icon: const Icon(Icons.nfc),
                  label: Text(l10n.passport_nfc_write),
                ),
              ],
            ),
            if (nfcUnavailableReason(l10n, nfc) case final reason?) ...[
              const SizedBox(height: 4),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
```

(Imports: the ones `passport_tag_card.dart` uses, plus the gear codec, rules, payload and `gear_tag_write.dart`.)

- [ ] **Step 6: The page**

```dart
/// One item's gear passport (gear tag spec 9). A tank shows the cylinder
/// passport instead, so a stale link or a retyped item never lands on the
/// wrong page.
class GearPassportPage extends ConsumerStatefulWidget {
  const GearPassportPage({super.key, required this.equipmentId, this.scannedTag});

  final String equipmentId;
  final GearTagPayload? scannedTag;

  @override
  ConsumerState<GearPassportPage> createState() => _GearPassportPageState();
}

class _GearPassportPageState extends ConsumerState<GearPassportPage> {
  static final _log = LoggerService.forClass(GearPassportPage);

  @override
  void initState() {
    super.initState();
    // Minted on first open, as the cylinder passport does; every await is
    // followed by a mounted check, and a failure is logged.
    Future<void>.microtask(_mintIfNeeded);
  }

  Future<void> _mintIfNeeded() async {
    final id = widget.equipmentId;
    try {
      final existing = await ref.read(passportIdProvider(id).future);
      if (existing != null || !mounted) return;
      final item = await ref.read(equipmentItemProvider(id).future);
      if (!mounted ||
          item == null ||
          item.type == EquipmentType.tank ||
          item.isWanted) {
        return;
      }
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (!mounted) return;
      await ref
          .read(cylinderPassportRepositoryProvider)
          .ensurePassportId(id, diverId: diverId);
      if (mounted) ref.invalidate(passportIdProvider(id));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mint a passport id for $id',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _printLabel(String equipmentId, BuildContext button) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedText = context.l10n.passport_tag_printFailed;
    try {
      await printPassportLabels(context, ref, [equipmentId], anchor: button);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to print the label for $equipmentId',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));
    return equipmentAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.gearPassport_title)),
        body: Center(child: Text(e.toString())),
      ),
      data: (equipment) {
        if (equipment != null && equipment.type == EquipmentType.tank) {
          return PassportPage(equipmentId: equipment.id);
        }
        return Scaffold(
          appBar: AppBar(title: Text(l10n.gearPassport_title)),
          body: equipment == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GearPassportHeader(equipment: equipment),
                      const SizedBox(height: 16),
                      if (!equipment.isWanted) ...[
                        ServiceClocksCard(
                          equipmentId: equipment.id,
                          equipmentType: equipment.type,
                          onLogService: (status) => showLogServiceDialog(
                            context,
                            ref,
                            equipmentId: equipment.id,
                            serviceKindId: status.kind.id,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      GearRecentServiceCard(equipmentId: equipment.id),
                      const SizedBox(height: 16),
                      ExposureCard(equipmentId: equipment.id),
                      const SizedBox(height: 16),
                      EquipmentLocationCard(equipment: equipment),
                      const SizedBox(height: 16),
                      PassportTripCard(equipmentId: equipment.id),
                      if (!equipment.isWanted) ...[
                        const SizedBox(height: 16),
                        GearTagCard(
                          equipment: equipment,
                          scannedTag: widget.scannedTag,
                          onPrintLabel: (b) => _printLabel(equipment.id, b),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}
```

- [ ] **Step 7: Entry card, detail page and route**

`gear_passport_entry_card.dart`:

```dart
/// The detail page's doorway to a gear passport: the QR once the item has a
/// passport id, the last service date, and Open passport.
class GearPassportEntryCard extends ConsumerWidget {
  const GearPassportEntryCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final passportId = ref.watch(passportIdProvider(equipment.id)).value;
    final records =
        ref.watch(serviceRecordsForEquipmentProvider(equipment.id)).value ??
        const <ServiceRecord>[];
    final last = lastServiceDate(records);
    final location = gearPassportLocation(equipment.id);
    return Card(
      child: InkWell(
        onTap: () => context.push(location),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (passportId != null)
                PassportQrView(
                  data: GearTagCodec.httpsUrl(
                    gearPayloadForItem(
                      item: equipment,
                      passportId: passportId,
                      now: DateTime.now(),
                      lastService: last,
                    ),
                  ),
                  semanticLabel: l10n.passport_tag_qrSemantics,
                  size: 72,
                )
              else
                const Icon(Icons.qr_code_2, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gearPassport_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      last == null
                          ? l10n.gearPassport_entry_noService
                          : l10n.gearPassport_entry_lastService(
                              units.formatDate(last),
                            ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(location),
                child: Text(l10n.passport_open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Detail page, where the tank card is:

```dart
          if (equipment.type == EquipmentType.tank) ...[
            PassportEntryCard(equipment: equipment),
            const SizedBox(height: 24),
          ] else if (!equipment.isWanted) ...[
            GearPassportEntryCard(equipment: equipment),
            const SizedBox(height: 24),
          ],
```

Router, after the `passport` child route:

```dart
                  // Any other gear's tag page (issue #2652).
                  GoRoute(
                    path: 'gear-passport',
                    name: 'gearPassport',
                    builder: (context, state) => GearPassportPage(
                      equipmentId: state.pathParameters['equipmentId']!,
                      scannedTag: scannedGearTagFrom(state.extra),
                    ),
                  ),
```

- [ ] **Step 8: Run**

Run: `flutter test test/features/gear_passports test/features/equipment/presentation`
Expected: PASS.

- [ ] **Step 9: Guards and commit**

```bash
dart format lib test
flutter analyze
flutter test test/architecture test/shared
git add lib test
git commit -m "feat(gear-passports): gear passport page and detail page entry card"
```

### Task 13: The foreign gear page

**Files:**
- Create: `lib/features/gear_passports/presentation/pages/foreign_gear_page.dart`
- Modify: `lib/core/router/app_router.dart` (route `gear-tag` beside `tag`, before `:equipmentId`)
- Test: `test/features/gear_passports/presentation/pages/foreign_gear_page_test.dart`

**Interfaces:**
- Consumes: `GearTagPayload` (Task 1); `gearAdoptionServiceProvider` (Task 8); `foreignGearTagFromQuery`, `gearPassportLocation` (Task 11); `PassportIdInUse`.
- Produces: `ForeignGearPage({required GearTagPayload? tag, bool newerFormat = false})`.

- [ ] **Step 1: Write the failing tests**

Harness: `GoRouter` with `/equipment/gear-tag` building `ForeignGearPage(tag: foreignGearTagFromQuery(...))` and a stub `/equipment/:id/gear-passport`; `gearAdoptionServiceProvider` overridden with a fake whose `adopt` records the tag and returns an `EquipmentItem(id: 'new', ...)`, or throws `PassportIdInUse('held')`; `equipmentRepositoryProvider`'s `getEquipmentById('held')` available through the test database seed. Cases:
- shows type label (`EquipmentType.regulator.localizedName(l10n)`), name, brand and model, serial, `l10n.gearPassport_entry_lastService(date)` and `l10n.passport_foreign_writtenOn(date)`;
- an unknown type shows `l10n.gearPassport_unknownType`;
- Add to my gear calls `adopt` with the tag and `fallbackName` equal to the type label, then lands on `/equipment/new/gear-passport`;
- a held id shows `l10n.passport_tag_linkInUse('Held reg')`;
- a null tag shows `l10n.passport_tag_linkInvalid` and no Add button.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/gear_passports/presentation/pages/foreign_gear_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
/// A read-only snapshot built from a gear tag alone (gear tag spec 10): what
/// the tag said when it was written, for gear that is not the diver's.
class ForeignGearPage extends ConsumerStatefulWidget {
  const ForeignGearPage({super.key, required this.tag, this.newerFormat = false});

  final GearTagPayload? tag;
  final bool newerFormat;

  @override
  ConsumerState<ForeignGearPage> createState() => _ForeignGearPageState();
}

class _ForeignGearPageState extends ConsumerState<ForeignGearPage> {
  static final _log = LoggerService.forClass(ForeignGearPage);
  bool _busy = false;

  String _typeLabel(GearTagPayload tag) =>
      tag.type?.localizedName(context.l10n) ?? context.l10n.gearPassport_unknownType;

  Future<void> _addToGear(GearTagPayload tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    final fallbackName = _typeLabel(tag);
    setState(() => _busy = true);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final item = await ref
          .read(gearAdoptionServiceProvider)
          .adopt(tag, diverId: diverId, fallbackName: fallbackName);
      if (!mounted) return;
      router.pushReplacement(gearPassportLocation(item.id));
    } on PassportIdInUse catch (e) {
      final holder = await ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(e.equipmentId);
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.passport_tag_linkInUse(holder?.name ?? e.equipmentId)),
        ),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to add scanned gear', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gearPassport_foreign_addFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final tag = widget.tag;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gearPassport_foreign_title)),
      body: tag == null
          ? Center(child: Text(l10n.passport_tag_linkInvalid))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tag.name ?? _typeLabel(tag),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      avatar: Icon(
                        tag.type == null
                            ? Icons.inventory_2_outlined
                            : equipmentTypeIcon(tag.type!),
                        size: 18,
                      ),
                      label: Text(_typeLabel(tag)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if ([tag.brand, tag.model].whereType<String>().isNotEmpty)
                    Text(
                      [tag.brand, tag.model].whereType<String>().join(' '),
                      style: theme.textTheme.titleMedium,
                    ),
                  if (tag.serial case final serial?)
                    Text(l10n.passport_foreign_serial(serial)),
                  if (tag.lastService case final last?) ...[
                    const SizedBox(height: 12),
                    Text(l10n.gearPassport_entry_lastService(units.formatDate(last))),
                  ],
                  if (tag.writtenOn case final written?)
                    Text(
                      l10n.passport_foreign_writtenOn(units.formatDate(written)),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (widget.newerFormat) ...[
                    const SizedBox(height: 8),
                    Text(l10n.passport_scan_newerFormat),
                  ],
                  const SizedBox(height: 16),
                  Text(l10n.gearPassport_foreign_notInGear),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _addToGear(tag),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.passport_foreign_addToGear),
                  ),
                ],
              ),
            ),
    );
  }
}
```

Router, after the existing `tag` route:

```dart
              // A scanned gear tag the diver does not hold (issue #2652).
              // Before ':equipmentId' so 'gear-tag' is never read as an id.
              GoRoute(
                path: 'gear-tag',
                name: 'foreignGearTag',
                builder: (context, state) => ForeignGearPage(
                  tag: foreignGearTagFromQuery(state.uri.queryParameters['t']),
                ),
              ),
```

In `openScannedTag` (Task 11), `ForeignGearTag(:final tag, :final newerFormat)` pushes `foreignGearLocation(tag)`; the page recomputes `newerFormat` from the query by decoding, so pass `newerFormat: (GearTagCodec.decode(t) as GearTagDecoded?)?.newerFormat ?? false` in the route builder through a helper `foreignGearNewerFormat(String? t)` added to `gear_routes.dart`.

- [ ] **Step 4: Run, guard, commit**

```bash
flutter test test/features/gear_passports
dart format lib test
flutter analyze
git add lib test
git commit -m "feat(gear-passports): read-only page for someone else's gear tag"
```

### Task 14: Labels for any gear

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/utils/print_passport_labels.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart:612-614` (`isEnabled`)
- Test: the existing `printPassportLabels` test (`grep -rl printPassportLabels test`) and the list bulk-action test

**Interfaces:**
- Consumes: `gearPayloadForItem`, `lastServiceDate` (Task 7); `GearTagCodec.httpsUrl` (Task 1); `PassportLabelData` (existing).
- Produces: `printPassportLabels(context, ref, ids, {anchor, export})` builds one label per selected item that is not on the wishlist, in selection order: the cylinder label for tanks (unchanged), and a gear label (`title` name, `subtitle` brand and model, `specLine` type label and serial, `url` the gear link) for any other type. Exports nothing when nothing qualifies.

- [ ] **Step 1: Add the failing cases**

With the file's `export` capture:

```dart
  testWidgets('a mixed selection prints both kinds, in order', (tester) async {
    // Seed a regulator 'reg' (brand Apeks, model XTX50, serial AB1) and a
    // tank 'tank'; select ['reg', 'tank'].
    // Expect two labels: labels[0].url starts with 'https://submersion.app/g#',
    // labels[0].title == 'Primary', labels[0].subtitle == 'Apeks XTX50',
    // labels[0].specLine contains the regulator type label and 'AB1';
    // labels[1].url starts with 'https://submersion.app/c#'.
  });

  testWidgets('wishlist items are skipped', (tester) async {
    // A selection of one wishlist regulator exports nothing.
  });
```

Write both in full with the existing test's seeding helpers; the expectations are exactly the ones in the comments. Also, in the gear label test, decode the label's QR the way the existing cylinder label PDF test does and expect the gear URL.

In the list bulk-action test, expect Print labels enabled for a selection of a regulator and a tank, and disabled for a selection containing a wishlist item.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test <print labels test> <list bulk action test>`
Expected: FAIL (gear is skipped, the action needs all tanks).

- [ ] **Step 3: Implement**

In `printPassportLabels`, replace the `tanks` filter with:

```dart
  final items = [
    for (final id in equipmentIds)
      if (byId[id] case final item? when !item.isWanted) item,
  ];
  if (items.isEmpty || !context.mounted) return;
  final itemIds = [for (final i in items) i.id];
  final recordsById = await ref
      .read(serviceRecordRepositoryProvider)
      .getRecordsForEquipmentIds(itemIds);
  if (!context.mounted) return;
  final tankIds = [
    for (final i in items)
      if (i.type == EquipmentType.tank) i.id,
  ];
```

keep the clocks only for `tankIds`, and loop `for (final item in items)`: when `item.type == EquipmentType.tank` build the cylinder label exactly as now; otherwise:

```dart
      final passportId = stored != null && stored.trim().isNotEmpty
          ? stored.trim()
          : await passportRepo.ensurePassportId(item.id, diverId: diverId);
      final payload = gearPayloadForItem(
        item: item,
        passportId: passportId,
        now: now,
        lastService: lastServiceDate(recordsById[item.id] ?? const []),
      );
      labels.add(
        PassportLabelData(
          title: item.name,
          subtitle: [
            if (item.brand?.trim().isNotEmpty ?? false) item.brand!.trim(),
            if (item.model?.trim().isNotEmpty ?? false) item.model!.trim(),
          ].join(' '),
          specLine: [
            item.type.localizedName(l10n),
            if (item.serialNumber?.trim().isNotEmpty ?? false)
              item.serialNumber!.trim(),
          ].join(', '),
          url: GearTagCodec.httpsUrl(payload),
        ),
      );
```

Update the doc comment: "Builds one label per selected item not on the wishlist: the cylinder label for a tank, the gear label for anything else (issue #2652)". In `equipment_list_content.dart`:

```dart
        isEnabled: (ids) => everyChecked(ids, (e) => !e.isWanted),
```

- [ ] **Step 4: Run, commit**

```bash
flutter test <print labels test> <list bulk action test> test/core/services/export/pdf
dart format lib test
git add lib test
git commit -m "feat(gear-passports): print labels for any gear"
```

### Task 15: Scan gear onto a dive

**Files:**
- Create: `lib/features/gear_passports/presentation/utils/scan_owned_item.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_equipmentChild` actions; new `_scanGear`)
- Test: `test/features/gear_passports/presentation/utils/scan_owned_item_test.dart`
- Test: a dive edit widget test for the Scan action (beside the existing dive edit equipment tests, `grep -rl "diveLog_edit_useSet" test`)

**Interfaces:**
- Consumes: `passportScanLauncherProvider` (existing); `resolveAnyTag` (Task 11); `importTagFill`; `equipmentRepositoryProvider.getEquipmentById`; `foreignPassportLocation`, `foreignGearLocation` (Task 11).
- Produces: `Future<EquipmentItem?> scanOwnedItem(BuildContext context, WidgetRef ref)`: opens the scan sheet, resolves, and returns the diver's own item, or null after telling the diver why (`gearPassport_scan_notYours` with a View action that pushes the foreign page; `gearPassport_scan_wishlist(name)`; `passport_tag_linkInvalid`; `passport_scan_openFailed` on an error). A cylinder tag on an own tank imports its fill.

- [ ] **Step 1: Write the failing tests**

`scan_owned_item_test.dart`: pump a minimal page with a button that calls `scanOwnedItem` and stores the result; override `passportScanLauncherProvider` with `(context) async => text`; seed a regulator `reg` (`passport_id` assigned), a wishlist regulator `wish`, and use the test database. Cases:
- own `/g` link returns `reg`;
- own `/c` link on a seeded tank returns the tank;
- unknown id returns null and shows `l10n.gearPassport_scan_notYours`, and tapping `l10n.gearPassport_scan_view` lands on `/equipment/gear-tag?...`;
- wishlist item returns null and shows `l10n.gearPassport_scan_wishlist('Wish')`;
- `'hello'` returns null and shows `l10n.passport_tag_linkInvalid`;
- launcher returning null returns null and shows nothing.

Dive edit test: with the launcher returning a seeded regulator's link, tap the Scan overline action (`find.text(l10n.gearPassport_scan_action)`) and expect the regulator's name in the equipment section and `l10n.gearPassport_scan_added('Primary')`; scanning it again shows `l10n.gearPassport_scan_alreadyOnDive('Primary')` and the name still appears once in the equipment list.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/gear_passports/presentation/utils/scan_owned_item_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `scanOwnedItem`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/import_tag_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_resolver.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('scanOwnedItem');

/// Scans a tag and returns the diver's own item it names, cylinder or other
/// gear, for a flow that adds the item somewhere (a dive, a trip). Returns
/// null after telling the diver why not: someone else's gear (with View),
/// a wishlist item, or text that is no tag.
Future<EquipmentItem?> scanOwnedItem(BuildContext context, WidgetRef ref) async {
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final l10n = context.l10n;
  try {
    final resolution = await resolveAnyTag(ref, text);
    if (!context.mounted) return null;
    switch (resolution) {
      case OwnTaggedItem(:final equipmentId, :final type, :final link):
        if (type == EquipmentType.tank && link is CylinderTagLink) {
          await importTagFill(ref, tag: link.payload, equipmentId: equipmentId);
        }
        final item = await ref
            .read(equipmentRepositoryProvider)
            .getEquipmentById(equipmentId);
        if (item == null || !context.mounted) return null;
        if (item.isWanted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.gearPassport_scan_wishlist(item.name))),
          );
          return null;
        }
        return item;
      case ForeignCylinderTag(:final tag):
        _notYours(messenger, l10n.gearPassport_scan_notYours,
            l10n.gearPassport_scan_view, () => router.push(foreignPassportLocation(tag)));
      case ForeignGearTag(:final tag):
        _notYours(messenger, l10n.gearPassport_scan_notYours,
            l10n.gearPassport_scan_view, () => router.push(foreignGearLocation(tag)));
      case UnreadableTag():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.passport_tag_linkInvalid)),
        );
    }
  } catch (e, stackTrace) {
    _log.error('Failed to scan an item', error: e, stackTrace: stackTrace);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passport_scan_openFailed)),
      );
    }
  }
  return null;
}

void _notYours(
  ScaffoldMessengerState messenger,
  String text,
  String viewLabel,
  VoidCallback view,
) => messenger.showSnackBar(
  SnackBar(
    content: Text(text),
    action: SnackBarAction(label: viewLabel, onPressed: view),
  ),
);
```

- [ ] **Step 4: The dive edit Scan action**

In `_equipmentChild`, after the Add action:

```dart
            FormOverlineAction(
              label: context.l10n.gearPassport_scan_action,
              icon: Icons.qr_code_scanner,
              onPressed: _scanGear,
            ),
```

and beside `_showEquipmentPicker`:

```dart
  /// Adds the item a scanned tag names to this dive's gear, through the
  /// same path as the picker so components expand (issue #2652).
  Future<void> _scanGear() async {
    final item = await scanOwnedItem(context, ref);
    if (item == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (_selectedEquipment.any((e) => e.id == item.id)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gearPassport_scan_alreadyOnDive(item.name))),
      );
      return;
    }
    await _addGear([item]);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.gearPassport_scan_added(item.name))),
    );
  }
```

(Check `_addGear`'s signature at `dive_edit_page.dart:~4190` and pass `markDirty` the way the picker's call does.)

- [ ] **Step 5: Run, commit**

```bash
flutter test test/features/gear_passports test/features/dive_log/presentation/pages
dart format lib test
flutter analyze
git add lib test
git commit -m "feat(gear-passports): scan gear onto a dive"
```

### Task 16: Scan gear onto a trip

**Files:**
- Modify: `lib/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart`
- Test: the trip gear add sheet test (`grep -rl showTripGearAddSheet test`)

**Interfaces:**
- Consumes: `scanOwnedItem` (Task 15); `_apply` (existing, private in the file).
- Produces: a fourth chooser entry `trips_gear_add_scan` (`Icons.qr_code_scanner`) that packs a scanned own item, or slots a scanned own tank on the cylinder board; an item already packed, or a tank already on the board, shows `gearPassport_scan_alreadyOnTrip(name)`; otherwise `gearPassport_scan_added(name)`.

- [ ] **Step 1: Add the failing cases**

With the existing test's harness and a launcher override:
- scanning a seeded regulator packs it (`tripEquipmentRepository` lists it) and shows `l10n.gearPassport_scan_added('Primary')`;
- scanning a seeded tank appends a cylinder slot with its `equipmentId`;
- scanning an item already in `packed` shows `l10n.gearPassport_scan_alreadyOnTrip('Primary')` and writes nothing.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test <trip gear add sheet test>`
Expected: FAIL.

- [ ] **Step 3: Implement**

`enum _Way { equipment, set, scan, rental }`; a `ListTile` with `Icons.qr_code_scanner` and `l10n.trips_gear_add_scan` between From set and Rental; and:

```dart
    case _Way.scan:
      final item = await scanOwnedItem(context, ref);
      if (item == null || !context.mounted) return;
      final already =
          packed.any((p) => p.id == item.id) ||
          slots.any((s) => s.equipmentId == item.id);
      final messenger = ScaffoldMessenger.of(context);
      if (already) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.gearPassport_scan_alreadyOnTrip(item.name))),
        );
        return;
      }
      await _apply(context, ref, trip, slots, [item], setName: null);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gearPassport_scan_added(item.name))),
      );
```

Update the doc comment: "a chooser that opens the equipment picker, the set picker, a tag scan, or the rental cylinder form".

- [ ] **Step 4: Run, commit**

```bash
flutter test test/features/trips
dart format lib test
git add lib test
git commit -m "feat(gear-passports): scan gear onto a trip"
```

### Task 17: Android link filters and documentation

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:140-166`
- Modify: `test/platform/passport_links_config_test.dart` (paths and hosts become sets)
- Create: `docs/import-formats/gear-tag.md`
- Create: `docs/design/specs/2026-10-10-gear-tags-device-checklist.md`

**Interfaces:**
- Produces: the app-link and `NDEF_DISCOVERED` filters accept `https://submersion.app/g`; the custom-scheme filter accepts host `g`.

- [ ] **Step 1: Update the config tests first**

Where the test reads one `data` element's `path` and expects `'/c'`, collect every `data` element's `path` in that filter and expect `containsAll(['/c', '/g'])`; where it expects host `'c'`, expect the custom-scheme filter's hosts to contain `'c'` and `'g'`. Keep `'every https filter is a complete app link'` unchanged; it must still pass.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/platform/passport_links_config_test.dart`
Expected: FAIL on `/g` and `g`.

- [ ] **Step 3: Edit the manifest**

In the autoVerify app-link filter and in the `NDEF_DISCOVERED` filter, add after the `/c` line:

```xml
                <data android:scheme="https" android:host="submersion.app" android:path="/g"/>
```

In the custom-scheme filter add:

```xml
                <data android:scheme="submersion" android:host="g"/>
```

Update the three comments: "Cylinder passport tags (`/c`, issue #2335) and gear tags (`/g`, issue #2652)".

- [ ] **Step 4: Docs**

`docs/import-formats/gear-tag.md`, following `docs/import-formats/cylinder-passport-tag.md`'s structure: URL forms; the payload table from spec 6.2 with examples; parsing rules from spec 6.3; the drop order and the NDEF layout (identity URI record, then the Android Application Record when it fits); and a worked example:

```
https://submersion.app/g#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab&w=2026-10-10&t=firstStage&n=Apeks+XTX50+primary&b=Apeks&mo=XTX50&sn=AB12345&ls=2026-03-02
```

`docs/design/specs/2026-10-10-gear-tags-device-checklist.md`, modelled on `2026-09-27-cylinder-passports-2-nfc-device-checklist.md`, with one checkbox row each for: write a regulator tag on iPhone and on Android (NTAG213 and NTAG215, note which fields fit); read it with the app open on both; background launch from a tap with the app closed on Android, and on iPhone once the website's association file lists `/g`; camera scan of a printed gear label on iPhone, Android and macOS; Paste link on Windows; the dive edit Scan and the trip Scan with an own regulator and an own tank; a foreign gear tag's Add to my gear; a 1.8.1 build tapping a `/g` tag (expect it ignored); the website `/g` page on a phone without the app.

Link both from `docs/import-formats/` index or README if one lists formats (`grep -rn cylinder-passport-tag docs`), and run `python3.14 scripts/check_docs_links.py`.

- [ ] **Step 5: Run, commit**

```bash
flutter test test/platform
python3.14 scripts/check_docs_links.py
git add android docs test/platform
git commit -m "feat(gear-passports): open gear tag links on Android, and document the format"
```

### Task 18: Translations and the full check

**Files:**
- Modify: the ten locale ARBs, then regenerate `lib/l10n/arb/app_localizations_*.dart`

- [ ] **Step 1: Translate**

For each of the 20 keys from Task 9, write the translation into `app_ar`, `de`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`, inserted by anchor line after each locale's `"passport_logFill_saveFailed"` line (and `trips_gear_add_scan` after `"trips_gear_add_rental"`), with the scratchpad script pattern from Task 9: build each line with `json.dumps(value, ensure_ascii=False)`, keep `{name}` and `{date}` verbatim, match each locale's existing words for passport, tag, gear, scan and service (read the neighbouring `passport_*` and `equipment_service_*` values first), and `json.loads` every file after writing.

- [ ] **Step 2: Generate and verify**

```bash
flutter gen-l10n
git diff --numstat -- lib/l10n/arb
grep -A1 "get gearPassport_title" lib/l10n/arb/app_localizations_de.dart
```

Expected: each locale ARB adds 20 lines (and Task 9's one removal); the German getter returns the German text, not English.

- [ ] **Step 3: Whole-branch verification**

```bash
dart format .
flutter analyze
flutter test test/architecture test/shared test/l10n test/platform
flutter test test/features/gear_passports test/features/cylinder_passports test/features/equipment test/features/trips test/features/dive_log test/features/gas_calculators test/core/services/export
```

Expected: no analyzer issues; every test passes.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n
git commit -m "i18n(gear-passports): translate gear tag strings"
```

---

## Self-review notes

- Spec coverage: 6 (Tasks 1, 3, 7), 7 (Tasks 2, 5), 8.1 (Task 4), 8.2 (Task 6), 8.3 (Task 4), 8.4 (Tasks 11, 15, 16; cylinder-only points pinned in Task 6), 9 (Task 12), 10 (Tasks 8, 13), 11 (Task 14), 12 (Task 17; website recorded on the issue at PR time), 13 (Task 17), 14 (Tasks 3, 8, 10, 13, 15), 15 (every task's tests).
- The website deliverable (association file `/g` paths and a static `/g` page) lives outside this repository; the PR description and a comment on #2652 record it.
