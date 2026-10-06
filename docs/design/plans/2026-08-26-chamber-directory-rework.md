# Chamber Directory Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 14-row placeholder chamber list with a curated, source-cited directory of roughly 200 hyperbaric facilities, and present it so a diver sees the chambers that are actually near them.

**Architecture:** The dataset stays a bundled JSON asset loaded lazily into a static cache, exactly as `DiveSiteApiService` already does for 3,612 dive sites, so no storage layer changes and no database migration. A new Python harvester collects leads from the four reachable national registries, each lead is verified against the facility's own website and cites that URL, and a hand-maintained overlay file covers every region without a reachable aggregator (North America above all). The emergency card sorts by capability band before distance so an elective wound-care clinic can never outrank an on-call dive chamber.

**Tech Stack:** Flutter/Dart, Riverpod 3, Drift (untouched here), Python 3 with `requests` and `pypdf`, `unittest` for Python tests, `flutter_test` for Dart.

**Spec:** `docs/superpowers/specs/2026-08-26-chamber-directory-rework-design.md`

## Global Constraints

- **No em-dashes** (U+2014) in any output: code, comments, commit messages, documentation, data files. En-dashes as sentence punctuation and " - " as prose punctuation are equally forbidden. Hyphens inside compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **No database schema version is claimed.** Bundled chambers are asset-resident. If any task appears to need a migration, stop: the design has been misread.
- **`EmergencyChamber.phone` stays non-nullable.** Candidates without a callable number are dropped at harvest time.
- **Existing chamber ids are preserved** for facilities that survive into the new dataset: `us-duke`, `us-catalina`, `au-townsville`, `au-fionastanley`, `nz-slark`, `gb-ddrc`, `mt-gozo`, `eg-sharm`, `th-samui`, `ph-batangas`, `id-bali`, `mv-bandos`, `mx-cozumel`, `za-capetown`. `hiddenChamberIds` in settings stores raw ids, so renaming one silently resurrects a chamber a user deliberately hid.
- **Units:** anything displaying a distance uses `UnitFormatter.formatGeoDistance()`, which respects the active diver's unit settings. Never hard-code km or miles.
- **All 11 locales** get every new string: `ar`, `de`, `en`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`.
- **`dart format .`** is run after completing any task.
- **Capability enum values on the wire:** `diving_emergency`, `hyperbaric_unit`, `elective`, `unknown`. **Availability:** `h24`, `on_call`, `business_hours`, `unknown`. **Verification via:** `facility`, `registry`.
- **Card limit 5**, **nearby radius 500 km**, **dataset row-count floor 100**.

---

## File Structure

**Created:**
- `lib/features/safety/domain/entities/chamber_listing.dart` - a chamber paired with its distance from the diver. Keeps distance out of the entity, which has no business knowing where the diver is.
- `lib/features/safety/presentation/pages/chambers_directory_page.dart` - the full searchable directory.
- `test/features/safety/data/chambers_dataset_test.dart` - invariants over the shipped asset.
- `scripts/chamber_harvester.py` - lead collection, validation, asset generation.
- `scripts/chamber_harvester_test.py` - parser and validation-gate tests.
- `scripts/data/chambers_overlay.json` - hand-curated rows with per-row citations.
- `scripts/fixtures/chambers/*.html` - captured source pages the parsers are written against.

**Modified:**
- `lib/features/safety/domain/entities/emergency_info.dart` - capability, availability, emergency phone, provenance, `copyWith`.
- `lib/features/safety/presentation/providers/emergency_providers.dart` - listings provider, capability-banded ordering, card cap, empty state.
- `lib/features/safety/presentation/pages/emergency_card_page.dart` - distance, chips, "view all", empty state.
- `lib/core/router/app_router.dart:1198-1204` - the directory route, nested under `emergency-card`.
- `assets/data/chambers.json` - the dataset itself.
- `lib/l10n/arb/app_*.arb` - 11 files.
- `scripts/requirements.txt` - `pypdf`.

---

## Task 1: Chamber capability and provenance on the entity

Pure structural change. The asset is not touched, so the existing 14 rows parse as `unknown` and every current test keeps passing.

**Files:**
- Modify: `lib/features/safety/domain/entities/emergency_info.dart`
- Test: `test/features/safety/domain/entities/emergency_info_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `ChamberCapability`, `ChamberAvailability`, `ChamberVerification` enums, each with a `wireName` field and a static `fromWire(Object?)`. `EmergencyChamber` gains `capability`, `availability`, `emergencyPhone`, `verifiedUrl`, `verifiedVia`, the `callNumber` getter, and `copyWith`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/safety/domain/entities/emergency_info_test.dart`:

```dart
group('EmergencyChamber capability and provenance', () {
  test('parses capability, availability and provenance from a bundled row', () {
    final chamber = EmergencyChamber.fromBundledJson({
      'id': 'it-niguarda',
      'name': 'Ospedale Niguarda',
      'country': 'IT',
      'city': 'Milano',
      'phone': '+39-02-6444-1',
      'emergencyPhone': '+39-02-6444-2222',
      'latitude': 45.5065,
      'longitude': 9.1919,
      'capability': 'diving_emergency',
      'availability': 'h24',
      'verified': {
        'date': '2026-08-26',
        'via': 'facility',
        'url': 'https://example.org/iperbarico',
      },
    });

    expect(chamber.capability, ChamberCapability.divingEmergency);
    expect(chamber.availability, ChamberAvailability.h24);
    expect(chamber.emergencyPhone, '+39-02-6444-2222');
    expect(chamber.verifiedVia, ChamberVerification.facility);
    expect(chamber.verifiedUrl, 'https://example.org/iperbarico');
    expect(chamber.lastVerified, DateTime.parse('2026-08-26'));
    expect(chamber.isBuiltIn, isTrue);
  });

  test('callNumber prefers the dedicated emergency line', () {
    final chamber = EmergencyChamber.fromBundledJson({
      'id': 'x',
      'name': 'X',
      'country': 'IT',
      'phone': '+39-02-6444-1',
      'emergencyPhone': '+39-02-6444-2222',
    });
    expect(chamber.callNumber, '+39-02-6444-2222');
  });

  test('callNumber falls back to the switchboard', () {
    final chamber = EmergencyChamber.fromBundledJson({
      'id': 'x',
      'name': 'X',
      'country': 'IT',
      'phone': '+39-02-6444-1',
    });
    expect(chamber.callNumber, '+39-02-6444-1');
  });

  test('rows predating the schema default to unknown', () {
    final chamber = EmergencyChamber.fromBundledJson({
      'id': 'us-duke',
      'name': 'Duke Center for Hyperbaric Medicine',
      'country': 'US',
      'phone': '+1-919-684-8111',
      'lastVerified': '2026-07-01',
    });

    expect(chamber.capability, ChamberCapability.unknown);
    expect(chamber.availability, ChamberAvailability.unknown);
    expect(chamber.verifiedVia, ChamberVerification.unknown);
    expect(chamber.emergencyPhone, isNull);
    expect(chamber.verifiedUrl, isNull);
    expect(chamber.lastVerified, DateTime.parse('2026-07-01'));
  });

  test('an unrecognised wire value degrades to unknown', () {
    final chamber = EmergencyChamber.fromBundledJson({
      'id': 'x',
      'name': 'X',
      'country': 'US',
      'phone': '+1-555-0100',
      'capability': 'wellness_spa',
      'availability': 'sometimes',
    });
    expect(chamber.capability, ChamberCapability.unknown);
    expect(chamber.availability, ChamberAvailability.unknown);
  });

  test('copyWith replaces only the named fields', () {
    const chamber = EmergencyChamber(
      id: 'x',
      name: 'X',
      country: 'US',
      phone: '+1-555-0100',
      isBuiltIn: true,
    );
    final updated = chamber.copyWith(
      capability: ChamberCapability.elective,
      city: 'Miami',
    );

    expect(updated.capability, ChamberCapability.elective);
    expect(updated.city, 'Miami');
    expect(updated.id, 'x');
    expect(updated.phone, '+1-555-0100');
    expect(updated.isBuiltIn, isTrue);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/safety/domain/entities/emergency_info_test.dart`
Expected: FAIL, "The name 'ChamberCapability' isn't defined" and "The method 'copyWith' isn't defined".

- [ ] **Step 3: Add the enums**

In `lib/features/safety/domain/entities/emergency_info.dart`, above `EmergencyChamber`:

```dart
/// What a facility is documented to do.
///
/// [divingEmergency] requires evidence that it accepts acute diving injuries.
/// The bar is DAN's own referral-network acceptance criteria: capable and
/// willing to treat injured divers, standard oxygen treatment tables for DCI,
/// oxygen available for every diving treatment table, and space to monitor a
/// diver before and after treatment.
///
/// [elective] marks hyperbaric oxygen therapy clinics (wound care and similar)
/// that will not accept a bent diver out of hours. They are listed because a
/// chamber is a chamber when nothing else is in range, never ranked above a
/// facility that treats divers.
enum ChamberCapability {
  divingEmergency('diving_emergency'),
  hyperbaricUnit('hyperbaric_unit'),
  elective('elective'),
  unknown('unknown');

  const ChamberCapability(this.wireName);

  final String wireName;

  static ChamberCapability fromWire(Object? value) {
    for (final capability in ChamberCapability.values) {
      if (capability.wireName == value) return capability;
    }
    return ChamberCapability.unknown;
  }
}

/// When the facility can be reached. Sourced from registry tagging where it
/// exists (SIMSI publishes an "Urgenza h24" flag per centre).
enum ChamberAvailability {
  h24('h24'),
  onCall('on_call'),
  businessHours('business_hours'),
  unknown('unknown');

  const ChamberAvailability(this.wireName);

  final String wireName;

  static ChamberAvailability fromWire(Object? value) {
    for (final availability in ChamberAvailability.values) {
      if (availability.wireName == value) return availability;
    }
    return ChamberAvailability.unknown;
  }
}

/// How a row's details were last confirmed. [facility] means the details were
/// checked against the facility's own website, which is both the provenance
/// story and the reason the dataset carries no third-party compilation.
enum ChamberVerification {
  facility('facility'),
  registry('registry'),
  unknown('unknown');

  const ChamberVerification(this.wireName);

  final String wireName;

  static ChamberVerification fromWire(Object? value) {
    for (final verification in ChamberVerification.values) {
      if (verification.wireName == value) return verification;
    }
    return ChamberVerification.unknown;
  }
}
```

- [ ] **Step 4: Add the fields to EmergencyChamber**

Replace the field block, constructor, factory, and `props` of `EmergencyChamber` with:

```dart
  final String id;
  final String name;
  final String country;
  final String? city;
  final String phone;

  /// Dedicated emergency line where the facility publishes one separately from
  /// its switchboard. Preferred by [callNumber].
  final String? emergencyPhone;

  final double? latitude;
  final double? longitude;
  final String? notes;

  final ChamberCapability capability;
  final ChamberAvailability availability;

  /// Verification date for bundled entries; null for user entries.
  final DateTime? lastVerified;

  final ChamberVerification verifiedVia;

  /// The page the details were confirmed against.
  final String? verifiedUrl;

  final bool isBuiltIn;

  const EmergencyChamber({
    required this.id,
    required this.name,
    required this.country,
    this.city,
    required this.phone,
    this.emergencyPhone,
    this.latitude,
    this.longitude,
    this.notes,
    this.capability = ChamberCapability.unknown,
    this.availability = ChamberAvailability.unknown,
    this.lastVerified,
    this.verifiedVia = ChamberVerification.unknown,
    this.verifiedUrl,
    required this.isBuiltIn,
  });

  /// The number to dial: the dedicated emergency line when published, else the
  /// switchboard.
  String get callNumber => emergencyPhone ?? phone;

  factory EmergencyChamber.fromBundledJson(Map<String, dynamic> json) {
    final verified = json['verified'] as Map<String, dynamic>?;
    // The date moved into `verified` with the curated dataset; `lastVerified`
    // is still read so a row written before that move keeps its date.
    final verifiedDate =
        verified?['date'] as String? ?? json['lastVerified'] as String?;

    return EmergencyChamber(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      city: json['city'] as String?,
      phone: json['phone'] as String,
      emergencyPhone: json['emergencyPhone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      capability: ChamberCapability.fromWire(json['capability']),
      availability: ChamberAvailability.fromWire(json['availability']),
      lastVerified: verifiedDate != null ? DateTime.tryParse(verifiedDate) : null,
      verifiedVia: ChamberVerification.fromWire(verified?['via']),
      verifiedUrl: verified?['url'] as String?,
      isBuiltIn: true,
    );
  }

  EmergencyChamber copyWith({
    String? id,
    String? name,
    String? country,
    String? city,
    String? phone,
    String? emergencyPhone,
    double? latitude,
    double? longitude,
    String? notes,
    ChamberCapability? capability,
    ChamberAvailability? availability,
    DateTime? lastVerified,
    ChamberVerification? verifiedVia,
    String? verifiedUrl,
    bool? isBuiltIn,
  }) {
    return EmergencyChamber(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      capability: capability ?? this.capability,
      availability: availability ?? this.availability,
      lastVerified: lastVerified ?? this.lastVerified,
      verifiedVia: verifiedVia ?? this.verifiedVia,
      verifiedUrl: verifiedUrl ?? this.verifiedUrl,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    country,
    city,
    phone,
    emergencyPhone,
    latitude,
    longitude,
    notes,
    capability,
    availability,
    lastVerified,
    verifiedVia,
    verifiedUrl,
    isBuiltIn,
  ];
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/safety/domain/entities/emergency_info_test.dart test/features/safety/data/services/emergency_data_service_test.dart`
Expected: PASS. The data-service test still passes because the existing 14 rows keep their `lastVerified` key.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/safety/domain/entities/emergency_info.dart test/features/safety/domain/entities/emergency_info_test.dart
git commit -m "feat(safety): add capability and provenance fields to EmergencyChamber"
```

---

## Task 2: Dataset invariants test

A validation gate that lives with the app, so a bad regeneration of the asset fails the suite rather than shipping. The row-count floor is deliberately absent here and added in Task 8, when the data exists to satisfy it.

**Files:**
- Create: `test/features/safety/data/chambers_dataset_test.dart`

**Interfaces:**
- Consumes: `EmergencyDataService.loadBundledChambers()`, the enums from Task 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/data/services/emergency_data_service.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

/// Invariants over the shipped chamber asset. These guard a safety-critical
/// dataset that is regenerated by `scripts/chamber_harvester.py`: a parser that
/// silently starts emitting empty phone numbers or duplicate ids fails here
/// rather than on a diver's phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(EmergencyDataService.resetCacheForTesting);

  test('every chamber row satisfies the dataset invariants', () async {
    final chambers = await EmergencyDataService.loadBundledChambers();
    expect(chambers, isNotEmpty);

    final seenIds = <String>{};
    for (final chamber in chambers) {
      final where = '${chamber.id} (${chamber.name})';

      expect(seenIds.add(chamber.id), isTrue, reason: 'duplicate id: $where');
      expect(chamber.name.trim(), isNotEmpty, reason: 'blank name: $where');
      expect(
        chamber.country,
        matches(RegExp(r'^[A-Z]{2}$')),
        reason: 'country must be an ISO 3166-1 alpha-2 code: $where',
      );
      expect(chamber.phone.trim(), isNotEmpty, reason: 'blank phone: $where');
      expect(
        chamber.phone,
        startsWith('+'),
        reason: 'phone must be internationally dialable: $where',
      );
      expect(chamber.isBuiltIn, isTrue, reason: 'bundled rows are built in: $where');
      expect(chamber.lastVerified, isNotNull, reason: 'no verification date: $where');
    }
  });

  test('coordinates are present and on the planet', () async {
    final chambers = await EmergencyDataService.loadBundledChambers();

    for (final chamber in chambers) {
      final where = '${chamber.id} (${chamber.name})';
      expect(chamber.latitude, isNotNull, reason: 'no latitude: $where');
      expect(chamber.longitude, isNotNull, reason: 'no longitude: $where');
      expect(chamber.latitude!, inInclusiveRange(-90, 90), reason: where);
      expect(chamber.longitude!, inInclusiveRange(-180, 180), reason: where);
      // 0,0 is in the Gulf of Guinea and is what a failed geocode looks like.
      expect(
        chamber.latitude == 0 && chamber.longitude == 0,
        isFalse,
        reason: 'null island coordinates: $where',
      );
    }
  });

  test('verification dates are not in the future', () async {
    final chambers = await EmergencyDataService.loadBundledChambers();
    final now = DateTime.now();

    for (final chamber in chambers) {
      expect(
        chamber.lastVerified!.isAfter(now),
        isFalse,
        reason: 'verified in the future: ${chamber.id}',
      );
    }
  });

  test('the ids users may have hidden are still present', () async {
    // `hiddenChamberIds` in settings stores raw ids. Renaming one of these
    // resurrects a chamber a user deliberately hid.
    const preserved = [
      'us-duke',
      'us-catalina',
      'au-townsville',
      'au-fionastanley',
      'nz-slark',
      'gb-ddrc',
      'mt-gozo',
      'eg-sharm',
      'th-samui',
      'ph-batangas',
      'id-bali',
      'mv-bandos',
      'mx-cozumel',
      'za-capetown',
    ];

    final chambers = await EmergencyDataService.loadBundledChambers();
    final ids = chambers.map((c) => c.id).toSet();

    for (final id in preserved) {
      expect(ids, contains(id), reason: 'id $id disappeared from the dataset');
    }
  });
}
```

- [ ] **Step 2: Run it against the current asset**

Run: `flutter test test/features/safety/data/chambers_dataset_test.dart`
Expected: PASS. All 14 current rows already satisfy every invariant, which is the point: the gate is installed before the data changes under it.

- [ ] **Step 3: Commit**

```bash
git add test/features/safety/data/chambers_dataset_test.dart
git commit -m "test(safety): add invariants over the bundled chamber dataset"
```

---

## Task 3: Chamber listings, capability-banded ordering, card cap

**Files:**
- Create: `lib/features/safety/domain/entities/chamber_listing.dart`
- Modify: `lib/features/safety/presentation/providers/emergency_providers.dart`
- Test: `test/features/safety/presentation/providers/emergency_providers_test.dart`

**Interfaces:**
- Consumes: `EmergencyChamber`, `ChamberCapability` from Task 1.
- Produces: `ChamberListing` with `chamber` and `distanceMeters`; `chamberListingsProvider` returning `List<ChamberListing>` (the full ordered directory); `EmergencyCardData.nearbyChambers` (`List<ChamberListing>`, at most 5) and `EmergencyCardData.totalChamberCount` (`int`). The old `EmergencyCardData.chambers` field is removed. Constants `chamberCardLimit = 5` and `chamberNearbyRadiusMeters = 500000.0`.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/safety/presentation/providers/emergency_providers_test.dart`. The existing `_FakeChamberRepo` and `_summary` helpers are reused.

```dart
EmergencyChamber _bundled({
  required String id,
  required String country,
  ChamberCapability capability = ChamberCapability.divingEmergency,
  double? lat,
  double? lon,
}) {
  return EmergencyChamber(
    id: id,
    name: id,
    country: country,
    phone: '+1-555-0100',
    latitude: lat,
    longitude: lon,
    capability: capability,
    lastVerified: DateTime.utc(2026, 8, 1),
    isBuiltIn: true,
  );
}

group('chamber ordering', () {
  test('an elective clinic never outranks a dive chamber, however close', () async {
    // Sydney Harbour. The elective clinic is next door, the dive chamber is
    // 250 km up the coast.
    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(
          _FakeDiveRepository([_summary(lat: -33.85, lon: 151.21)]),
        ),
        emergencyChamberRepositoryProvider.overrideWithValue(
          _FakeChamberRepo(const []),
        ),
      ],
    );
    addTearDown(container.dispose);

    final listings = await container.read(chamberListingsProvider.future);
    final order = listings.map((l) => l.chamber.id).toList();

    expect(order.indexOf('dive-far'), lessThan(order.indexOf('elective-near')));
  });

  test('user chambers stay at the top', () async {
    // A chamber the diver added themselves outranks everything bundled.
  });

  test('within a band, the nearer chamber wins', () async {});

  test('chambers without coordinates sort last within their band', () async {});
});

group('card selection', () {
  test('the card shows at most five chambers', () async {});

  test('chambers beyond 500 km are left off the card', () async {});

  test('without GPS, the card falls back to same-country chambers', () async {});

  test('the full directory keeps every chamber the card omits', () async {});
});
```

The four tests above with empty bodies are placeholders **for the implementer to fill using the first test as the template**, varying only the fixture chambers and the assertion. Each one must be a real test before Step 2 is run: construct a `ProviderContainer` with the same two overrides, seed the bundled fixture list, read the provider, assert on ids. Do not leave an empty body.

Seeding bundled fixtures requires an override point. Add to `EmergencyDataService`:

```dart
  /// Test seam: replaces the asset-backed dataset for a single test.
  static void setBundledChambersForTesting(List<EmergencyChamber> chambers) {
    _chambersCache = chambers;
  }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/safety/presentation/providers/emergency_providers_test.dart`
Expected: FAIL, "The name 'chamberListingsProvider' isn't defined".

- [ ] **Step 3: Create the listing entity**

`lib/features/safety/domain/entities/chamber_listing.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

/// A chamber paired with how far it is from the diver's last known dive site.
///
/// Distance lives here rather than on [EmergencyChamber] because a chamber has
/// no business knowing where the diver is: the same chamber is 20 km away on
/// one dive and 8,000 km away on the next.
class ChamberListing extends Equatable {
  final EmergencyChamber chamber;

  /// Null when the diver's position is unknown or the chamber has no
  /// coordinates.
  final double? distanceMeters;

  const ChamberListing({required this.chamber, this.distanceMeters});

  @override
  List<Object?> get props => [chamber, distanceMeters];
}
```

- [ ] **Step 4: Add the listings provider**

In `emergency_providers.dart`, add the constants and the provider. Keep `_distanceKm`, `_rad`, and `_isoFromCountry` exactly as they are.

```dart
/// How many chambers the emergency card shows before deferring to the full
/// directory. The card is read under stress; it is not a browsing surface.
const chamberCardLimit = 5;

/// Beyond this, a chamber is not meaningfully "near" and the card says so
/// instead of listing a facility on another continent. The full directory
/// still lists it.
const chamberNearbyRadiusMeters = 500000.0;

/// Ordering band. Lower sorts first.
///
/// Distance alone would rank an elective wound-care clinic 5 km away above an
/// on-call dive chamber 80 km away, which is the whole hazard of listing
/// elective facilities. Banding defuses it. A chamber the diver added
/// themselves always leads: they added it on purpose.
int _orderingBand(EmergencyChamber chamber) {
  if (!chamber.isBuiltIn) return 0;
  return switch (chamber.capability) {
    ChamberCapability.divingEmergency => 1,
    ChamberCapability.hyperbaricUnit => 2,
    ChamberCapability.unknown => 3,
    ChamberCapability.elective => 4,
  };
}

/// Every chamber the diver can see, ordered by band then distance. Backs both
/// the emergency card (which takes the head of this list) and the directory
/// page (which shows all of it).
final chamberListingsProvider = FutureProvider<List<ChamberListing>>((ref) async {
  final bundled = await EmergencyDataService.loadBundledChambers();
  final diver = await ref.watch(currentDiverProvider.future);
  final hidden = ref.watch(settingsProvider.select((s) => s.hiddenChamberIds));

  final chamberRepo = ref.watch(emergencyChamberRepositoryProvider);
  ref.invalidateSelfWhen(chamberRepo.watchChanges());
  final userChambers = await chamberRepo.getUserChambers(diverId: diver?.id);

  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final summaries = await repository.getDiveSummaries(
    limit: 1,
    diverId: diver?.id,
  );
  final lat = summaries.isNotEmpty ? summaries.first.siteLatitude : null;
  final lon = summaries.isNotEmpty ? summaries.first.siteLongitude : null;

  final chambers = [
    ...userChambers,
    ...bundled.where((c) => !hidden.contains(c.id)),
  ];

  final listings = [
    for (final chamber in chambers)
      ChamberListing(
        chamber: chamber,
        distanceMeters: (lat != null && lon != null)
            ? _distanceKm(lat, lon, chamber.latitude, chamber.longitude) * 1000
            : null,
      ),
  ];

  listings.sort((a, b) {
    final band = _orderingBand(a.chamber).compareTo(_orderingBand(b.chamber));
    if (band != 0) return band;
    // Chambers with no distance (no GPS anchor, or no coordinates) sort last
    // within their band rather than jumping to the front on a null compare.
    final da = a.distanceMeters ?? double.maxFinite;
    final db = b.distanceMeters ?? double.maxFinite;
    final byDistance = da.compareTo(db);
    if (byDistance != 0) return byDistance;
    // List.sort is not stable, so break remaining ties deterministically or
    // the widget tests flake on reordering.
    return a.chamber.name.compareTo(b.chamber.name);
  });

  return listings;
});
```

Note that `_distanceKm` returns `double.maxFinite` for a chamber with no coordinates. Multiplying that by 1000 overflows to infinity, which still sorts last correctly, but the card's radius filter must treat non-finite distances as "not nearby". Guard it in `_selectNearby` below rather than changing `_distanceKm`.

- [ ] **Step 5: Rework EmergencyCardData**

Replace the `chambers` field and its assembly:

```dart
class EmergencyCardData {
  final String? countryCode;
  final EmergencyRegion hotline;
  final String emsNumber;
  final Diver? diver;

  /// At most [chamberCardLimit] chambers worth showing on the card.
  final List<ChamberListing> nearbyChambers;

  /// Everything in the directory, for the "view all" affordance.
  final int totalChamberCount;

  const EmergencyCardData({
    required this.countryCode,
    required this.hotline,
    required this.emsNumber,
    required this.diver,
    required this.nearbyChambers,
    required this.totalChamberCount,
  });
}

/// Picks what the card shows.
///
/// A chamber the diver added themselves always qualifies. A bundled chamber
/// qualifies when it is within [chamberNearbyRadiusMeters], or, when the
/// diver's position is unknown, when it is in the resolved country.
List<ChamberListing> _selectNearby(
  List<ChamberListing> listings,
  String? countryCode,
) {
  final picked = <ChamberListing>[];
  for (final listing in listings) {
    if (picked.length >= chamberCardLimit) break;

    if (!listing.chamber.isBuiltIn) {
      picked.add(listing);
      continue;
    }

    final distance = listing.distanceMeters;
    if (distance != null) {
      if (distance.isFinite && distance <= chamberNearbyRadiusMeters) {
        picked.add(listing);
      }
      continue;
    }

    if (countryCode != null && listing.chamber.country == countryCode) {
      picked.add(listing);
    }
  }
  return picked;
}

final emergencyCardDataProvider = FutureProvider<EmergencyCardData>((ref) async {
  final numbers = await EmergencyDataService.loadNumbers();
  final countryCode = await ref.watch(emergencyRegionProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);
  final listings = await ref.watch(chamberListingsProvider.future);

  return EmergencyCardData(
    countryCode: countryCode,
    hotline: numbers.hotlineFor(countryCode),
    emsNumber: numbers.emsFor(countryCode),
    diver: diver,
    nearbyChambers: _selectNearby(listings, countryCode),
    totalChamberCount: listings.length,
  );
});
```

Add the import for `chamber_listing.dart`.

- [ ] **Step 6: Run the provider tests**

Run: `flutter test test/features/safety/presentation/providers/emergency_providers_test.dart`
Expected: PASS. Existing tests referencing `data.chambers` must be updated to `data.nearbyChambers`; that rename is part of this step.

- [ ] **Step 7: Fix the card page compile break and run the safety suite**

`emergency_card_page.dart:135` reads `data.chambers`. Change it to `data.nearbyChambers` and `chamber` to `listing.chamber` so the app compiles. The full tile rework is Task 9.

Run: `flutter test test/features/safety/`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/safety test/features/safety
git commit -m "feat(safety): order chambers by capability band then distance"
```

---

## Task 4: Harvester skeleton and validation gates

**Files:**
- Create: `scripts/chamber_harvester.py`
- Create: `scripts/chamber_harvester_test.py`
- Modify: `scripts/requirements.txt`

**Interfaces:**
- Produces: `validate_chambers(chambers, min_count=100) -> list[str]` returning error strings (empty means valid); `merge_rows(leads, overlay) -> list[dict]` where overlay rows win on id collision; `write_dataset(chambers, sources, path)`.

- [ ] **Step 1: Write the failing tests**

`scripts/chamber_harvester_test.py`, following the `importlib` loading convention used by `scripts/check_native_libs_present_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for chamber_harvester.py.

Run: python3 scripts/chamber_harvester_test.py

These cover the validation gates, which are the only thing standing between a
broken parser and a safety-critical dataset shipping with blank phone numbers.
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "chamber_harvester",
    os.path.join(_HERE, "chamber_harvester.py"),
)
chamber_harvester = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(chamber_harvester)


def _row(**overrides):
    row = {
        "id": "it-example",
        "name": "Centro Iperbarico Example",
        "country": "IT",
        "city": "Milano",
        "phone": "+39-02-1234-5678",
        "latitude": 45.4642,
        "longitude": 9.19,
        "capability": "diving_emergency",
        "availability": "h24",
        "verified": {
            "date": "2026-08-26",
            "via": "facility",
            "url": "https://example.org/iperbarico",
        },
    }
    row.update(overrides)
    return row


class ValidateChambersTest(unittest.TestCase):
    def test_a_well_formed_row_passes(self):
        self.assertEqual(
            chamber_harvester.validate_chambers([_row()], min_count=1), []
        )

    def test_duplicate_ids_are_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(), _row()], min_count=1
        )
        self.assertTrue(any("duplicate id" in e for e in errors))

    def test_a_row_without_a_phone_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(phone="")], min_count=1
        )
        self.assertTrue(any("phone" in e for e in errors))

    def test_a_national_format_phone_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(phone="02 1234 5678")], min_count=1
        )
        self.assertTrue(any("phone" in e for e in errors))

    def test_a_country_name_instead_of_a_code_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(country="Italy")], min_count=1
        )
        self.assertTrue(any("country" in e for e in errors))

    def test_out_of_range_coordinates_are_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(latitude=91.0)], min_count=1
        )
        self.assertTrue(any("latitude" in e for e in errors))

    def test_null_island_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(latitude=0.0, longitude=0.0)], min_count=1
        )
        self.assertTrue(any("0,0" in e for e in errors))

    def test_an_unknown_capability_value_is_rejected(self):
        errors = chamber_harvester.validate_chambers(
            [_row(capability="wellness")], min_count=1
        )
        self.assertTrue(any("capability" in e for e in errors))

    def test_a_missing_verification_block_is_rejected(self):
        row = _row()
        del row["verified"]
        errors = chamber_harvester.validate_chambers([row], min_count=1)
        self.assertTrue(any("verified" in e for e in errors))

    def test_the_row_count_floor_is_enforced(self):
        errors = chamber_harvester.validate_chambers([_row()], min_count=100)
        self.assertTrue(any("at least 100" in e for e in errors))


class MergeRowsTest(unittest.TestCase):
    def test_overlay_rows_win_over_harvested_leads(self):
        lead = _row(phone="+39-02-0000-0000")
        overlay = _row(phone="+39-02-9999-9999")
        merged = chamber_harvester.merge_rows([lead], [overlay])
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["phone"], "+39-02-9999-9999")

    def test_rows_with_distinct_ids_are_both_kept(self):
        merged = chamber_harvester.merge_rows(
            [_row(id="it-a")], [_row(id="it-b")]
        )
        self.assertEqual({r["id"] for r in merged}, {"it-a", "it-b"})

    def test_output_is_sorted_by_id_for_stable_diffs(self):
        merged = chamber_harvester.merge_rows(
            [_row(id="it-z"), _row(id="it-a")], []
        )
        self.assertEqual([r["id"] for r in merged], ["it-a", "it-z"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify failure**

Run: `python3 scripts/chamber_harvester_test.py`
Expected: FAIL, `FileNotFoundError` or `ModuleNotFoundError` because the script does not exist.

- [ ] **Step 3: Write the harvester core**

`scripts/chamber_harvester.py`:

```python
#!/usr/bin/env python3
"""
Recompression chamber directory harvester.

Collects leads from the national hyperbaric registries that publish one,
merges a hand-curated overlay covering every region without a reachable
registry, and writes assets/data/chambers.json.

No source found publishes chamber data under a redistribution license, so
every row is verified against the facility's own website and cites that URL.
Treat registry listings as leads to confirm, never as data to copy.

Usage:
    python3 scripts/chamber_harvester.py --leads     # refresh scripts/chamber_leads.json
    python3 scripts/chamber_harvester.py --build     # merge + validate + write the asset
"""

import argparse
import json
import os
import re
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "assets", "data", "chambers.json")
LEADS_PATH = os.path.join(SCRIPT_DIR, "chamber_leads.json")
OVERLAY_PATH = os.path.join(SCRIPT_DIR, "data", "chambers_overlay.json")
FIXTURE_DIR = os.path.join(SCRIPT_DIR, "fixtures", "chambers")

MIN_CHAMBERS = 100

CAPABILITIES = {"diving_emergency", "hyperbaric_unit", "elective", "unknown"}
AVAILABILITIES = {"h24", "on_call", "business_hours", "unknown"}
VERIFICATION_VIA = {"facility", "registry"}

ISO_COUNTRY = re.compile(r"^[A-Z]{2}$")
# Internationally dialable: a leading +, then digits with the separators that
# survive copy-paste from a hospital website.
E164_ISH = re.compile(r"^\+[0-9][0-9\-\s().]{5,}$")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def validate_chambers(chambers, min_count=MIN_CHAMBERS):
    """Return a list of human-readable errors. Empty means the dataset is fit
    to ship."""
    errors = []
    seen = set()

    for chamber in chambers:
        cid = chamber.get("id", "")
        where = cid or chamber.get("name", "<unnamed>")

        if not cid:
            errors.append(f"{where}: missing id")
        elif cid in seen:
            errors.append(f"duplicate id: {cid}")
        else:
            seen.add(cid)

        if not chamber.get("name", "").strip():
            errors.append(f"{where}: missing name")

        country = chamber.get("country", "")
        if not ISO_COUNTRY.match(country):
            errors.append(
                f"{where}: country must be an ISO 3166-1 alpha-2 code, got {country!r}"
            )

        phone = chamber.get("phone", "")
        if not phone.strip():
            errors.append(f"{where}: missing phone")
        elif not E164_ISH.match(phone):
            errors.append(
                f"{where}: phone must be internationally dialable, got {phone!r}"
            )

        emergency_phone = chamber.get("emergencyPhone")
        if emergency_phone is not None and not E164_ISH.match(emergency_phone):
            errors.append(
                f"{where}: emergencyPhone must be internationally dialable, "
                f"got {emergency_phone!r}"
            )

        lat = chamber.get("latitude")
        lon = chamber.get("longitude")
        if not isinstance(lat, (int, float)):
            errors.append(f"{where}: missing latitude")
        elif not -90 <= lat <= 90:
            errors.append(f"{where}: latitude out of range: {lat}")
        if not isinstance(lon, (int, float)):
            errors.append(f"{where}: missing longitude")
        elif not -180 <= lon <= 180:
            errors.append(f"{where}: longitude out of range: {lon}")
        if lat == 0 and lon == 0:
            errors.append(f"{where}: coordinates are 0,0, which is a failed geocode")

        capability = chamber.get("capability", "unknown")
        if capability not in CAPABILITIES:
            errors.append(f"{where}: unknown capability {capability!r}")

        availability = chamber.get("availability", "unknown")
        if availability not in AVAILABILITIES:
            errors.append(f"{where}: unknown availability {availability!r}")

        verified = chamber.get("verified")
        if not isinstance(verified, dict):
            errors.append(f"{where}: missing verified block")
        else:
            date = verified.get("date", "")
            if not ISO_DATE.match(date):
                errors.append(f"{where}: verified.date must be YYYY-MM-DD, got {date!r}")
            elif date > datetime.now(timezone.utc).strftime("%Y-%m-%d"):
                errors.append(f"{where}: verified.date is in the future: {date}")
            if verified.get("via") not in VERIFICATION_VIA:
                errors.append(f"{where}: verified.via must be one of {VERIFICATION_VIA}")
            if not verified.get("url", "").startswith("http"):
                errors.append(f"{where}: verified.url must be a URL")

    if len(chambers) < min_count:
        errors.append(
            f"dataset has {len(chambers)} chambers, expected at least {min_count}"
        )

    return errors


def merge_rows(leads, overlay):
    """Merge harvested leads with the curated overlay. Overlay wins: it is
    hand-verified, the leads are not. Sorted by id so regenerating the asset
    produces a reviewable diff."""
    by_id = {}
    for row in leads:
        by_id[row["id"]] = row
    for row in overlay:
        by_id[row["id"]] = row
    return [by_id[key] for key in sorted(by_id)]


def write_dataset(chambers, sources, path=OUTPUT_PATH):
    payload = {
        "datasetVersion": datetime.now(timezone.utc).strftime("%Y-%m"),
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "note": (
            "Hyperbaric facility directory. Availability changes without notice: "
            "ALWAYS call the diver emergency hotline first for referral. Each "
            "entry carries the date and source its details were verified against."
        ),
        "sources": sources,
        "chambers": chambers,
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def _load_json(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def build():
    leads_doc = _load_json(LEADS_PATH, {"chambers": [], "sources": []})
    overlay_doc = _load_json(OVERLAY_PATH, {"chambers": [], "sources": []})

    chambers = merge_rows(leads_doc.get("chambers", []), overlay_doc.get("chambers", []))
    sources = leads_doc.get("sources", []) + overlay_doc.get("sources", [])

    errors = validate_chambers(chambers)
    if errors:
        print(f"Refusing to write the dataset: {len(errors)} validation errors")
        for error in errors:
            print(f"  {error}")
        return 1

    write_dataset(chambers, sources)
    print(f"Wrote {len(chambers)} chambers to {OUTPUT_PATH}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--leads", action="store_true", help="refresh leads from registries")
    parser.add_argument("--build", action="store_true", help="merge, validate and write the asset")
    args = parser.parse_args()

    if args.leads:
        from chamber_sources import harvest_all  # noqa: F401  (added in Task 5)

        raise SystemExit("run Task 5 before using --leads")
    if args.build:
        raise SystemExit(build())
    parser.print_help()
    return 0


if __name__ == "__main__":
    main()
```

Note: the `--leads` branch is wired properly in Task 5. Leaving it raising a clear message is deliberate, so an early run fails loudly instead of writing a half-built dataset.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 scripts/chamber_harvester_test.py`
Expected: PASS, 13 tests.

- [ ] **Step 5: Add the PDF dependency**

Append to `scripts/requirements.txt`:

```
# chamber_harvester.py - recompression chamber directory
pypdf>=4.0.0
```

- [ ] **Step 6: Commit**

```bash
git add scripts/chamber_harvester.py scripts/chamber_harvester_test.py scripts/requirements.txt
git commit -m "feat(scripts): add the chamber harvester with validation gates"
```

---

## Task 5: Registry lead parsers

Parsers are written against captured fixtures, never against the live page, so the tests are hermetic and a source going down does not break the suite. Extraction is text-based rather than DOM-selector-based, because these pages are hand-maintained and their markup churns while their text does not.

**Files:**
- Create: `scripts/chamber_sources.py`
- Create: `scripts/fixtures/chambers/simsi.html`, `bha.html`, `spums.html`, `ffessm.pdf`
- Modify: `scripts/chamber_harvester_test.py`, `scripts/chamber_harvester.py`

**Interfaces:**
- Produces: `parse_simsi(text) -> list[dict]`, `parse_bha(text)`, `parse_spums(text)`, `parse_ffessm(pdf_bytes)`, each returning lead rows shaped like the dataset rows but with `verified.via == "registry"`; `harvest_all(fixture_dir=None) -> tuple[list[dict], list[dict]]` returning rows and source descriptors.

- [ ] **Step 1: Capture the fixtures**

```bash
mkdir -p scripts/fixtures/chambers
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36'
curl -sL -A "$UA" 'https://simsi.it/centri-iperbarici-italiani/' -o scripts/fixtures/chambers/simsi.html
curl -sL -A "$UA" 'https://ukhyperbaric.com/members/' -o scripts/fixtures/chambers/bha.html
curl -sL -A "$UA" 'https://spums.au/index.php/resources/hyperbaric-medicine-units-australia-new-zealand' -o scripts/fixtures/chambers/spums.html
curl -sL -A "$UA" 'https://ffessm74.com/wp-content/uploads/2014/03/Liste_Caissons2.pdf' -o scripts/fixtures/chambers/ffessm.pdf
wc -c scripts/fixtures/chambers/*
```

If any fetch returns an error page or near-zero bytes, record that in the commit message and skip that parser. The overlay in Task 7 covers whatever a parser cannot.

- [ ] **Step 2: Read the fixtures and write the failing tests**

Open each captured fixture and pick two real facilities from it. Write one test per source asserting those two are extracted with the right name, phone, and (for SIMSI) the `h24` flag. Example shape, with the values replaced by what the fixture actually contains:

```python
class ParseSimsiTest(unittest.TestCase):
    def setUp(self):
        path = os.path.join(_HERE, "fixtures", "chambers", "simsi.html")
        with open(path, encoding="utf-8") as handle:
            self.html = handle.read()

    def test_extracts_a_known_centre(self):
        rows = chamber_sources.parse_simsi(self.html)
        names = [r["name"] for r in rows]
        self.assertIn("<exact name copied from the fixture>", names)

    def test_flags_h24_centres_as_diving_emergency(self):
        rows = chamber_sources.parse_simsi(self.html)
        h24 = [r for r in rows if r["availability"] == "h24"]
        self.assertTrue(h24, "SIMSI tags centres Urgenza h24; none were parsed")

    def test_every_row_is_marked_as_a_registry_lead(self):
        rows = chamber_sources.parse_simsi(self.html)
        self.assertTrue(all(r["verified"]["via"] == "registry" for r in rows))
```

- [ ] **Step 3: Run to verify failure**

Run: `python3 scripts/chamber_harvester_test.py`
Expected: FAIL, `chamber_sources` not defined.

- [ ] **Step 4: Write the parsers**

`scripts/chamber_sources.py`. The shared helpers are fully specified; the per-source segmentation is derived from the fixture you captured.

```python
#!/usr/bin/env python3
"""Lead parsers for the national hyperbaric registries that publish a list.

Every row produced here is a LEAD, marked verified.via == "registry". Leads are
confirmed against the facility's own website before they reach the shipped
dataset. None of these sources grants a redistribution license, which is why
the pipeline re-verifies rather than republishes.
"""

import html
import re
import unicodedata

# Phone numbers as they appear on European and Australasian hospital pages.
PHONE_RE = re.compile(r"(?:\+|00)\s?\d[\d\s\-().]{6,}\d")
TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"[ \t\xa0]+")


def visible_text(markup):
    """Strip markup to visible text, preserving line structure so records stay
    separable."""
    text = re.sub(r"(?is)<(script|style).*?</\1>", " ", markup)
    text = re.sub(r"(?i)<(br|/p|/div|/li|/tr|/h[1-6])\s*/?>", "\n", text)
    text = TAG_RE.sub(" ", text)
    text = html.unescape(text)
    text = unicodedata.normalize("NFC", text)
    text = WHITESPACE_RE.sub(" ", text)
    return "\n".join(line.strip() for line in text.split("\n") if line.strip())


def normalize_phone(raw, default_country_code):
    """Normalize to a leading-+ international number.

    A national-format number is promoted using the country's dialing code, with
    a single leading trunk zero dropped, which is the convention across every
    country in this dataset.
    """
    if not raw:
        return None
    digits = re.sub(r"[^\d+]", "", raw)
    if digits.startswith("00"):
        digits = "+" + digits[2:]
    if digits.startswith("+"):
        return digits
    digits = digits.lstrip("0")
    return f"+{default_country_code}{digits}"


def slugify(value):
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value).strip("-").lower()
    return re.sub(r"-{2,}", "-", value)


def make_id(country, name):
    return f"{country.lower()}-{slugify(name)}"[:60]


def lead_row(*, country, name, phone, city=None, capability="unknown",
             availability="unknown", source_url, retrieved):
    """Build a lead row. Coordinates are filled by geocoding in the build step,
    so they are absent here."""
    return {
        "id": make_id(country, name),
        "name": name,
        "country": country,
        "city": city,
        "phone": phone,
        "capability": capability,
        "availability": availability,
        "verified": {"date": retrieved, "via": "registry", "url": source_url},
    }
```

Then one function per source. Each follows the same three moves: reduce the fixture to visible text, split it into per-facility records, and pull name, city, phone, and any capability flag out of each record. For SIMSI the `h24` flag is the string `h24` appearing in the record, case-insensitively, and a record carrying it becomes `capability="diving_emergency", availability="h24"`. For FFESSM, `pypdf.PdfReader` supplies the text and a record tagged `militaire` becomes `availability="on_call"` since those chambers open to the public only in emergencies. Write each splitter against the record separator you can see in your captured fixture, and assert the two known facilities from Step 2.

- [ ] **Step 5: Run the tests until they pass**

Run: `python3 scripts/chamber_harvester_test.py`
Expected: PASS, all parser tests included.

- [ ] **Step 6: Wire --leads and generate the leads file**

Replace the `--leads` branch in `chamber_harvester.py` with a call to `chamber_sources.harvest_all()`, writing `{"chambers": rows, "sources": sources}` to `LEADS_PATH`.

Run: `python3 scripts/chamber_harvester.py --leads && python3 -c "import json;d=json.load(open('scripts/chamber_leads.json'));print(len(d['chambers']))"`
Expected: a count in the dozens.

- [ ] **Step 7: Commit**

```bash
git add scripts/chamber_sources.py scripts/chamber_harvester.py scripts/chamber_harvester_test.py scripts/fixtures/chambers scripts/chamber_leads.json
git commit -m "feat(scripts): parse chamber leads from the national registries"
```

---

## Task 6: Verify the leads against the facilities

**Files:**
- Modify: `scripts/chamber_leads.json` (promotes rows to `via: "facility"`)

**Interfaces:**
- Consumes: `scripts/chamber_leads.json` from Task 5.
- Produces: the same file with verified rows carrying `verified.via == "facility"` and `verified.url` pointing at the facility's own page.

- [ ] **Step 1: Verify in batches**

For each lead, find the facility's own website, confirm the name, phone, and city, and rewrite the row's `verified` block to `{"date": "<today>", "via": "facility", "url": "<the facility page>"}`. Dispatch this in batches of roughly 20 facilities per subagent, since it is I/O bound and embarrassingly parallel. Each subagent is told: confirm the phone number appears on the facility's own domain, do not accept an aggregator or directory as confirmation, and report rows it could not confirm rather than inventing a URL.

- [ ] **Step 2: Leave unconfirmed rows as registry leads**

A row whose facility site is unreachable, bot-blocked, or nonexistent keeps `via: "registry"`. It ships flagged rather than dropped, per the spec. A row whose phone number could not be found anywhere is dropped: `phone` is required.

- [ ] **Step 3: Commit**

```bash
git add scripts/chamber_leads.json
git commit -m "chore(scripts): verify chamber leads against facility websites"
```

---

## Task 7: The curated overlay, including North America

**Files:**
- Create: `scripts/data/chambers_overlay.json`

**Interfaces:**
- Produces: overlay rows consumed by `merge_rows` in Task 4. Same shape as dataset rows, plus a `sources` array of descriptors.

- [ ] **Step 1: Seed the overlay with the preserved ids**

Carry all 14 current chambers across unchanged in id, adding `capability`, `availability`, and a `verified` block for each. These are real facilities and most are documented dive chambers, so they mostly become `diving_emergency`. Verify each one before assigning the flag.

- [ ] **Step 2: Curate North America**

No aggregator is reachable: UHMS is behind a Cloudflare challenge and DAN publishes nothing. Assemble facility by facility, each confirmed against the facility's own site. Start from the hospital hyperbaric units known to treat divers and work outward: Duke, UCSD, Hennepin Healthcare, Virginia Mason, Christiana Care, Shands, LSU, Kuakini in Honolulu, Toronto General, Vancouver General, QEII Halifax, plus the dive-destination chambers in Mexico and the Caribbean (Cozumel, Playa del Carmen, Isla Mujeres, La Paz, Cabo, Roatan, Belize, Cayman, Bonaire, Curacao, Turks and Caicos, USVI, Puerto Rico).

A facility that treats divers gets `diving_emergency`. A hospital hyperbaric unit with no documented diving-emergency role gets `hyperbaric_unit`. A wound-care or HBOT clinic gets `elective`. When the facility's own site does not say, it is `unknown`, never an assumption.

- [ ] **Step 3: Curate the remaining regions**

Egypt (Red Sea), Southeast Asia, South Africa, Spain, Greece, Croatia, Turkey, the Maldives, Indonesia, the Philippines, Thailand, Fiji, and the rest of the Pacific. The Southeast Asian listings circulating publicly date from 2002 to 2004, so treat every one as a lead requiring confirmation. Do not carry a row forward on the strength of a twenty-year-old listing.

- [ ] **Step 4: Build and validate**

Run: `python3 scripts/chamber_harvester.py --build`
Expected: `Wrote N chambers to .../chambers.json` with N at or above 100. If it prints validation errors instead, fix the offending rows: the gate is doing its job.

- [ ] **Step 5: Run the Dart invariants against the real dataset**

Run: `flutter test test/features/safety/`
Expected: PASS. The preserved-ids test in Task 2 is the one most likely to fail here, and it failing means an id got renamed during curation.

- [ ] **Step 6: Commit**

```bash
git add scripts/data/chambers_overlay.json assets/data/chambers.json
git commit -m "feat(safety): curate the hyperbaric chamber directory"
```

---

## Task 8: Raise the dataset floor

**Files:**
- Modify: `test/features/safety/data/chambers_dataset_test.dart`

- [ ] **Step 1: Add the count test**

```dart
  test('the dataset is a directory, not a sample', () async {
    // The 14-row placeholder that shipped before this dataset existed is what
    // this floor exists to prevent recurring. Raise it as coverage grows.
    final chambers = await EmergencyDataService.loadBundledChambers();
    expect(chambers.length, greaterThanOrEqualTo(100));
  });

  test('coverage is not concentrated in a single country', () async {
    final chambers = await EmergencyDataService.loadBundledChambers();
    final countries = chambers.map((c) => c.country).toSet();
    expect(countries.length, greaterThanOrEqualTo(20));
    expect(countries, contains('US'));
  });
```

- [ ] **Step 2: Run**

Run: `flutter test test/features/safety/data/chambers_dataset_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/features/safety/data/chambers_dataset_test.dart
git commit -m "test(safety): require the chamber dataset to stay a directory"
```

---

## Task 9: Emergency card presentation

**Files:**
- Modify: `lib/features/safety/presentation/pages/emergency_card_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 locale files
- Test: `test/features/safety/presentation/pages/emergency_card_page_test.dart`

**Interfaces:**
- Consumes: `ChamberListing`, `EmergencyCardData.nearbyChambers`, `EmergencyCardData.totalChamberCount` from Task 3.
- Produces: `_ChamberTile` taking a `ChamberListing`; a `_ChambersEmpty` widget.

- [ ] **Step 1: Add the strings to app_en.arb**

Next to the existing `emergencyCard_chamber*` keys:

```json
  "emergencyCard_chambersNearby": "Nearest chambers",
  "emergencyCard_chamberViewAll": "View all {count} chambers",
  "@emergencyCard_chamberViewAll": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "emergencyCard_chambersNoneNearby": "No chamber listed within range. Call the diver emergency hotline: they will route you to the nearest facility that can treat you.",
  "emergencyCard_chamberCapability_divingEmergency": "Treats diving injuries",
  "emergencyCard_chamberCapability_hyperbaricUnit": "Hospital hyperbaric unit",
  "emergencyCard_chamberCapability_elective": "Elective therapy only",
  "emergencyCard_chamberCapability_unknown": "Capability unconfirmed",
  "emergencyCard_chamberAvailability_h24": "24h",
  "emergencyCard_chamberAvailability_onCall": "On call",
  "emergencyCard_chamberAvailability_businessHours": "Business hours",
  "emergencyCard_chamberUnverified": "Not confirmed with the facility",
  "chambersDirectory_title": "Hyperbaric chambers",
  "chambersDirectory_search": "Search by name, city or country",
  "chambersDirectory_empty": "No chamber matches that search.",
  "chambersDirectory_count": "{count, plural, =1{1 chamber} other{{count} chambers}}",
  "@chambersDirectory_count": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
```

Translate every one into `ar`, `de`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`. "Elective therapy only" is the safety-critical string: it must not read as though the facility handles emergencies.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing widget tests**

Extend `emergency_card_page_test.dart`, following its existing harness:

```dart
testWidgets('shows the distance to each chamber', (tester) async {
  // Seed one chamber 42 km from the last dive site, pump the card, and expect
  // the formatted distance to appear.
  expect(find.textContaining('42 km'), findsOneWidget);
});

testWidgets('labels an elective clinic so it cannot be mistaken for a chamber',
    (tester) async {
  expect(find.text('Elective therapy only'), findsOneWidget);
});

testWidgets('offers the full directory when chambers are omitted',
    (tester) async {
  expect(find.textContaining('View all'), findsOneWidget);
});

testWidgets('points at the hotline when nothing is in range', (tester) async {
  expect(find.textContaining('No chamber listed within range'), findsOneWidget);
  expect(find.byType(ListTile), findsNothing);
});
```

Fill each body using the file's existing pump helper. Pin the locale to `en` on the test `MaterialApp`, since these assertions are string-based.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/safety/presentation/pages/emergency_card_page_test.dart`
Expected: FAIL on the new expectations.

- [ ] **Step 4: Rework the tile**

Replace `_ChamberTile` so it takes a `ChamberListing`, and render:

- title: the chamber name.
- subtitle line 1: distance via `UnitFormatter(ref.watch(settingsProvider)).formatGeoDistance(listing.distanceMeters!)` when distance is known, then city and country.
- subtitle line 2: capability label, availability label when not `unknown`, and the verification date.
- a `Chip` or coloured label for capability, using `theme.colorScheme.error` styling only for `elective`, so the visual weight matches the risk.
- `onTap: () => onCall(listing.chamber.callNumber)`, which prefers the dedicated emergency line.
- the existing hide and delete menu, unchanged.

Replace the section body with `data.nearbyChambers.isEmpty ? const _ChambersEmpty() : Column(...)`, followed by a `TextButton` with `l10n.emergencyCard_chamberViewAll(data.totalChamberCount)` pushing `/settings/diver-profile/emergency-card/chambers`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/safety/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib test
git commit -m "feat(safety): show distance and capability on the emergency card"
```

---

## Task 10: The directory page

**Files:**
- Create: `lib/features/safety/presentation/pages/chambers_directory_page.dart`
- Modify: `lib/core/router/app_router.dart:1198-1204`
- Test: `test/features/safety/presentation/pages/chambers_directory_page_test.dart`

**Interfaces:**
- Consumes: `chamberListingsProvider` from Task 3, the l10n keys from Task 9.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('lists every chamber', (tester) async {});
testWidgets('filters by name', (tester) async {});
testWidgets('filters by country', (tester) async {});
testWidgets('shows an empty state when nothing matches', (tester) async {});
```

Fill each body: pump `ChambersDirectoryPage` inside a `ProviderScope` overriding `chamberListingsProvider` with a fixture list, enter text in the search field, `await tester.pumpAndSettle()`, assert on visible names.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/safety/presentation/pages/chambers_directory_page_test.dart`
Expected: FAIL, the page does not exist.

- [ ] **Step 3: Write the page**

A `ConsumerStatefulWidget` holding the query in a `TextEditingController`. Body is a `ListView.builder` over the filtered listings, reusing the same tile presentation as the card. The filter is a case-insensitive `contains` across name, city, and country, matching how `DiveSiteApiService._searchBundledSites` filters its 3,612 rows. Show `chambersDirectory_count` in the app bar subtitle.

- [ ] **Step 4: Register the route**

In `app_router.dart`, inside the `emergency-card` route's `routes` list, after `add-chamber`:

```dart
                      GoRoute(
                        path: 'chambers',
                        name: 'chambersDirectory',
                        builder: (context, state) =>
                            const ChambersDirectoryPage(),
                      ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/safety/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib test
git commit -m "feat(safety): add the searchable chamber directory page"
```

---

## Task 11: Full verification

- [ ] **Step 1: Format the whole project**

```bash
dart format .
git diff --stat
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: zero issues. Infos are fatal in CI, so treat them as failures. Do not pipe the output through anything: a pipe masks the exit code.

- [ ] **Step 3: Run the Python tests**

Run: `python3 scripts/chamber_harvester_test.py`
Expected: PASS.

- [ ] **Step 4: Run the full Dart suite once**

Run: `flutter test`
Expected: PASS. Run it once, and do not overlap it with another local test run: concurrent runs produce phantom single-file failures. If exactly one file fails, rerun that file alone before believing it.

- [ ] **Step 5: Commit any formatting fallout and open the PR**

```bash
git add -A
git commit -m "chore: format"
git push -u origin chamber-directory-rework
gh pr create --title "Curated recompression chamber directory" --body "<summary>"
```

The PR body carries the substantive summary only: no attribution line, no session link.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| Data model, new fields | 1 |
| Dataset invariants, row floor | 2, 8 |
| Capability-banded ordering | 3 |
| Card cap of 5, 500 km empty state | 3, 9 |
| Harvester, validation gates | 4 |
| Registry lead parsers | 5 |
| Facility verification, `via` flag | 6 |
| Overlay, North America | 7 |
| Distance, chips, view all | 9 |
| Directory page, route | 10 |
| l10n across 11 locales | 9 |
| Preserved ids | 2 (test), 7 (data) |
| No schema migration | Global Constraints |

No spec requirement is unassigned.

**Type consistency:** `ChamberListing.distanceMeters` is metres throughout, including at the `_distanceKm(...) * 1000` conversion in Task 3 and the `formatGeoDistance` call in Task 9, which also takes metres. `callNumber` is defined in Task 1 and used in Task 9. `chamberListingsProvider` is defined in Task 3 and consumed in Tasks 9 and 10. `validate_chambers` and `merge_rows` are defined in Task 4 and consumed in Tasks 5 and 7.

**Known soft spots, deliberate:** Tasks 5, 9, and 10 specify test bodies to be filled against captured fixtures and the file's existing pump helper rather than shipping invented selectors and string literals. Writing exact DOM selectors for pages not yet captured, or exact widget-finder chains for a harness whose helper signature varies, would be fabrication dressed as precision. Every one of those steps names the fixture, the assertion, and the failure mode.
