# Site Location From Coordinates Implementation Plan

> **Schema version:** the column landed as **v166**, not v162. `origin/main`
> claimed v163 while this branch was open and v164/v165 were reserved for two
> other open PRs, so the migration, helper, ladder entry and test were
> renumbered in the merge commit. Every "v162" below is the number as planned.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill town and body of water (not only country and region) from a dive site's coordinates, in a synced per-diver language, with a per-site "Look up from coordinates" action and a bulk "Fill in missing location details" pass that never overwrites existing values.

**Architecture:** `LocationService.reverseGeocode` returns a `PlaceLookup` value and takes a language code; body of water comes from a second Nominatim request on the `natural` layer, filtered to water features, behind a shared one-request-per-second throttle. A new `diver_settings.place_name_language` column (v162) feeds every caller through `placeNameLanguageProvider`. The site form gains one shared fill-empty routine and a lookup button; a `SiteLocationBackfillService` walks sites through a column-patching repository method.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Drift, `dart:io HttpClient` against Nominatim, `geocoding` 5.x, `clock` + `fake_async` for time, `flutter gen-l10n` ARB localisation.

**Spec:** `docs/superpowers/specs/2026-08-25-site-location-from-coordinates-design.md`

## Global Constraints

- Worktree: `.claude/worktrees/issue-1187-site-geocoding`, branch `worktree-issue-1187-site-geocoding`. Every shell command below must start with `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-1187-site-geocoding && echo "PWD: $(pwd)" &&` (the Bash cwd silently resets between calls; a relative write in the wrong tree edits main).
- Never use an em-dash or en-dash as punctuation in code, comments, docs, strings, or commit messages. Use commas, colons, or two sentences.
- No emojis in code or comments.
- TDD: write the failing test, run it and watch it fail, implement, run it and watch it pass, then commit.
- `dart format .` before every commit. `flutter analyze` must report "No issues found" (infos are fatal in CI).
- Every new user-visible string goes into all 11 ARB files: `ar, de, en, es, fr, he, hu, it, nl, pt, zh` under `lib/l10n/arb/`. Regenerate with `flutter gen-l10n`. Placeholder `@key` metadata goes in `app_en.arb` (run `grep -c '"@' lib/l10n/arb/app_de.arb` once; if it is non-zero, mirror the metadata there too).
- Schema version for the new column: 162. If `grep -n "currentSchemaVersion = " lib/core/database/database.dart` already shows 162 or higher when Task 4 starts, use the next free number everywhere the plan says 162 (constant, ladder list, helper comment, test file name, sync defaults comment).
- Place name language default is `'en'`. Supported codes: `en, es, fr, de, it, nl, pt, hu, ar, he, zh`. There is no "follow app language" mode.
- Body of water is accepted only from Nominatim hits with `class == 'water'`, or `class == 'natural'` with `type` in `{bay, strait}`.
- The bulk pass writes only empty columns. Only the per-site Replace dialog may overwrite.
- The site save path never geocodes (existing Grand Turk / Bonaire tests in `test/features/dive_sites/presentation/pages/site_edit_page_test.dart` must keep passing unchanged).
- Do not push. Commits are local to the worktree branch.

---

## File Structure

**Create**
- `lib/core/services/geocoding/place_lookup.dart`: `PlaceLookup` value (country, region, locality, bodyOfWater, networkFailed).
- `lib/core/services/geocoding/nominatim_throttle.dart`: `NominatimThrottle`, serialises Nominatim requests one second apart using `clock.now()`.
- `lib/core/constants/place_name_language.dart`: `PlaceNameLanguage.supportedCodes`, `defaultCode`, `normalize`.
- `lib/features/settings/presentation/widgets/place_name_language_picker.dart`: `showPlaceNameLanguagePicker`, `PlaceNameLanguageList`, `placeNameLanguageLabel`.
- `lib/features/dive_sites/domain/services/site_location_merge.dart`: `SiteLocationDetails` and `mergeMissingLocationDetails`.
- `lib/features/dive_sites/domain/services/site_location_backfill_service.dart`: `SiteLocationBackfillService`, `BackfillSummary`.
- `lib/features/dive_sites/presentation/providers/site_location_backfill_provider.dart`: `BackfillState`, `SiteLocationBackfillNotifier`, `siteLocationBackfillProvider`.
- `lib/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart`: confirmation, progress dialog, summary snackbar.
- Tests listed per task.

**Modify**
- `lib/core/services/location_service.dart`: language parameter, `PlaceLookup` return, natural-layer lookup, throttle.
- `lib/core/database/database.dart`: column, v162 helper and ladder step.
- `lib/core/services/sync/sync_data_serializer.dart`: older-peer default.
- `lib/features/settings/presentation/providers/settings_providers.dart`, `lib/features/settings/data/repositories/diver_settings_repository.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/features/settings/presentation/pages/language_settings_page.dart`.
- `lib/features/dive_sites/presentation/pages/site_edit_page.dart`, `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart`, `lib/features/dive_sites/presentation/widgets/location_picker_map.dart`, `lib/features/dive_sites/presentation/pages/site_list_page.dart`, `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (if it carries the sites overflow menu), `lib/features/dive_sites/data/repositories/site_repository_impl.dart`.
- `lib/features/maps/presentation/widgets/region_download_dialog.dart`, `lib/features/dive_import/data/services/uddf_entity_importer.dart`, `lib/features/import_wizard/data/adapters/universal_adapter.dart`, `test/integration/uddf_test_importer.dart`.
- All 11 ARB files.

---

### Task 1: `PlaceLookup` and the language parameter

**Files:**
- Create: `lib/core/services/geocoding/place_lookup.dart`
- Modify: `lib/core/services/location_service.dart` (lines 14-35 `LocationResult`, 39-63 URI builders and locale pin, 101-222 `getCurrentLocation`, 224-313 `reverseGeocode` and `_reverseGeocodeWeb`)
- Modify callers so the tree compiles, all passing `languageCode: LocationService.defaultLanguageCode` for now (Task 7 wires the real setting): `lib/features/dive_sites/presentation/pages/site_edit_page.dart:212-215`, `lib/features/dive_sites/presentation/widgets/location_picker_map.dart:64-67` and `:99-102`, `lib/features/maps/presentation/widgets/region_download_dialog.dart:71-74`, `lib/features/dive_import/data/services/uddf_entity_importer.dart:1035-1038` and `:1108-1111`, `test/integration/uddf_test_importer.dart:442`, `test/features/dive_sites/presentation/pages/site_edit_page_test.dart:31-58` (`_FakeLocationService`), plus any other fake found by `grep -rn "reverseGeocode(" test/`.
- Test: `test/core/services/location_service_test.dart`

**Interfaces:**
- Produces: `class PlaceLookup { const PlaceLookup({String? country, String? region, String? locality, String? bodyOfWater, bool networkFailed = false}); const PlaceLookup.empty(); const PlaceLookup.unavailable(); bool get isEmpty; }`
- Produces: `Future<PlaceLookup> LocationService.reverseGeocode(double latitude, double longitude, {required String languageCode})`
- Produces: `static const String LocationService.defaultLanguageCode = 'en'`
- Produces: `static Uri LocationService.buildReverseGeocodeUri(double latitude, double longitude, {required String languageCode})`
- Produces: `Future<LocationResult?> LocationService.getCurrentLocation({bool includeGeocoding = true, Duration timeout = const Duration(seconds: 15), String languageCode = LocationService.defaultLanguageCode})`; `LocationResult` gains `final String? bodyOfWater` and `PlaceLookup get place`.

- [ ] **Step 1: Write the failing tests**

Append to the `reverseGeocode web fallback` group in `test/core/services/location_service_test.dart` (after the test named `'sends the English pin in both the URI and the request headers'`), and change every existing `service.reverseGeocode(a, b)` call in the file to `service.reverseGeocode(a, b, languageCode: 'en')`:

```dart
    test('sends the requested language in the URI and the headers', () async {
      final server = _FakeNominatim(
        body: jsonEncode(<String, dynamic>{
          'address': <String, dynamic>{'country': 'Schweiz'},
        }),
      );

      final result = await server.run(
        () => service.reverseGeocode(47.0276, 8.4006, languageCode: 'de'),
      );

      expect(result.country, 'Schweiz');
      expect(server.lastUri.queryParameters['accept-language'], 'de');
      expect(server.lastHeaders['accept-language'], 'de');
    });

    test('returns PlaceLookup.unavailable when the request throws', () async {
      final result = await HttpOverrides.runZoned(
        () => service.reverseGeocode(47.0, 8.4, languageCode: 'en'),
        createHttpClient: (_) => _ThrowingHttpClient(),
      );

      expect(result.isEmpty, isTrue);
      expect(result.networkFailed, isTrue);
    });
```

Add this fake next to `_FakeHttpClient`:

```dart
class _ThrowingHttpClient implements HttpClient {
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    throw const SocketException('offline');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

In the `native geocoder locale (#214)` group, change the test `'asks the geocoder for English results'` to call `service.reverseGeocode(36.0143, -5.6044, languageCode: 'es')` and expect `geocoding.locales` to equal `[const Locale('es')]`; keep the other two tests passing `languageCode: 'en'`.

In the `Nominatim URIs pin English results (#214)` group, change the reverse URI test to call `LocationService.buildReverseGeocodeUri(36.0, -5.6, languageCode: 'fr')` and expect `accept-language` to be `'fr'`.

- [ ] **Step 2: Run the test file to verify it fails**

Run: `flutter test test/core/services/location_service_test.dart`
Expected: compilation errors: `languageCode` is not a named parameter, `PlaceLookup`/`networkFailed` undefined.

- [ ] **Step 3: Create `PlaceLookup`**

`lib/core/services/geocoding/place_lookup.dart`:

```dart
/// What a reverse geocode of one coordinate found.
///
/// Every field is optional: a point in open sea has no locality, a point on
/// land has no body of water. [networkFailed] is true when the lookup could
/// not reach the geocoder at all, so a caller iterating many sites can stop
/// early instead of collecting one failure per site.
class PlaceLookup {
  const PlaceLookup({
    this.country,
    this.region,
    this.locality,
    this.bodyOfWater,
    this.networkFailed = false,
  });

  const PlaceLookup.empty() : this();

  const PlaceLookup.unavailable() : this(networkFailed: true);

  final String? country;
  final String? region;
  final String? locality;
  final String? bodyOfWater;
  final bool networkFailed;

  bool get isEmpty =>
      country == null &&
      region == null &&
      locality == null &&
      bodyOfWater == null;

  PlaceLookup copyWith({String? bodyOfWater}) => PlaceLookup(
    country: country,
    region: region,
    locality: locality,
    bodyOfWater: bodyOfWater ?? this.bodyOfWater,
    networkFailed: networkFailed,
  );

  @override
  String toString() =>
      'PlaceLookup(country: $country, region: $region, locality: $locality, '
      'bodyOfWater: $bodyOfWater, networkFailed: $networkFailed)';
}
```

- [ ] **Step 4: Thread the language through `LocationService`**

In `lib/core/services/location_service.dart`:

Add `import 'dart:io' show Platform, HttpClient, SocketException;` (replace the existing `dart:io` import) and `import 'package:submersion/core/services/geocoding/place_lookup.dart';`.

Replace `LocationResult` (lines 14-35) with:

```dart
/// Result of a location capture
class LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? country;
  final String? region;
  final String? locality;
  final String? bodyOfWater;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.country,
    this.region,
    this.locality,
    this.bodyOfWater,
  });

  /// The geocoded part of this result, in the shape the site form consumes.
  PlaceLookup get place => PlaceLookup(
    country: country,
    region: region,
    locality: locality,
    bodyOfWater: bodyOfWater,
  );

  @override
  String toString() =>
      'LocationResult(lat: $latitude, lng: $longitude, country: $country, region: $region)';
}
```

Replace the URI builder and locale pin block (lines 39-63) with:

```dart
  /// The language every existing row was geocoded in. Issue #214 pinned
  /// results to English because the platform geocoder answered in the device
  /// locale and split one country across 'Spanien' and 'España'. The pin is
  /// now a synced per-diver setting (issue #1187) whose default is this
  /// value, so unchanged users keep grouping exactly as before.
  static const String defaultLanguageCode = 'en';

  /// Nominatim reverse-geocode URI for the address layer.
  static Uri buildReverseGeocodeUri(
    double latitude,
    double longitude, {
    required String languageCode,
  }) => Uri.parse(
    'https://nominatim.openstreetmap.org/reverse?format=json'
    '&lat=$latitude&lon=$longitude&zoom=10&accept-language=$languageCode',
  );

  /// Nominatim forward-geocode URI, English-pinned: dive centres are matched
  /// by address text, not grouped in statistics.
  static Uri buildForwardGeocodeUri(String address) => Uri.parse(
    'https://nominatim.openstreetmap.org/search?format=json'
    '&q=${Uri.encodeComponent(address)}&limit=1&addressdetails=1'
    '&accept-language=$defaultLanguageCode',
  );
```

Delete the `_geocoderLocale` constant and its comment. Keep `debugForceNativeGeocoder` and `_useNativeGeocoder` as they are.

Change `getCurrentLocation`'s signature to:

```dart
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = defaultLanguageCode,
  }) async {
```

and its geocoding block (lines 191-213) to:

```dart
      PlaceLookup place = const PlaceLookup.empty();

      // Perform reverse geocoding if requested
      if (includeGeocoding) {
        place = await reverseGeocode(
          position.latitude,
          position.longitude,
          languageCode: languageCode,
        );
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        country: place.country,
        region: place.region,
        locality: place.locality,
        bodyOfWater: place.bodyOfWater,
      );
```

Replace `reverseGeocode` and `_reverseGeocodeWeb` (lines 224-313) with:

```dart
  /// Reverse geocode a coordinate into country, region and locality, in the
  /// language named by [languageCode] (an ISO 639-1 code such as 'en').
  ///
  /// Uses the platform geocoder on mobile and falls back to OpenStreetMap
  /// Nominatim everywhere else. Never throws: a geocoder that cannot be
  /// reached yields [PlaceLookup.unavailable].
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    try {
      _log.info('Reverse geocoding: $latitude, $longitude ($languageCode)');

      // Try native geocoding first (works on iOS/Android)
      if (_useNativeGeocoder) {
        try {
          // Built per call rather than cached in a static: construction only
          // asks the platform factory for an implementation, and a cached
          // instance would outlive the per-test factory fakes.
          final placemarks = await Geocoding().placemarkFromCoordinates(
            latitude,
            longitude,
            locale: Locale(languageCode),
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _log.info(
              'Native geocoded: ${place.locality}, ${place.administrativeArea}, ${place.country}',
            );
            return PlaceLookup(
              country: place.country,
              region: place.administrativeArea,
              locality: place.locality,
            );
          }
        } catch (e) {
          _log.warning('Native geocoding failed, trying web fallback: $e');
        }
      }

      // Fallback to OpenStreetMap Nominatim API (works on all platforms)
      return await _reverseGeocodeWeb(latitude, longitude, languageCode);
    } catch (e, stackTrace) {
      _log.error('Reverse geocoding failed', error: e, stackTrace: stackTrace);
      return const PlaceLookup.unavailable();
    }
  }

  /// Web-based reverse geocoding using OpenStreetMap Nominatim
  Future<PlaceLookup> _reverseGeocodeWeb(
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    try {
      final json = await _fetchNominatimJson(
        buildReverseGeocodeUri(
          latitude,
          longitude,
          languageCode: languageCode,
        ),
        languageCode,
      );
      final address = json?['address'] as Map<String, dynamic>?;
      if (address == null) return const PlaceLookup.empty();

      final country = address['country'] as String?;
      final region =
          address['state'] as String? ??
          address['province'] as String? ??
          address['region'] as String?;
      final locality =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String?;

      _log.info('Web geocoded: $locality, $region, $country');
      return PlaceLookup(country: country, region: region, locality: locality);
    } on SocketException catch (e) {
      _log.warning('Web reverse geocoding unreachable: $e');
      return const PlaceLookup.unavailable();
    } catch (e) {
      _log.warning('Web reverse geocoding failed: $e');
      return const PlaceLookup.empty();
    }
  }

  /// One Nominatim GET. Returns the decoded object, or null for a non-200
  /// status. Lets socket errors propagate so callers can tell "offline" from
  /// "nothing there". The client is closed in a finally so its sockets are
  /// released even when the body or the JSON decode throws.
  Future<Map<String, dynamic>?> _fetchNominatimJson(
    Uri url,
    String languageCode,
  ) async {
    final client = HttpClient();
    client.userAgent = 'Submersion Dive Log App';
    try {
      final request = await client.getUrl(url);
      request.headers.set('Accept-Language', languageCode);
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }
```

- [ ] **Step 5: Update the callers**

Each of these currently calls `reverseGeocode(lat, lon)`; add `languageCode: LocationService.defaultLanguageCode`:

- `lib/features/dive_sites/presentation/pages/site_edit_page.dart:212-215`
- `lib/features/dive_sites/presentation/widgets/location_picker_map.dart:64-67` and `:99-102`
- `lib/features/maps/presentation/widgets/region_download_dialog.dart:71-74`
- `lib/features/dive_import/data/services/uddf_entity_importer.dart:1035-1038` and `:1108-1111`
- `test/integration/uddf_test_importer.dart:442`

In `test/features/dive_sites/presentation/pages/site_edit_page_test.dart:31-58` change the fake's override to:

```dart
  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async => PlaceLookup(country: country, region: region);

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => LocationResult(
    latitude: 12.3,
    longitude: 45.6,
    accuracy: 5,
    country: country,
    region: region,
  );
```

and add `import 'package:submersion/core/services/geocoding/place_lookup.dart';`. Run `grep -rn "reverseGeocode(\|getCurrentLocation(" test/ lib/ | grep -v location_service` and fix every remaining fake or caller the same way.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/services/location_service_test.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart`
Expected: all pass.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
dart format . && git add -A lib/core/services test/core/services lib/features test/features test/integration && git commit -m "refactor(location): return PlaceLookup and take the geocode language per call (#1187)"
```

---

### Task 2: Body of water from the Nominatim natural layer

**Files:**
- Modify: `lib/core/services/location_service.dart` (`reverseGeocode`, new `buildNaturalFeatureUri`, `bodyOfWaterFromNaturalFeature`, `_lookupBodyOfWater`)
- Test: `test/core/services/location_service_test.dart`

**Interfaces:**
- Consumes: `PlaceLookup`, `_fetchNominatimJson` from Task 1.
- Produces: `static Uri LocationService.buildNaturalFeatureUri(double latitude, double longitude, {required String languageCode})`
- Produces: `static String? LocationService.bodyOfWaterFromNaturalFeature(Map<String, dynamic> json)` (pure, public for tests)
- `reverseGeocode` now fills `PlaceLookup.bodyOfWater` from a second request.

- [ ] **Step 1: Extend the fake server to answer per URI**

In `test/core/services/location_service_test.dart`, change `_FakeNominatim` so a test can serve different bodies to the address and natural requests:

```dart
class _FakeNominatim {
  _FakeNominatim({this.statusCode = 200, this.body = '{}', this.bodyFor});

  final int statusCode;
  final String body;

  /// When set, wins over [body] for the given request.
  final String? Function(Uri uri)? bodyFor;

  String bodyForUri(Uri uri) => bodyFor?.call(uri) ?? body;
  ...
```

and in `_FakeHttpClientRequest.close()` use `_server.bodyForUri(uri)` instead of `_server.body`.

Update the existing test `'sends the English pin in both the URI and the request headers'` (renamed in Task 1) and any test asserting `server.requestedUris, hasLength(1)`: a reverse geocode now makes two requests, so assert `hasLength(2)` and check `server.requestedUris.first` for the address URI.

- [ ] **Step 2: Write the failing tests**

Add a new group at the end of `main()`:

```dart
  group('body of water (issue #1187)', () {
    Map<String, dynamic> address() => <String, dynamic>{
      'address': <String, dynamic>{
        'country': 'Switzerland',
        'state': 'Lucerne',
        'village': 'Weggis',
      },
    };

    String? natural(Uri uri, Map<String, dynamic> hit) =>
        uri.queryParameters['layer'] == 'natural' ? jsonEncode(hit) : null;

    test('the natural-layer URI asks for water features only', () {
      final uri = LocationService.buildNaturalFeatureUri(
        47.027631,
        8.400640,
        languageCode: 'de',
      );
      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.path, '/reverse');
      expect(uri.queryParameters['layer'], 'natural');
      expect(uri.queryParameters['zoom'], '14');
      expect(uri.queryParameters['accept-language'], 'de');
      expect(uri.queryParameters['format'], 'json');
    });

    test('a lake on the natural layer becomes the body of water', () async {
      final server = _FakeNominatim(
        body: jsonEncode(address()),
        bodyFor: (uri) => natural(uri, {
          'class': 'water',
          'type': 'lake',
          'name': 'Lake Lucerne',
        }),
      );

      final result = await server.run(
        () => service.reverseGeocode(47.027631, 8.400640, languageCode: 'en'),
      );

      expect(result.locality, 'Weggis');
      expect(result.bodyOfWater, 'Lake Lucerne');
      expect(server.requestedUris, hasLength(2));
      expect(server.requestedUris.last.queryParameters['layer'], 'natural');
    });

    test('a bay is accepted', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'bay',
          'name': 'Naama Bay',
        }),
        'Naama Bay',
      );
    });

    test('a strait is accepted', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'strait',
          'name': 'Strait of Gibraltar',
        }),
        'Strait of Gibraltar',
      );
    });

    test('a mountain range is not a body of water', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'mountain_range',
          'name': 'Urner Alps',
        }),
        isNull,
      );
    });

    test('a saddle is not a body of water', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'natural',
          'type': 'saddle',
          'name': 'coll Roig',
        }),
        isNull,
      );
    });

    test('an unable-to-geocode answer yields no body of water', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'error': 'Unable to geocode',
        }),
        isNull,
      );
    });

    test('a water hit with a blank name is ignored', () {
      expect(
        LocationService.bodyOfWaterFromNaturalFeature({
          'class': 'water',
          'type': 'lake',
          'name': '',
        }),
        isNull,
      );
    });

    test('a failing natural-layer request keeps the address result', () async {
      var calls = 0;
      final server = _FakeNominatim(
        body: jsonEncode(address()),
        bodyFor: (uri) {
          if (uri.queryParameters['layer'] != 'natural') return null;
          calls++;
          return 'this is not json';
        },
      );

      final result = await server.run(
        () => service.reverseGeocode(47.027631, 8.400640, languageCode: 'en'),
      );

      expect(calls, 1);
      expect(result.country, 'Switzerland');
      expect(result.locality, 'Weggis');
      expect(result.bodyOfWater, isNull);
      expect(result.networkFailed, isFalse);
    });
  });
```

- [ ] **Step 3: Run the test file to verify it fails**

Run: `flutter test test/core/services/location_service_test.dart`
Expected: compile error, `buildNaturalFeatureUri` and `bodyOfWaterFromNaturalFeature` undefined.

- [ ] **Step 4: Implement the natural-layer lookup**

In `lib/core/services/location_service.dart`, after `buildReverseGeocodeUri` add:

```dart
  /// Nominatim reverse-geocode URI for the natural layer, which answers with
  /// the lake, bay or strait a point lies in. zoom=14 keeps the answer to a
  /// named feature rather than the whole region. Nominatim has no ocean
  /// polygons, so open-sea points come back "Unable to geocode".
  static Uri buildNaturalFeatureUri(
    double latitude,
    double longitude, {
    required String languageCode,
  }) => Uri.parse(
    'https://nominatim.openstreetmap.org/reverse?format=json'
    '&lat=$latitude&lon=$longitude&zoom=14&layer=natural'
    '&accept-language=$languageCode',
  );

  /// The name of a water feature from a natural-layer answer, or null when
  /// the hit is not water. The natural layer also carries mountain ranges,
  /// saddles and peaks; class `water` covers lakes, reservoirs and rivers,
  /// and bays and straits arrive as class `natural`.
  static String? bodyOfWaterFromNaturalFeature(Map<String, dynamic> json) {
    final osmClass = json['class'] as String?;
    final type = json['type'] as String?;
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    if (osmClass == 'water') return name;
    if (osmClass == 'natural' && (type == 'bay' || type == 'strait')) {
      return name;
    }
    return null;
  }
```

In `reverseGeocode`, replace the two `return PlaceLookup(...)` / `return await _reverseGeocodeWeb(...)` statements so both paths add the water lookup:

```dart
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _log.info(
              'Native geocoded: ${place.locality}, ${place.administrativeArea}, ${place.country}',
            );
            return _withBodyOfWater(
              PlaceLookup(
                country: place.country,
                region: place.administrativeArea,
                locality: place.locality,
              ),
              latitude,
              longitude,
              languageCode,
            );
          }
```

and

```dart
      // Fallback to OpenStreetMap Nominatim API (works on all platforms)
      final address = await _reverseGeocodeWeb(latitude, longitude, languageCode);
      if (address.networkFailed) return address;
      return _withBodyOfWater(address, latitude, longitude, languageCode);
```

Add the helpers after `_reverseGeocodeWeb`:

```dart
  Future<PlaceLookup> _withBodyOfWater(
    PlaceLookup address,
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    final water = await _lookupBodyOfWater(latitude, longitude, languageCode);
    return water == null ? address : address.copyWith(bodyOfWater: water);
  }

  /// Best-effort: any failure here leaves the address result untouched.
  Future<String?> _lookupBodyOfWater(
    double latitude,
    double longitude,
    String languageCode,
  ) async {
    try {
      final json = await _fetchNominatimJson(
        buildNaturalFeatureUri(
          latitude,
          longitude,
          languageCode: languageCode,
        ),
        languageCode,
      );
      if (json == null) return null;
      final water = bodyOfWaterFromNaturalFeature(json);
      _log.info('Natural layer: ${water ?? 'no water feature'}');
      return water;
    } catch (e) {
      _log.warning('Body of water lookup failed: $e');
      return null;
    }
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/services/location_service_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/core/services/location_service.dart test/core/services/location_service_test.dart && git commit -m "feat(location): read the body of water from the Nominatim natural layer (#1187)"
```

---

### Task 3: One Nominatim request per second

**Files:**
- Create: `lib/core/services/geocoding/nominatim_throttle.dart`
- Modify: `lib/core/services/location_service.dart` (`_fetchNominatimJson`, `forwardGeocode`)
- Test: `test/core/services/geocoding/nominatim_throttle_test.dart`, `test/core/services/location_service_test.dart` (setUp)

**Interfaces:**
- Produces: `class NominatimThrottle { NominatimThrottle({Duration minimumGap = const Duration(seconds: 1)}); Future<void> wait(); }`
- Produces: `static NominatimThrottle LocationService.throttle` (replaceable, `@visibleForTesting`).

- [ ] **Step 1: Write the failing throttle test**

`test/core/services/geocoding/nominatim_throttle_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';

void main() {
  test('the first request goes through immediately', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      var released = false;
      throttle.wait().then((_) => released = true);
      async.flushMicrotasks();
      expect(released, isTrue);
    });
  });

  test('a second request waits until a second has passed', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      final releasedAt = <Duration>[];
      final start = clock.now();
      throttle.wait().then((_) => releasedAt.add(clock.now().difference(start)));
      throttle.wait().then((_) => releasedAt.add(clock.now().difference(start)));
      async.flushMicrotasks();
      expect(releasedAt, [Duration.zero]);

      async.elapse(const Duration(milliseconds: 999));
      expect(releasedAt, hasLength(1));

      async.elapse(const Duration(milliseconds: 1));
      expect(releasedAt, [Duration.zero, const Duration(seconds: 1)]);
    });
  });

  test('requests spaced wider than the gap are not delayed', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      throttle.wait();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      var released = false;
      throttle.wait().then((_) => released = true);
      async.flushMicrotasks();
      expect(released, isTrue);
    });
  });

  test('three queued requests are released one second apart', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      final start = clock.now();
      final releasedAt = <Duration>[];
      for (var i = 0; i < 3; i++) {
        throttle.wait().then(
          (_) => releasedAt.add(clock.now().difference(start)),
        );
      }
      async.elapse(const Duration(seconds: 2));
      expect(releasedAt, [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });
  });

  test('a zero gap never delays', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle(minimumGap: Duration.zero);
      var count = 0;
      for (var i = 0; i < 5; i++) {
        throttle.wait().then((_) => count++);
      }
      async.flushMicrotasks();
      expect(count, 5);
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/geocoding/nominatim_throttle_test.dart`
Expected: compile error, `nominatim_throttle.dart` not found.

- [ ] **Step 3: Implement the throttle**

`lib/core/services/geocoding/nominatim_throttle.dart`:

```dart
import 'package:clock/clock.dart';

/// Spaces Nominatim requests at least [minimumGap] apart, process-wide.
///
/// OpenStreetMap's usage policy allows one request per second. A single
/// interactive lookup makes two requests (address layer, then natural
/// layer) and the bulk backfill makes hundreds, so the spacing lives in one
/// place instead of at every call site. Waiters are released in call order.
///
/// Uses `clock.now()` rather than `Stopwatch` so fake_async tests can drive
/// it; a `Stopwatch` is invisible to the synthetic clock.
class NominatimThrottle {
  NominatimThrottle({this.minimumGap = const Duration(seconds: 1)});

  final Duration minimumGap;

  DateTime? _lastRelease;
  Future<void> _queue = Future<void>.value();

  /// Completes when the caller may send its request.
  Future<void> wait() {
    final turn = _queue.then((_) => _holdUntilGapElapsed());
    _queue = turn;
    return turn;
  }

  Future<void> _holdUntilGapElapsed() async {
    final last = _lastRelease;
    if (last != null) {
      final sinceLast = clock.now().difference(last);
      if (sinceLast < minimumGap) {
        await Future<void>.delayed(minimumGap - sinceLast);
      }
    }
    _lastRelease = clock.now();
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/core/services/geocoding/nominatim_throttle_test.dart`
Expected: all pass.

- [ ] **Step 5: Wire the throttle into the service and its tests**

In `lib/core/services/location_service.dart` add `import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';` and, inside `LocationService` after `debugForceNativeGeocoder`:

```dart
  /// Process-wide spacing for every Nominatim request. Tests replace it with
  /// a zero-gap instance so lookups do not wait a real second each.
  @visibleForTesting
  static NominatimThrottle throttle = NominatimThrottle();
```

At the top of `_fetchNominatimJson`, before `final client = HttpClient();`, add `await throttle.wait();`. In `forwardGeocode`, add `await throttle.wait();` immediately before `final client = HttpClient();`.

In `test/core/services/location_service_test.dart` add a file-level `setUp` at the top of `main()`:

```dart
  setUp(() {
    LocationService.throttle = NominatimThrottle(minimumGap: Duration.zero);
  });
```

with `import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';`. Do the same in every test that overrides `HttpOverrides` to reach `LocationService` (`grep -rln "LocationService.instance" test/`).

Add one integration-style test to the `body of water` group proving the two requests of one lookup are spaced:

```dart
    test('the address and natural requests are a second apart', () {
      fakeAsync((async) {
        LocationService.throttle = NominatimThrottle();
        final start = clock.now();
        final seenAt = <Duration>[];
        final server = _FakeNominatim(
          body: jsonEncode(address()),
          bodyFor: (uri) {
            seenAt.add(clock.now().difference(start));
            return uri.queryParameters['layer'] == 'natural'
                ? jsonEncode({'class': 'water', 'type': 'lake', 'name': 'L'})
                : null;
          },
        );
        PlaceLookup? result;
        server
            .run(() => service.reverseGeocode(47.0, 8.4, languageCode: 'en'))
            .then((r) => result = r);
        async.elapse(const Duration(seconds: 1));
        expect(seenAt, [Duration.zero, const Duration(seconds: 1)]);
        expect(result?.bodyOfWater, 'L');
      });
    });
```

(imports: `package:clock/clock.dart`, `package:fake_async/fake_async.dart`, `package:submersion/core/services/geocoding/place_lookup.dart`.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/services`
Expected: all pass. Then `flutter analyze`: `No issues found!`

- [ ] **Step 7: Commit**

```bash
dart format . && git add lib/core/services test/core/services && git commit -m "feat(location): space Nominatim requests one second apart (#1187)"
```

---

### Task 4: Schema v162, `diver_settings.place_name_language`

**Files:**
- Create: `lib/core/constants/place_name_language.dart`
- Modify: `lib/core/database/database.dart` (`DiverSettings` table near line 1663, `currentSchemaVersion` line 3168, `migrationVersions` after line 3452, helper near `_assertO2CellMvDefaultColumn` line 4908, ladder step after line 8537)
- Test: `test/core/database/migration_v162_place_name_language_test.dart`, `test/core/constants/place_name_language_test.dart`

**Interfaces:**
- Produces: `abstract final class PlaceNameLanguage { static const String defaultCode = 'en'; static const List<String> supportedCodes; static String normalize(String? code); }`
- Produces: Drift column `DiverSettings.placeNameLanguage` (`place_name_language TEXT NOT NULL DEFAULT 'en'`), generated `DiverSetting.placeNameLanguage` and `DiverSettingsCompanion.placeNameLanguage`.

- [ ] **Step 1: Write the failing tests**

`test/core/constants/place_name_language_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/place_name_language.dart';

void main() {
  test('English is the default', () {
    expect(PlaceNameLanguage.defaultCode, 'en');
  });

  test('every app language except system is supported', () {
    expect(PlaceNameLanguage.supportedCodes, [
      'en',
      'es',
      'fr',
      'de',
      'it',
      'nl',
      'pt',
      'hu',
      'ar',
      'he',
      'zh',
    ]);
  });

  test('normalize keeps a supported code', () {
    expect(PlaceNameLanguage.normalize('de'), 'de');
  });

  test('normalize falls back to English for unknown, null or blank', () {
    expect(PlaceNameLanguage.normalize('xx'), 'en');
    expect(PlaceNameLanguage.normalize(null), 'en');
    expect(PlaceNameLanguage.normalize(''), 'en');
    expect(PlaceNameLanguage.normalize('system'), 'en');
  });
}
```

`test/core/database/migration_v162_place_name_language_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v162 shape: a diver_settings table without the place name
/// language column, stamped at v161 so the 161->162 upgrade runs.
NativeDatabase _dbAt161() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 161');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
    },
  );
}

void main() {
  test("v162 adds place_name_language defaulting to 'en'", () async {
    final db = AppDatabase(_dbAt161());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('place_name_language'));

    final row = await db
        .customSelect('SELECT place_name_language FROM diver_settings')
        .getSingle();
    expect(row.read<String>('place_name_language'), 'en');
  });

  test('fresh databases get the place_name_language column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('place_name_language'));
  });

  test('the helper no-ops when diver_settings is absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 161'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v162 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(162));
    expect(AppDatabase.migrationVersions, contains(162));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/constants/place_name_language_test.dart test/core/database/migration_v162_place_name_language_test.dart`
Expected: the constants test fails to compile (file missing); the migration test fails on `contains('place_name_language')` and `contains(162)`.

- [ ] **Step 3: Create the constants file**

`lib/core/constants/place_name_language.dart`:

```dart
/// The language reverse-geocoded place names are stored in.
///
/// A synced per-diver setting (issue #1187). Stored as the ISO 639-1 code,
/// never as a display name. English is the default because every row
/// written before the setting existed was geocoded in English (issue #214),
/// and mixing languages within one logbook splits a country across two
/// statistics buckets. There is deliberately no "follow app language"
/// value: the app language can be `system`, which resolves per device.
abstract final class PlaceNameLanguage {
  static const String defaultCode = 'en';

  /// The app's own languages, in the order the language picker lists them.
  static const List<String> supportedCodes = [
    'en',
    'es',
    'fr',
    'de',
    'it',
    'nl',
    'pt',
    'hu',
    'ar',
    'he',
    'zh',
  ];

  /// A supported code, or [defaultCode] for anything else. A synced peer on a
  /// newer build could send a code this build does not know.
  static String normalize(String? code) =>
      code != null && supportedCodes.contains(code) ? code : defaultCode;
}
```

- [ ] **Step 4: Add the column, helper, and ladder step**

In `lib/core/database/database.dart`:

After the `locale` column in `class DiverSettings` (line 1663) add:

```dart
  // Language for reverse-geocoded place names, ISO 639-1 (issue #1187, v162)
  TextColumn get placeNameLanguage =>
      text().withDefault(const Constant('en'))();
```

Change `static const int currentSchemaVersion = 161;` to `162`.

Append to `migrationVersions` after the `161,` entry:

```dart
    // v162: diver_settings.place_name_language, the synced language used for
    // reverse-geocoded country/region/town/body of water (issue #1187).
    162,
```

After `_assertO2CellMvDefaultColumn` add:

```dart
  /// v162: place_name_language on diver_settings (issue #1187). Defaults to
  /// 'en', the language every pre-v162 row was geocoded in (issue #214).
  Future<void> _assertPlaceNameLanguageColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('place_name_language')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN place_name_language TEXT "
        "NOT NULL DEFAULT 'en'",
      );
    }
  }
```

After the `if (from < 161) await reportProgress();` line add:

```dart
        // v162: place_name_language on diver_settings (issue #1187).
        if (from < 162) {
          await _assertPlaceNameLanguageColumn();
        }
        if (from < 162) await reportProgress();
```

- [ ] **Step 5: Regenerate Drift code and run the tests**

Run: `dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -1`
Expected: `wrote N outputs` with no errors.

Run: `flutter test test/core/constants/place_name_language_test.dart test/core/database/migration_v162_place_name_language_test.dart test/core/database`
Expected: all pass (the other ladder tests assert `greaterThanOrEqualTo`, so they stay green).

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/core/constants/place_name_language.dart lib/core/database/database.dart test/core/constants/place_name_language_test.dart test/core/database/migration_v162_place_name_language_test.dart && git commit -m "feat(db): v162 diver_settings.place_name_language (#1187)"
```

---

### Task 5: `AppSettings.placeNameLanguage`, repository, sync default, provider

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field near line 181 `locale`, constructor default near 488, `copyWith` parameter near 648 and assignment near 777, setter near `setLocale` line 1353, selector near `localeProvider` line 2001)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (insert companion near line 101, update companion near 261, row mapping near 465)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_applyDiverSettingDefaults`, after the `'defaultShowO2CellMv': false,` entry near line 5665)
- Test: `test/features/settings/data/repositories/diver_settings_place_name_language_test.dart`, `test/core/services/sync/sync_diver_settings_fallback_test.dart`

**Interfaces:**
- Consumes: `PlaceNameLanguage` from Task 4.
- Produces: `AppSettings.placeNameLanguage` (String, default `'en'`), `AppSettings.copyWith({String? placeNameLanguage})`, `SettingsNotifier.setPlaceNameLanguage(String code)`, `final placeNameLanguageProvider = Provider<String>`.

- [ ] **Step 1: Write the failing repository test**

`test/features/settings/data/repositories/diver_settings_place_name_language_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiverSettingsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverSettingsRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-1',
            name: 'Test Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('defaults to English', () {
    expect(const AppSettings().placeNameLanguage, 'en');
  });

  test('round-trips the place name language', () async {
    await repository.updateSettingsForDiver(
      'diver-1',
      const AppSettings(placeNameLanguage: 'de'),
    );

    final loaded = await repository.getSettingsForDiver('diver-1');
    expect(loaded.placeNameLanguage, 'de');
  });

  test('an unknown stored code loads as English', () async {
    await repository.updateSettingsForDiver('diver-1', const AppSettings());
    await (db.update(db.diverSettings)..where((t) => t.diverId.equals('diver-1')))
        .write(const DiverSettingsCompanion(placeNameLanguage: Value('xx')));

    final loaded = await repository.getSettingsForDiver('diver-1');
    expect(loaded.placeNameLanguage, 'en');
  });
}
```

Before writing this, confirm the repository's read and write method names and the `Divers` insert companion's required fields with `grep -n "Future<AppSettings> get\|Future<void> updateSettingsForDiver" lib/features/settings/data/repositories/diver_settings_repository.dart` and `grep -n "class DiversCompanion" -A 40 lib/core/database/database.g.dart | grep required`; adjust the test to the real names if they differ.

- [ ] **Step 2: Extend the sync fallback test**

Add to `test/core/services/sync/sync_diver_settings_fallback_test.dart`, following the shape of the existing tests:

```dart
  test(
    'applies a pre-v162 diver_settings payload missing placeNameLanguage',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds-162',
              diverId: 'diver-1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds-162');
      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('placeNameLanguage');
      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-162'))).go();

      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-162'))).getSingle();
      expect(row.placeNameLanguage, 'en');
    },
  );
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/settings/data/repositories/diver_settings_place_name_language_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart`
Expected: the repository test fails to compile (`placeNameLanguage` is not a named parameter of `AppSettings`); the sync test throws in `DiverSetting.fromJson` on the missing key.

- [ ] **Step 4: Implement**

`lib/features/settings/presentation/providers/settings_providers.dart`:

- Add `import 'package:submersion/core/constants/place_name_language.dart';`.
- After `final String locale;` (line 181) add:

```dart
  /// ISO 639-1 code for reverse-geocoded place names (issue #1187). Synced
  /// with the diver so every device stores the same spelling.
  final String placeNameLanguage;
```

- In the constructor after `this.locale = 'system',` add `this.placeNameLanguage = PlaceNameLanguage.defaultCode,`.
- In `copyWith` parameters after `String? locale,` add `String? placeNameLanguage,`; in the assignments after `locale: locale ?? this.locale,` add `placeNameLanguage: placeNameLanguage ?? this.placeNameLanguage,`.
- After `setLocale` add:

```dart
  Future<void> setPlaceNameLanguage(String code) async {
    state = state.copyWith(
      placeNameLanguage: PlaceNameLanguage.normalize(code),
    );
    await _saveSettings();
  }
```

- After `localeProvider` add:

```dart
/// The language new reverse-geocode results are stored in (issue #1187).
final placeNameLanguageProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider.select((s) => s.placeNameLanguage));
});
```

`lib/features/settings/data/repositories/diver_settings_repository.dart`:

- Add `import 'package:submersion/core/constants/place_name_language.dart';`.
- Insert companion: after `locale: Value(s.locale),` add `placeNameLanguage: Value(s.placeNameLanguage),`.
- Update companion: after `locale: Value(settings.locale),` add `placeNameLanguage: Value(settings.placeNameLanguage),`.
- Row mapping: after `locale: row.locale,` add `placeNameLanguage: PlaceNameLanguage.normalize(row.placeNameLanguage),`.

`lib/core/services/sync/sync_data_serializer.dart`, in `_applyDiverSettingDefaults` after the `'defaultShowO2CellMv': false,` entry:

```dart
      // v162: seed it so payloads predating the column hydrate instead of
      // throwing in DiverSetting.fromJson (issue #1187).
      'placeNameLanguage': 'en',
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/settings test/core/services/sync/sync_diver_settings_fallback_test.dart`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/features/settings lib/core/services/sync/sync_data_serializer.dart test/features/settings test/core/services/sync/sync_diver_settings_fallback_test.dart && git commit -m "feat(settings): synced place name language preference (#1187)"
```

---

### Task 6: Settings row and picker, with localisation

**Files:**
- Create: `lib/features/settings/presentation/widgets/place_name_language_picker.dart`
- Modify: `lib/features/settings/presentation/pages/language_settings_page.dart` (rename `_LocaleOption` to `LocaleOption`, lines 12-43 and its class declaration further down)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (after the coordinate-format `_buildUnitTile`, lines 548-557; import)
- Modify: all 11 ARB files
- Test: `test/features/settings/presentation/widgets/place_name_language_picker_test.dart`

**Interfaces:**
- Consumes: `placeNameLanguageProvider`, `SettingsNotifier.setPlaceNameLanguage`, `PlaceNameLanguage.supportedCodes`.
- Produces: `void showPlaceNameLanguagePicker(BuildContext context, WidgetRef ref, AppSettings settings)`, `class PlaceNameLanguageList`, `String placeNameLanguageLabel(String code)` (returns the native name, e.g. `Deutsch`), `class LocaleOption` (public, in `language_settings_page.dart`).
- Produces l10n keys: `settings_placeNameLanguage_title`, `settings_placeNameLanguage_subtitle`.

- [ ] **Step 1: Add the strings to every ARB**

`lib/l10n/arb/app_en.arb`, next to `settings_coordinateFormat_subtitle`:

```json
  "settings_placeNameLanguage_title": "Place name language",
  "settings_placeNameLanguage_subtitle": "Used when country, region, town and body of water are looked up from coordinates. Existing sites are not changed.",
```

The other ten, each next to their own `settings_coordinateFormat_subtitle`:

- `app_de.arb`: `"Sprache der Ortsnamen"` / `"Wird verwendet, wenn Land, Region, Ort und Gewässer aus Koordinaten ermittelt werden. Bestehende Tauchplätze werden nicht geändert."`
- `app_es.arb`: `"Idioma de los nombres de lugar"` / `"Se usa al obtener país, región, localidad y masa de agua a partir de las coordenadas. Los puntos de buceo existentes no cambian."`
- `app_fr.arb`: `"Langue des noms de lieux"` / `"Utilisée lorsque le pays, la région, la ville et le plan d'eau sont déduits des coordonnées. Les sites existants ne sont pas modifiés."`
- `app_it.arb`: `"Lingua dei nomi dei luoghi"` / `"Usata quando paese, regione, città e specchio d'acqua vengono ricavati dalle coordinate. I siti esistenti non vengono modificati."`
- `app_nl.arb`: `"Taal van plaatsnamen"` / `"Gebruikt wanneer land, regio, plaats en water uit coördinaten worden opgezocht. Bestaande duikstekken worden niet gewijzigd."`
- `app_pt.arb`: `"Idioma dos nomes de lugares"` / `"Usado quando país, região, cidade e corpo de água são obtidos a partir das coordenadas. Os locais existentes não são alterados."`
- `app_hu.arb`: `"Helynevek nyelve"` / `"Akkor használjuk, amikor az ország, régió, település és víztest a koordinátákból kerül lekérdezésre. A meglévő merülőhelyek nem változnak."`
- `app_ar.arb`: `"لغة أسماء الأماكن"` / `"تُستخدم عند البحث عن البلد والمنطقة والبلدة والمسطح المائي من الإحداثيات. لا يتم تغيير المواقع الحالية."`
- `app_he.arb`: `"שפת שמות המקומות"` / `"בשימוש כאשר מדינה, אזור, עיר וגוף מים נשלפים מהקואורדינטות. אתרים קיימים אינם משתנים."`
- `app_zh.arb`: `"地名语言"` / `"根据坐标查找国家、地区、城镇和水域时使用。现有潜点不会更改。"`

Run: `flutter gen-l10n`
Expected: no errors; `grep -c placeNameLanguage lib/l10n/arb/app_localizations.dart` prints a number greater than 0.

- [ ] **Step 2: Write the failing picker test**

`test/features/settings/presentation/widgets/place_name_language_picker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/place_name_language_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Stands in for SettingsNotifier so the picker's saves can be inspected
/// without a database. Only setPlaceNameLanguage is exercised here.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  final List<String> saved;

  _RecordingSettingsNotifier(super.initial, this.saved);

  @override
  Future<void> setPlaceNameLanguage(String code) async {
    state = state.copyWith(placeNameLanguage: code);
    saved.add(code);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> saved;
  late ProviderContainer container;

  setUp(() {
    saved = [];
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _RecordingSettingsNotifier(const AppSettings(), saved),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showPlaceNameLanguagePicker(
              context,
              ref,
              container.read(settingsProvider),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers every supported language by its native name', (
    tester,
  ) async {
    await openPicker(tester);
    for (final name in ['English', 'Deutsch', 'Español', 'Magyar', '简体中文']) {
      expect(find.text(name), findsOneWidget, reason: 'missing $name');
    }
    expect(find.text('System Default'), findsNothing);
  });

  testWidgets('marks the current language', (tester) async {
    await openPicker(tester);
    final tile = find.ancestor(
      of: find.text('English'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('selecting a language saves it and closes', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(saved, ['de']);
    expect(find.byType(PlaceNameLanguageList), findsNothing);
  });

  test('the label is the native name, falling back to the code', () {
    expect(placeNameLanguageLabel('de'), 'Deutsch');
    expect(placeNameLanguageLabel('en'), 'English');
    expect(placeNameLanguageLabel('xx'), 'xx');
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/settings/presentation/widgets/place_name_language_picker_test.dart`
Expected: compile error, picker file missing.

- [ ] **Step 4: Make `LocaleOption` public and write the picker**

In `lib/features/settings/presentation/pages/language_settings_page.dart` rename `_LocaleOption` to `LocaleOption` everywhere in the file (`grep -n "_LocaleOption" lib/ test/` must then return nothing).

`lib/features/settings/presentation/widgets/place_name_language_picker.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/place_name_language.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/language_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The place name language picker (issue #1187), split out of
/// `settings_page.dart` so it can be pumped directly in tests.
///
/// The options are the app's own languages minus "System Default": the value
/// must resolve to the same code on every one of the diver's devices, which
/// a device-dependent choice cannot promise.

/// Opens the place name language picker.
void showPlaceNameLanguagePicker(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        AppLocalizations.of(context).settings_placeNameLanguage_title,
      ),
      content: PlaceNameLanguageList(
        selected: settings.placeNameLanguage,
        onSelected: (code) {
          Navigator.of(dialogContext).pop();
          ref.read(settingsProvider.notifier).setPlaceNameLanguage(code);
        },
      ),
    ),
  );
}

/// The supported languages, each by its native name.
class PlaceNameLanguageList extends StatelessWidget {
  const PlaceNameLanguageList({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final void Function(String code) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final code in PlaceNameLanguage.supportedCodes)
            ListTile(
              title: Text(placeNameLanguageLabel(code)),
              trailing: code == selected
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => onSelected(code),
            ),
        ],
      ),
    );
  }
}

/// The native name of a language code, from the app language list, so there
/// is no second hand-maintained list of names.
String placeNameLanguageLabel(String code) {
  for (final option in LanguageSettingsPage.supportedLocales) {
    if (option.code == code) return option.nativeName;
  }
  return code;
}
```

In `lib/features/settings/presentation/pages/settings_page.dart` add `import 'package:submersion/features/settings/presentation/widgets/place_name_language_picker.dart';` and, directly after the coordinate-format `_buildUnitTile(...)` call (line 557), add:

```dart
                const Divider(height: 1),
                ListTile(
                  title: Text(context.l10n.settings_placeNameLanguage_title),
                  subtitle: Text(
                    context.l10n.settings_placeNameLanguage_subtitle,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        placeNameLanguageLabel(settings.placeNameLanguage),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () =>
                      showPlaceNameLanguagePicker(context, ref, settings),
                ),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/settings`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/features/settings lib/l10n test/features/settings && git commit -m "feat(settings): place name language row and picker (#1187)"
```

---

### Task 7: Every geocode caller uses the diver's place name language

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (`_geocodeSeed` line 210, `_useMyLocation` line 1344)
- Modify: `lib/features/dive_sites/presentation/widgets/location_picker_map.dart` (`_updateLocationPreview` line 64, `_confirmSelection` line 99)
- Modify: `lib/features/maps/presentation/widgets/region_download_dialog.dart` (line 71; check whether the widget is a `ConsumerStatefulWidget`, and if not convert it, keeping everything else unchanged)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (constructor line 230, lookups at 1035 and 1108)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (line 525)
- Test: `test/features/dive_sites/presentation/pages/site_edit_language_test.dart`, `test/features/dive_import/data/services/uddf_entity_importer_language_test.dart`

**Interfaces:**
- Consumes: `placeNameLanguageProvider` (Task 5), `reverseGeocode(..., languageCode:)` (Task 1).
- Produces: `UddfEntityImporter({..., String placeNameLanguage = LocationService.defaultLanguageCode})`.

- [ ] **Step 1: Write the failing site-form test**

`test/features/dive_sites/presentation/pages/site_edit_language_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Records the language every geocode was asked for.
class _RecordingLocationService implements LocationService {
  final List<String> languages = [];

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    languages.add(languageCode);
    return const PlaceLookup(country: 'Schweiz', region: 'Luzern');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A settings notifier that starts with German place names.
class _GermanSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _GermanSettings() : super(const AppSettings(placeNameLanguage: 'de'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('seeding a new site geocodes in the place name language', (
    tester,
  ) async {
    final location = _RecordingLocationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          validatedCurrentDiverIdProvider.overrideWith((_) async => null),
          settingsProvider.overrideWith((_) => _GermanSettings()),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              initialLocation: const GeoPoint(47.027631, 8.400640),
              embedded: true,
              onSaved: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(location.languages, ['de']);
    expect(find.text('Schweiz'), findsOneWidget);
  });
}
```

Check `test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart` for the exact set of overrides that page needs (for example `shareByDefaultProvider`) and mirror them; the list above is the minimum from `site_edit_page_test.dart`.

- [ ] **Step 2: Write the failing importer test**

`test/features/dive_import/data/services/uddf_entity_importer_language_test.dart`: read the top of `test/features/dive_import/data/services/uddf_entity_importer_test.dart` for how an importer is constructed with mock repositories and how a site with coordinates but no country is fed in (`grep -n "reverseGeocode\|latitude" test/features/dive_import/data/services/uddf_entity_importer_test.dart`). Write one test that:

1. Installs `HttpOverrides` with a fake client capturing the `accept-language` query parameter (copy `_FakeNominatim` and its three helper classes from `test/core/services/location_service_test.dart` into this file, or extract them to `test/helpers/fake_nominatim.dart` first and import from both places).
2. Constructs `UddfEntityImporter(placeNameLanguage: 'fr')` and imports one site with latitude/longitude and no country.
3. Asserts the captured URI has `accept-language=fr`.

Also set `LocationService.throttle = NominatimThrottle(minimumGap: Duration.zero);` in `setUp`.

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_language_test.dart test/features/dive_import/data/services/uddf_entity_importer_language_test.dart`
Expected: the site test sees `['en']`; the importer test fails to compile (`placeNameLanguage` is not a parameter).

- [ ] **Step 4: Wire the provider**

`site_edit_page.dart`:
- `_geocodeSeed`: replace `languageCode: LocationService.defaultLanguageCode` with `languageCode: ref.read(placeNameLanguageProvider)`.
- `_useMyLocation`: `locationService.getCurrentLocation(includeGeocoding: true, languageCode: ref.read(placeNameLanguageProvider))`.

`location_picker_map.dart`: in both `_updateLocationPreview` and `_confirmSelection`, replace the constant with `ref.read(placeNameLanguageProvider)` (the widget is already a `ConsumerStatefulWidget`; add the settings import if missing).

`region_download_dialog.dart`: replace the constant with `ref.read(placeNameLanguageProvider)`; if the widget is not a `ConsumerStatefulWidget`, change `StatefulWidget` to `ConsumerStatefulWidget` and `State<...>` to `ConsumerState<...>` and add `import 'package:submersion/core/providers/provider.dart';` plus the settings providers import.

`uddf_entity_importer.dart`:

```dart
  final TankPresetEntity? _defaultTankPreset;
  final int _defaultStartPressure;
  final bool _applyDefaultTankToImports;
  final String _placeNameLanguage;

  UddfEntityImporter({
    TankPresetEntity? defaultTankPreset,
    int defaultStartPressure = 200,
    bool applyDefaultTankToImports = false,
    String placeNameLanguage = LocationService.defaultLanguageCode,
  }) : _defaultTankPreset = defaultTankPreset,
       _defaultStartPressure = defaultStartPressure,
       _applyDefaultTankToImports = applyDefaultTankToImports,
       _placeNameLanguage = placeNameLanguage;
```

and both lookups pass `languageCode: _placeNameLanguage`.

`universal_adapter.dart` line 525:

```dart
    final importer = UddfEntityImporter(
      defaultTankPreset: defaultTankPreset,
      defaultStartPressure: settings.defaultStartPressure,
      applyDefaultTankToImports: settings.applyDefaultTankToImports,
      placeNameLanguage: settings.placeNameLanguage,
    );
```

Finally `grep -rn "LocationService.defaultLanguageCode" lib/` must list only `location_service.dart` and the `UddfEntityImporter` default parameter.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites test/features/dive_import test/features/maps test/features/import_wizard`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 6: Commit**

```bash
dart format . && git add -A lib test && git commit -m "feat(location): geocode in the diver's place name language (#1187)"
```

---

### Task 8: The "only empty fields" rule and the repository patch

**Files:**
- Create: `lib/features/dive_sites/domain/services/site_location_merge.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (add `fillMissingLocationDetails` next to `applyImportedMetadata`, line 238)
- Test: `test/features/dive_sites/domain/services/site_location_merge_test.dart`, `test/features/dive_sites/data/repositories/site_repository_fill_missing_location_test.dart`

**Interfaces:**
- Consumes: `PlaceLookup` (Task 1).
- Produces: `class SiteLocationDetails { const SiteLocationDetails({String? country, String? region, String? city, String? bodyOfWater}); factory SiteLocationDetails.ofSite(DiveSite site); bool get isEmpty; }`
- Produces: `SiteLocationDetails? mergeMissingLocationDetails({required SiteLocationDetails current, required PlaceLookup found})`: the values to write (null where nothing changes), or null when nothing changes.
- Produces: `Future<bool> SiteRepository.fillMissingLocationDetails(String siteId, PlaceLookup found)`.

- [ ] **Step 1: Write the failing merge tests**

`test/features/dive_sites/domain/services/site_location_merge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';

void main() {
  const found = PlaceLookup(
    country: 'Switzerland',
    region: 'Lucerne',
    locality: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
  );

  test('fills every empty field', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(),
      found: found,
    );
    expect(merged, isNotNull);
    expect(merged!.country, 'Switzerland');
    expect(merged.region, 'Lucerne');
    expect(merged.city, 'Weggis');
    expect(merged.bodyOfWater, 'Lake Lucerne');
  });

  test('leaves filled fields alone and returns only the empty ones', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(
        country: 'Schweiz',
        region: 'Luzern',
      ),
      found: found,
    );
    expect(merged!.country, isNull);
    expect(merged.region, isNull);
    expect(merged.city, 'Weggis');
    expect(merged.bodyOfWater, 'Lake Lucerne');
  });

  test('treats whitespace-only as empty', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(city: '   '),
      found: const PlaceLookup(locality: 'Weggis'),
    );
    expect(merged!.city, 'Weggis');
  });

  test('ignores blank found values', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(),
      found: const PlaceLookup(country: '', locality: ' '),
    );
    expect(merged, isNull);
  });

  test('returns null when every field is already filled', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
      ),
      found: found,
    );
    expect(merged, isNull);
  });

  test('returns null when the lookup found nothing', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(),
      found: const PlaceLookup.empty(),
    );
    expect(merged, isNull);
  });

  test('ofSite reads the four location columns', () {
    const site = DiveSite(
      id: 's',
      name: 'n',
      country: 'Switzerland',
      city: 'Weggis',
    );
    final details = SiteLocationDetails.ofSite(site);
    expect(details.country, 'Switzerland');
    expect(details.region, isNull);
    expect(details.city, 'Weggis');
    expect(details.bodyOfWater, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/domain/services/site_location_merge_test.dart`
Expected: compile error, file missing.

- [ ] **Step 3: Implement the merge**

`lib/features/dive_sites/domain/services/site_location_merge.dart`:

```dart
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The four site columns a reverse geocode can fill.
class SiteLocationDetails {
  const SiteLocationDetails({
    this.country,
    this.region,
    this.city,
    this.bodyOfWater,
  });

  factory SiteLocationDetails.ofSite(DiveSite site) => SiteLocationDetails(
    country: site.country,
    region: site.region,
    city: site.city,
    bodyOfWater: site.bodyOfWater,
  );

  final String? country;
  final String? region;
  final String? city;
  final String? bodyOfWater;

  bool get isEmpty =>
      country == null && region == null && city == null && bodyOfWater == null;
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// The single home of the "only fill empty fields" rule (issue #1187).
///
/// Returns the values to write, with null for every field that must not
/// change, or null when nothing should change. A field is filled only when
/// [current] is blank and [found] has a non-blank value for it; manual edits
/// and deliberate clears are never overwritten here. The lookup's locality
/// maps to the site's city column.
SiteLocationDetails? mergeMissingLocationDetails({
  required SiteLocationDetails current,
  required PlaceLookup found,
}) {
  String? fill(String? existing, String? candidate) =>
      _isBlank(existing) && !_isBlank(candidate) ? candidate!.trim() : null;

  final merged = SiteLocationDetails(
    country: fill(current.country, found.country),
    region: fill(current.region, found.region),
    city: fill(current.city, found.locality),
    bodyOfWater: fill(current.bodyOfWater, found.bodyOfWater),
  );
  return merged.isEmpty ? null : merged;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/dive_sites/domain/services/site_location_merge_test.dart`
Expected: all pass.

- [ ] **Step 5: Write the failing repository test**

`test/features/dive_sites/data/repositories/site_repository_fill_missing_location_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const found = PlaceLookup(
    country: 'Switzerland',
    region: 'Lucerne',
    locality: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
  );

  test('fills only the empty columns and reports a change', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        name: 'Hertenstein',
        country: 'Schweiz',
        rating: 4,
        location: GeoPoint(47.027631, 8.400640),
      ),
    );

    final changed = await sites.fillMissingLocationDetails('s1', found);

    expect(changed, isTrue);
    final stored = await sites.getSiteById('s1');
    expect(stored!.country, 'Schweiz', reason: 'filled values are kept');
    expect(stored.region, 'Lucerne');
    expect(stored.city, 'Weggis');
    expect(stored.bodyOfWater, 'Lake Lucerne');
    expect(stored.rating, 4, reason: 'unrelated columns untouched');
  });

  test('marks the site pending for sync when it changed', () async {
    await sites.createSite(const DiveSite(id: 's2', name: 'n'));
    await (db.delete(db.syncRecords)..where((t) => t.recordId.equals('s2'))).go();

    await sites.fillMissingLocationDetails('s2', found);

    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals('s2'))).get();
    expect(pending, isNotEmpty);
  });

  test('writes nothing and reports no change when all filled', () async {
    await sites.createSite(
      const DiveSite(
        id: 's3',
        name: 'n',
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
      ),
    );
    final before = await sites.getSiteById('s3');
    await (db.delete(db.syncRecords)..where((t) => t.recordId.equals('s3'))).go();

    final changed = await sites.fillMissingLocationDetails('s3', found);

    expect(changed, isFalse);
    expect(await sites.getSiteById('s3'), before);
    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals('s3'))).get();
    expect(pending, isEmpty, reason: 'no write, no sync record');
  });

  test('returns false for an unknown site', () async {
    expect(await sites.fillMissingLocationDetails('nope', found), isFalse);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_fill_missing_location_test.dart`
Expected: compile error, `fillMissingLocationDetails` undefined.

- [ ] **Step 7: Implement the repository method**

In `lib/features/dive_sites/data/repositories/site_repository_impl.dart` add the imports `import 'package:submersion/core/services/geocoding/place_lookup.dart';` and `import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';`, then before `applyImportedMetadata`:

```dart
  /// Fills whichever of country, region, city and body of water are still
  /// empty on [siteId] from [found], leaving every other column untouched
  /// (issue #1187). Returns true when a column was written. The row is
  /// marked pending for sync only when something changed.
  Future<bool> fillMissingLocationDetails(
    String siteId,
    PlaceLookup found,
  ) async {
    try {
      return await _db.transaction(() async {
        final row = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).getSingleOrNull();
        if (row == null) return false;

        final merged = mergeMissingLocationDetails(
          current: SiteLocationDetails.ofSite(_mapRowToSite(row)),
          found: found,
        );
        if (merged == null) return false;

        final now = DateTime.now().millisecondsSinceEpoch;
        await (_db.update(_db.diveSites)..where((t) => t.id.equals(siteId)))
            .write(
              DiveSitesCompanion(
                country: merged.country == null
                    ? const Value.absent()
                    : Value(merged.country),
                region: merged.region == null
                    ? const Value.absent()
                    : Value(merged.region),
                city: merged.city == null
                    ? const Value.absent()
                    : Value(merged.city),
                bodyOfWater: merged.bodyOfWater == null
                    ? const Value.absent()
                    : Value(merged.bodyOfWater),
                updatedAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveSites',
          recordId: siteId,
          localUpdatedAt: now,
        );
        return true;
      }).then((changed) {
        if (changed) SyncEventBus.notifyLocalChange();
        return changed;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to fill location details for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

If `markRecordPending` opens its own transaction and Drift complains about nesting, move the `markRecordPending` call after the transaction block (still guarded by `changed`).

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_fill_missing_location_test.dart test/features/dive_sites/domain/services/site_location_merge_test.dart`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 9: Commit**

```bash
dart format . && git add lib/features/dive_sites test/features/dive_sites && git commit -m "feat(sites): fill-empty merge rule and repository patch for location details (#1187)"
```

---

### Task 9: The site form fills town and body of water through one routine

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/location_picker_map.dart` (`PickedLocation` lines 16-30, `_confirmSelection` lines 96-114)
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (`_geocodeSeed` lines 210-226, `_useMyLocation` lines 1372-1382, `_pickFromMap` lines 1424-1436)
- Test: `test/features/dive_sites/presentation/pages/site_edit_fill_location_test.dart`

**Interfaces:**
- Consumes: `PlaceLookup`, `LocationResult.place` (Task 1), `mergeMissingLocationDetails` and `SiteLocationDetails` (Task 8).
- Produces: `PickedLocation({required double latitude, required double longitude, required PlaceLookup place})`.
- Produces (private to the page): `bool _applyPlaceLookup(PlaceLookup lookup, {required bool overwrite})`: writes the four controllers, returns whether any changed.

- [ ] **Step 1: Write the failing test**

`test/features/dive_sites/presentation/pages/site_edit_fill_location_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../../helpers/test_database.dart';

Finder _rowField(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(SuggestionFormRow),
  ),
  matching: find.byType(TextFormField),
);

class _FakeLocationService implements LocationService {
  _FakeLocationService(this.place);

  final PlaceLookup place;

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async => place;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => LocationResult(
    latitude: 47.027631,
    longitude: 8.400640,
    accuracy: 5,
    country: place.country,
    region: place.region,
    locality: place.locality,
    bodyOfWater: place.bodyOfWater,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _weggis = PlaceLookup(
  country: 'Switzerland',
  region: 'Lucerne',
  locality: 'Weggis',
  bodyOfWater: 'Lake Lucerne',
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? siteId,
    GeoPoint? initialLocation,
    PlaceLookup place = _weggis,
    DiveSite? seeded,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          shareByDefaultProvider.overrideWith((_) async => false),
          validatedCurrentDiverIdProvider.overrideWith((_) async => null),
          if (seeded != null)
            siteProvider(seeded.id).overrideWith((_) async => seeded),
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(place),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: siteId,
              initialLocation: initialLocation,
              embedded: true,
              onSaved: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Use my location fills town and body of water', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.text('Weggis'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsOneWidget);
    expect(find.text('Switzerland'), findsOneWidget);
  });

  testWidgets('Use my location never overwrites a filled field', (
    tester,
  ) async {
    final repo = SiteRepository();
    final seeded = await repo.createSite(
      const DiveSite(id: '', name: 'Hertenstein', city: 'Hertenstein'),
    );
    await pumpEditor(tester, siteId: seeded.id, seeded: seeded);

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.text('Hertenstein'), findsWidgets);
    expect(find.text('Weggis'), findsNothing);
    expect(find.text('Lake Lucerne'), findsOneWidget);
  });

  testWidgets('seeding from a dive fills town and body of water without '
      'dirtying the form', (tester) async {
    await pumpEditor(
      tester,
      initialLocation: const GeoPoint(47.027631, 8.400640),
    );

    expect(find.text('Weggis'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsOneWidget);
    // Backing out of an untouched seeded form asks nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
```

Confirm the Cancel button text and the unsaved-changes dialog behaviour against `test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart` and `site_edit_page_test.dart` (search for `Discard` / `Cancel`); adjust the last assertion to whatever the page actually shows.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_fill_location_test.dart`
Expected: the first and third tests fail on `find.text('Weggis')` (country and region fill, town and lake do not).

- [ ] **Step 3: Implement**

`location_picker_map.dart`, replace `PickedLocation`:

```dart
/// Result from the location picker
class PickedLocation {
  final double latitude;
  final double longitude;

  /// What the coordinates reverse-geocoded to.
  final PlaceLookup place;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.place,
  });
}
```

with `import 'package:submersion/core/services/geocoding/place_lookup.dart';`, and in `_confirmSelection`:

```dart
      Navigator.of(context).pop(
        PickedLocation(
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          place: result,
        ),
      );
```

`site_edit_page.dart`: add imports for `place_lookup.dart` and `site_location_merge.dart`, then add this method next to `_geocodeSeed`:

```dart
  /// Writes [lookup] into the country, region, city and body of water
  /// fields. With [overwrite] false only empty fields change (the rule lives
  /// in [mergeMissingLocationDetails]); with it true every found value
  /// replaces the current one. Returns whether any field changed. Callers
  /// decide whether that dirties the form.
  bool _applyPlaceLookup(PlaceLookup lookup, {required bool overwrite}) {
    final current = overwrite
        ? const SiteLocationDetails()
        : SiteLocationDetails(
            country: _countryController.text,
            region: _regionController.text,
            city: _cityController.text,
            bodyOfWater: _bodyOfWaterController.text,
          );
    final merged = mergeMissingLocationDetails(current: current, found: lookup);
    if (merged == null) return false;

    var changed = false;
    void set(TextEditingController controller, String? value) {
      if (value == null || controller.text == value) return;
      controller.text = value;
      changed = true;
    }

    set(_countryController, merged.country);
    set(_regionController, merged.region);
    set(_cityController, merged.city);
    set(_bodyOfWaterController, merged.bodyOfWater);
    return changed;
  }
```

Replace the body of `_geocodeSeed`'s `setState` with:

```dart
    setState(() {
      _isApplyingInitialValues = true;
      _applyPlaceLookup(result, overwrite: false);
      _isApplyingInitialValues = false;
    });
```

In `_useMyLocation`, replace the two `if (_countryController...` / `if (_regionController...` blocks with `_applyPlaceLookup(result.place, overwrite: false);` (keep `_hasChanges = true;` because the coordinates changed).

In `_pickFromMap`, replace the same two blocks with `_applyPlaceLookup(result.place, overwrite: false);`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites/presentation/pages`
Expected: all pass, including the unchanged Grand Turk and Bonaire tests. `flutter analyze`: `No issues found!`

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/features/dive_sites test/features/dive_sites && git commit -m "feat(sites): fill town and body of water from every coordinate source (#1187)"
```

---

### Task 10: "Look up from coordinates" on the site form

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart` (constructor, fields, the action row lines 96-123)
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (`LocationSection` wiring lines 948-967; new `_lookupFromCoordinates` next to `_pickFromMap`)
- Modify: all 11 ARB files
- Test: `test/features/dive_sites/presentation/pages/site_edit_lookup_from_coordinates_test.dart`

**Interfaces:**
- Consumes: `_applyPlaceLookup` (Task 9), `placeNameLanguageProvider` (Task 5), `reverseGeocode` (Task 1).
- Produces: `LocationSection.onLookupFromCoordinates` (`VoidCallback?`, null disables the button).
- Produces l10n keys: `diveSites_edit_gps_lookupFromCoordinates`, `diveSites_edit_snackbar_lookupNothingFound`, `diveSites_edit_snackbar_lookupFailed`, `diveSites_edit_lookupReplace_title`, `diveSites_edit_lookupReplace_body`, `diveSites_edit_lookupReplace_replace`, `diveSites_edit_lookupReplace_keep`; changed `diveSites_edit_gps_helperText`.

- [ ] **Step 1: Add the strings to every ARB**

`app_en.arb`: change `diveSites_edit_gps_helperText` to `"Choose a location method or look up the coordinates to auto-fill country, region, town and body of water"`, and add next to `diveSites_edit_gps_pickFromMap`:

```json
  "diveSites_edit_gps_lookupFromCoordinates": "Look up from coordinates",
  "diveSites_edit_snackbar_lookupNothingFound": "No location details found for these coordinates",
  "diveSites_edit_snackbar_lookupFailed": "Location lookup failed. Check your connection and try again.",
  "diveSites_edit_lookupReplace_title": "Replace location details?",
  "diveSites_edit_lookupReplace_body": "The lookup found different values for these fields:",
  "diveSites_edit_lookupReplace_replace": "Replace",
  "diveSites_edit_lookupReplace_keep": "Keep",
```

Translations (helperText / lookupFromCoordinates / lookupNothingFound / lookupFailed / replace_title / replace_body / replace / keep):

- `de`: "Wählen Sie eine Standortmethode oder suchen Sie die Koordinaten, um Land, Region, Ort und Gewässer automatisch auszufüllen" / "Aus Koordinaten ermitteln" / "Keine Ortsangaben für diese Koordinaten gefunden" / "Ortssuche fehlgeschlagen. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut." / "Ortsangaben ersetzen?" / "Die Suche hat für diese Felder andere Werte gefunden:" / "Ersetzen" / "Behalten"
- `es`: "Elige un método de ubicación o consulta las coordenadas para rellenar país, región, localidad y masa de agua" / "Consultar por coordenadas" / "No se encontraron datos de ubicación para estas coordenadas" / "La consulta de ubicación falló. Comprueba tu conexión e inténtalo de nuevo." / "¿Reemplazar los datos de ubicación?" / "La consulta encontró valores distintos para estos campos:" / "Reemplazar" / "Mantener"
- `fr`: "Choisissez une méthode de localisation ou recherchez les coordonnées pour remplir le pays, la région, la ville et le plan d'eau" / "Rechercher depuis les coordonnées" / "Aucune information de lieu trouvée pour ces coordonnées" / "La recherche de lieu a échoué. Vérifiez votre connexion et réessayez." / "Remplacer les informations de lieu ?" / "La recherche a trouvé des valeurs différentes pour ces champs :" / "Remplacer" / "Conserver"
- `it`: "Scegli un metodo di localizzazione o cerca le coordinate per compilare paese, regione, città e specchio d'acqua" / "Cerca dalle coordinate" / "Nessun dettaglio di località trovato per queste coordinate" / "Ricerca della località non riuscita. Controlla la connessione e riprova." / "Sostituire i dettagli di località?" / "La ricerca ha trovato valori diversi per questi campi:" / "Sostituisci" / "Mantieni"
- `nl`: "Kies een locatiemethode of zoek de coördinaten op om land, regio, plaats en water automatisch in te vullen" / "Opzoeken op coördinaten" / "Geen locatiegegevens gevonden voor deze coördinaten" / "Locatie opzoeken mislukt. Controleer je verbinding en probeer het opnieuw." / "Locatiegegevens vervangen?" / "Het opzoeken vond andere waarden voor deze velden:" / "Vervangen" / "Behouden"
- `pt`: "Escolha um método de localização ou consulte as coordenadas para preencher país, região, cidade e corpo de água" / "Consultar pelas coordenadas" / "Nenhum detalhe de localização encontrado para estas coordenadas" / "A consulta de localização falhou. Verifique a sua ligação e tente novamente." / "Substituir os detalhes de localização?" / "A consulta encontrou valores diferentes para estes campos:" / "Substituir" / "Manter"
- `hu`: "Válasszon helymeghatározási módot, vagy kérdezze le a koordinátákat az ország, régió, település és víztest automatikus kitöltéséhez" / "Lekérdezés a koordinátákból" / "Nem található helyadat ezekhez a koordinátákhoz" / "A helylekérdezés nem sikerült. Ellenőrizze a kapcsolatot, és próbálja újra." / "Lecseréli a helyadatokat?" / "A lekérdezés eltérő értékeket talált ezekhez a mezőkhöz:" / "Csere" / "Megtartás"
- `ar`: "اختر طريقة لتحديد الموقع أو ابحث عن الإحداثيات لملء البلد والمنطقة والبلدة والمسطح المائي تلقائيًا" / "البحث من الإحداثيات" / "لم يتم العثور على تفاصيل موقع لهذه الإحداثيات" / "فشل البحث عن الموقع. تحقق من الاتصال وحاول مرة أخرى." / "استبدال تفاصيل الموقع؟" / "عثر البحث على قيم مختلفة لهذه الحقول:" / "استبدال" / "إبقاء"
- `he`: "בחרו שיטת מיקום או חפשו את הקואורדינטות כדי למלא אוטומטית מדינה, אזור, עיר וגוף מים" / "חיפוש לפי קואורדינטות" / "לא נמצאו פרטי מיקום לקואורדינטות אלה" / "חיפוש המיקום נכשל. בדקו את החיבור ונסו שוב." / "להחליף את פרטי המיקום?" / "החיפוש מצא ערכים שונים לשדות אלה:" / "החלפה" / "שמירה"
- `zh`: "选择定位方式或根据坐标查找，以自动填写国家、地区、城镇和水域" / "根据坐标查找" / "未找到这些坐标的地点信息" / "地点查找失败。请检查网络连接后重试。" / "替换地点信息？" / "查找结果中以下字段的值不同：" / "替换" / "保留"

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

`test/features/dive_sites/presentation/pages/site_edit_lookup_from_coordinates_test.dart`: copy the `_rowField`, `_FakeLocationService`, `_weggis`, `setUp`/`tearDown` and `pumpEditor` helpers from Task 9's test file verbatim, then:

```dart
  Future<void> enterCoordinates(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '47.027631',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '8.400640',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the button is disabled until both coordinates parse', (
    tester,
  ) async {
    await pumpEditor(tester);
    final button = find.widgetWithText(TextButton, 'Look up from coordinates');
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    await enterCoordinates(tester);
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  testWidgets('fills the empty fields and saves them', (tester) async {
    await pumpEditor(tester);
    await enterCoordinates(tester);
    await tester.enterText(_rowField('Dive Site Name'), 'Hertenstein');

    await tester.tap(find.text('Look up from coordinates'));
    await tester.pumpAndSettle();

    expect(find.text('Weggis'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (await SiteRepository().getAllSites()).single;
    expect(saved.city, 'Weggis');
    expect(saved.bodyOfWater, 'Lake Lucerne');
    expect(saved.country, 'Switzerland');
  });

  testWidgets('offers to replace when nothing was empty and values differ', (
    tester,
  ) async {
    final repo = SiteRepository();
    final seeded = await repo.createSite(
      const DiveSite(
        id: '',
        name: 'Hertenstein',
        country: 'Schweiz',
        region: 'Luzern',
        city: 'Weggis',
        bodyOfWater: 'Vierwaldstättersee',
        location: GeoPoint(47.027631, 8.400640),
      ),
    );
    await pumpEditor(tester, siteId: seeded.id, seeded: seeded);

    await tester.tap(find.text('Look up from coordinates'));
    await tester.pumpAndSettle();

    expect(find.text('Replace location details?'), findsOneWidget);
    // Only the differing fields are listed; the town is identical.
    expect(find.textContaining('Lake Lucerne'), findsOneWidget);
    expect(find.textContaining('Weggis'), findsNothing);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(find.text('Lake Lucerne'), findsOneWidget);
    expect(find.text('Vierwaldstättersee'), findsNothing);
  });

  testWidgets('Keep leaves the fields alone', (tester) async {
    final repo = SiteRepository();
    final seeded = await repo.createSite(
      const DiveSite(
        id: '',
        name: 'Hertenstein',
        country: 'Schweiz',
        region: 'Luzern',
        city: 'Weggis',
        bodyOfWater: 'Vierwaldstättersee',
        location: GeoPoint(47.027631, 8.400640),
      ),
    );
    await pumpEditor(tester, siteId: seeded.id, seeded: seeded);

    await tester.tap(find.text('Look up from coordinates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.text('Vierwaldstättersee'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsNothing);
  });

  testWidgets('says so when nothing was found', (tester) async {
    await pumpEditor(tester, place: const PlaceLookup.empty());
    await enterCoordinates(tester);

    await tester.tap(find.text('Look up from coordinates'));
    await tester.pumpAndSettle();

    expect(
      find.text('No location details found for these coordinates'),
      findsOneWidget,
    );
  });

  testWidgets('reports an unreachable geocoder', (tester) async {
    await pumpEditor(tester, place: const PlaceLookup.unavailable());
    await enterCoordinates(tester);

    await tester.tap(find.text('Look up from coordinates'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Location lookup failed. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });
```

The `Latitude` / `Longitude` labels come from `diveSites_edit_gps_latitude_label` and `_longitude_label`; check `grep -n "latitude_label\|longitude_label" lib/l10n/arb/app_en.arb` and `test/features/dive_sites/presentation/pages/site_edit_altitude_autofill_test.dart` for how coordinates are typed in tests, and copy that approach if `widgetWithText(TextFormField, ...)` does not match the `CoordinateFieldGroup` fields.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_lookup_from_coordinates_test.dart`
Expected: every test fails, first on `find.widgetWithText(TextButton, 'Look up from coordinates')` (no such button).

- [ ] **Step 4: Add the button to `LocationSection`**

In `location_section.dart` add the constructor parameter `required this.onLookupFromCoordinates,` after `onPickFromMap`, the field `final VoidCallback? onLookupFromCoordinates;`, and after the `Pick from Map` `TextButton.icon` inside the `Row` (wrap the row's children in a `Wrap` with `spacing: 12` if three buttons overflow at 360 px; keep the existing two buttons' order):

```dart
                  TextButton.icon(
                    onPressed: isGettingLocation
                        ? null
                        : onLookupFromCoordinates,
                    icon: const Icon(Icons.travel_explore, size: 16),
                    label: Text(
                      l10n.diveSites_edit_gps_lookupFromCoordinates,
                    ),
                  ),
```

Replace the `Row(` at line 98 with `Wrap(spacing: 12, runSpacing: 4, children: [` and drop the `const SizedBox(width: 12)` spacer.

- [ ] **Step 5: Add the page logic**

In `site_edit_page.dart`, wire the section:

```dart
            onLookupFromCoordinates: _parsedCoordinates() == null
                ? null
                : _lookupFromCoordinates,
```

and add next to `_pickFromMap`:

```dart
  /// The typed coordinates, or null while either field does not parse.
  GeoPoint? _parsedCoordinates() {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GeoPoint(lat, lng);
  }

  /// Explicit lookup for the typed coordinates (issue #1187). Fills empty
  /// fields; when nothing was empty and the lookup differs, offers to
  /// replace. Never runs on save.
  Future<void> _lookupFromCoordinates() async {
    final point = _parsedCoordinates();
    if (point == null) return;
    setState(() => _isGettingLocation = true);
    try {
      final lookup = await ref
          .read(locationServiceProvider)
          .reverseGeocode(
            point.latitude,
            point.longitude,
            languageCode: ref.read(placeNameLanguageProvider),
          );
      if (!mounted) return;

      if (lookup.networkFailed) {
        _showLookupSnackBar(context.l10n.diveSites_edit_snackbar_lookupFailed);
        return;
      }
      if (lookup.isEmpty) {
        _showLookupSnackBar(
          context.l10n.diveSites_edit_snackbar_lookupNothingFound,
        );
        return;
      }

      var changed = false;
      setState(() {
        changed = _applyPlaceLookup(lookup, overwrite: false);
        if (changed) _hasChanges = true;
      });
      if (changed) return;

      final differing = _differingLookupValues(lookup);
      if (differing.isEmpty) return;
      final replace = await _confirmReplaceLocationDetails(differing);
      if (!mounted || !replace) return;
      setState(() {
        if (_applyPlaceLookup(lookup, overwrite: true)) _hasChanges = true;
      });
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showLookupSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Field label to found value, for the fields whose found value is
  /// non-blank and differs from what the form shows.
  Map<String, String> _differingLookupValues(PlaceLookup lookup) {
    final l10n = context.l10n;
    final out = <String, String>{};
    void compare(String label, String current, String? found) {
      if (found == null || found.trim().isEmpty) return;
      if (current.trim() == found.trim()) return;
      out[label] = found.trim();
    }

    compare(l10n.diveSites_edit_field_country_label, _countryController.text, lookup.country);
    compare(l10n.diveSites_edit_field_region_label, _regionController.text, lookup.region);
    compare(l10n.diveSites_edit_field_city_label, _cityController.text, lookup.locality);
    compare(l10n.diveSites_edit_field_bodyOfWater_label, _bodyOfWaterController.text, lookup.bodyOfWater);
    return out;
  }

  Future<bool> _confirmReplaceLocationDetails(
    Map<String, String> differing,
  ) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveSites_edit_lookupReplace_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.diveSites_edit_lookupReplace_body),
            const SizedBox(height: 12),
            for (final entry in differing.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${entry.key}: ${entry.value}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.diveSites_edit_lookupReplace_keep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.diveSites_edit_lookupReplace_replace),
          ),
        ],
      ),
    );
    return result ?? false;
  }
```

The button's enabled state depends on the coordinate controllers, so the page must rebuild when they change: confirm `_latitudeController` and `_longitudeController` have `addListener(_onFieldChanged)` (line 122 onward) and that `_onFieldChanged` calls `setState`; if they do not, add listeners that call `setState(() {})` in `initState` and remove them in `dispose`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 7: Commit**

```bash
dart format . && git add lib/features/dive_sites lib/l10n test/features/dive_sites && git commit -m "feat(sites): look up location details from typed coordinates (#1187)"
```

---

### Task 11: `SiteLocationBackfillService`

**Files:**
- Create: `lib/features/dive_sites/domain/services/site_location_backfill_service.dart`
- Test: `test/features/dive_sites/domain/services/site_location_backfill_service_test.dart`

**Interfaces:**
- Consumes: `SiteRepository.getAllSites({String? diverId})`, `SiteRepository.fillMissingLocationDetails` (Task 8), `LocationService.reverseGeocode` (Task 1), `PlaceLookup.networkFailed`.
- Produces:

```dart
class BackfillSummary {
  const BackfillSummary({required this.total, required this.updated, required this.unchanged, required this.failed, this.cancelled = false, this.offline = false});
  final int total; final int updated; final int unchanged; final int failed; final bool cancelled; final bool offline;
}
class SiteLocationBackfillService {
  SiteLocationBackfillService({required SiteRepository sites, required LocationService location, required String languageCode});
  static bool needsLookup(DiveSite site);
  Future<List<DiveSite>> candidates({String? diverId});
  Future<BackfillSummary> run({String? diverId, required void Function(int done, int total) onProgress, required bool Function() isCancelled});
}
```

- [ ] **Step 1: Write the failing tests**

`test/features/dive_sites/domain/services/site_location_backfill_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';

import '../../../../helpers/test_database.dart';

/// Answers each coordinate from a map; unknown coordinates come back empty.
class _MapLocationService implements LocationService {
  _MapLocationService(this.answers, {this.offline = false, this.throwOn});

  final Map<String, PlaceLookup> answers;
  final bool offline;
  final String? throwOn;
  final List<String> asked = [];

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    final key = '$latitude,$longitude';
    asked.add(key);
    if (offline) return const PlaceLookup.unavailable();
    if (key == throwOn) throw StateError('boom');
    return answers[key] ?? const PlaceLookup.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const weggis = PlaceLookup(
    country: 'Switzerland',
    region: 'Lucerne',
    locality: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
  );

  Future<void> seed() async {
    await sites.createSite(
      const DiveSite(
        id: 'empty',
        name: 'Empty',
        location: GeoPoint(47.0, 8.4),
      ),
    );
    await sites.createSite(
      const DiveSite(
        id: 'partial',
        name: 'Partial',
        country: 'Switzerland',
        region: 'Lucerne',
        location: GeoPoint(47.1, 8.5),
      ),
    );
    await sites.createSite(
      const DiveSite(
        id: 'full',
        name: 'Full',
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
        location: GeoPoint(47.2, 8.6),
      ),
    );
    await sites.createSite(const DiveSite(id: 'nogps', name: 'No GPS'));
  }

  SiteLocationBackfillService service(LocationService location) =>
      SiteLocationBackfillService(
        sites: sites,
        location: location,
        languageCode: 'en',
      );

  test('needsLookup wants coordinates and at least one empty field', () {
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(id: '1', name: 'n', location: GeoPoint(1, 2)),
      ),
      isTrue,
    );
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(id: '1', name: 'n'),
      ),
      isFalse,
    );
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(
          id: '1',
          name: 'n',
          location: GeoPoint(1, 2),
          country: 'a',
          region: 'b',
          city: 'c',
          bodyOfWater: 'd',
        ),
      ),
      isFalse,
    );
    expect(
      SiteLocationBackfillService.needsLookup(
        const DiveSite(
          id: '1',
          name: 'n',
          location: GeoPoint(1, 2),
          country: 'a',
          region: 'b',
          city: '  ',
          bodyOfWater: 'd',
        ),
      ),
      isTrue,
      reason: 'blank counts as empty',
    );
  });

  test('candidates skips full sites and sites without coordinates', () async {
    await seed();
    final found = await service(_MapLocationService({})).candidates();
    expect(found.map((s) => s.id), unorderedEquals(['empty', 'partial']));
  });

  test('run fills only empty fields and counts outcomes', () async {
    await seed();
    final location = _MapLocationService({
      '47.0,8.4': weggis,
      '47.1,8.5': const PlaceLookup(country: 'Schweiz', locality: 'Weggis'),
    });
    final progress = <(int, int)>[];

    final summary = await service(location).run(
      onProgress: (done, total) => progress.add((done, total)),
      isCancelled: () => false,
    );

    expect(summary.total, 2);
    expect(summary.updated, 2);
    expect(summary.unchanged, 0);
    expect(summary.failed, 0);
    expect(summary.cancelled, isFalse);
    expect(progress, [(0, 2), (1, 2), (2, 2)]);
    expect(location.asked, hasLength(2), reason: 'full and nogps not asked');

    final partial = await sites.getSiteById('partial');
    expect(partial!.country, 'Switzerland', reason: 'kept');
    expect(partial.city, 'Weggis');
    final empty = await sites.getSiteById('empty');
    expect(empty!.bodyOfWater, 'Lake Lucerne');
  });

  test('a lookup that finds nothing counts as unchanged', () async {
    await seed();
    final summary = await service(_MapLocationService({})).run(
      onProgress: (_, _) {},
      isCancelled: () => false,
    );
    expect(summary.updated, 0);
    expect(summary.unchanged, 2);
  });

  test('a throwing site is counted as failed and the run continues', () async {
    await seed();
    final location = _MapLocationService({
      '47.1,8.5': weggis,
    }, throwOn: '47.0,8.4');

    final summary = await service(location).run(
      onProgress: (_, _) {},
      isCancelled: () => false,
    );

    expect(summary.failed, 1);
    expect(summary.updated, 1);
  });

  test('cancelling between sites stops the run', () async {
    await seed();
    final location = _MapLocationService({'47.0,8.4': weggis});
    var calls = 0;

    final summary = await service(location).run(
      onProgress: (_, _) {},
      isCancelled: () => calls++ >= 1,
    );

    expect(summary.cancelled, isTrue);
    expect(location.asked, hasLength(1));
  });

  test('an unreachable geocoder on the first site aborts as offline', () async {
    await seed();
    final location = _MapLocationService({}, offline: true);

    final summary = await service(location).run(
      onProgress: (_, _) {},
      isCancelled: () => false,
    );

    expect(summary.offline, isTrue);
    expect(summary.failed, 0);
    expect(location.asked, hasLength(1));
  });

  test('run scopes candidates to the diver', () async {
    await seed();
    final location = _MapLocationService({'47.0,8.4': weggis});

    final summary = await service(location).run(
      diverId: 'someone-else',
      onProgress: (_, _) {},
      isCancelled: () => false,
    );

    expect(summary.total, 0);
    expect(location.asked, isEmpty);
  });
}
```

For the last test, check how `getAllSites(diverId:)` treats sites whose `diverId` is null (`sed -n 47,66p lib/features/dive_sites/data/repositories/site_repository_impl.dart`); if null-diver sites are returned for every diver, seed the sites with `diverId: 'diver-1'` after inserting a `Divers` row, and expect `total 0` for `'someone-else'`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/domain/services/site_location_backfill_service_test.dart`
Expected: compile error, file missing.

- [ ] **Step 3: Implement the service**

`lib/features/dive_sites/domain/services/site_location_backfill_service.dart`:

```dart
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Outcome of one backfill run.
class BackfillSummary {
  const BackfillSummary({
    required this.total,
    required this.updated,
    required this.unchanged,
    required this.failed,
    this.cancelled = false,
    this.offline = false,
  });

  final int total;
  final int updated;
  final int unchanged;
  final int failed;
  final bool cancelled;

  /// The geocoder could not be reached on the first request, so the run
  /// stopped before collecting one failure per site.
  final bool offline;
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// Fills empty country, region, town and body of water for every site that
/// has coordinates (issue #1187). Only empty columns are ever written; the
/// rule itself lives in `mergeMissingLocationDetails` behind
/// [SiteRepository.fillMissingLocationDetails]. Request spacing is the
/// location service's concern.
class SiteLocationBackfillService {
  SiteLocationBackfillService({
    required SiteRepository sites,
    required LocationService location,
    required String languageCode,
  }) : _sites = sites,
       _location = location,
       _languageCode = languageCode;

  final SiteRepository _sites;
  final LocationService _location;
  final String _languageCode;
  static final _log = LoggerService.forClass(SiteLocationBackfillService);

  /// A site the run would look up: coordinates present and at least one of
  /// the four fields blank.
  static bool needsLookup(DiveSite site) =>
      site.location != null &&
      (_isBlank(site.country) ||
          _isBlank(site.region) ||
          _isBlank(site.city) ||
          _isBlank(site.bodyOfWater));

  Future<List<DiveSite>> candidates({String? diverId}) async {
    final all = await _sites.getAllSites(diverId: diverId);
    return all.where(needsLookup).toList(growable: false);
  }

  Future<BackfillSummary> run({
    String? diverId,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final targets = await candidates(diverId: diverId);
    final total = targets.length;
    var updated = 0;
    var unchanged = 0;
    var failed = 0;
    var done = 0;
    onProgress(done, total);

    for (final site in targets) {
      if (isCancelled()) {
        return BackfillSummary(
          total: total,
          updated: updated,
          unchanged: unchanged,
          failed: failed,
          cancelled: true,
        );
      }
      final point = site.location!;
      try {
        final lookup = await _location.reverseGeocode(
          point.latitude,
          point.longitude,
          languageCode: _languageCode,
        );
        if (lookup.networkFailed) {
          if (done == 0) {
            return BackfillSummary(
              total: total,
              updated: updated,
              unchanged: unchanged,
              failed: failed,
              offline: true,
            );
          }
          failed++;
        } else if (await _sites.fillMissingLocationDetails(site.id, lookup)) {
          updated++;
        } else {
          unchanged++;
        }
      } catch (e, stackTrace) {
        _log.warning(
          'Backfill failed for site ${site.id}: $e',
          error: e,
          stackTrace: stackTrace,
        );
        failed++;
      }
      done++;
      onProgress(done, total);
    }

    return BackfillSummary(
      total: total,
      updated: updated,
      unchanged: unchanged,
      failed: failed,
    );
  }
}
```

If `LoggerService.warning` does not accept `error:`/`stackTrace:` named arguments (check `grep -n "void warning" lib/core/services/logger_service.dart`), call `_log.warning('Backfill failed for site ${site.id}: $e')` instead.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites/domain/services/site_location_backfill_service_test.dart`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/features/dive_sites test/features/dive_sites && git commit -m "feat(sites): backfill service for missing location details (#1187)"
```

---

### Task 12: Bulk "Fill in missing location details" from the sites list

**Files:**
- Create: `lib/features/dive_sites/presentation/providers/site_location_backfill_provider.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (both `PopupMenuButton<String>` blocks, lines 515-545 and 777-800)
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart` (`PopupMenuButton<String>` lines 173-197)
- Modify: all 11 ARB files
- Test: `test/features/dive_sites/presentation/providers/site_location_backfill_provider_test.dart`, `test/features/dive_sites/presentation/widgets/site_location_backfill_dialog_test.dart`

**Interfaces:**
- Consumes: `SiteLocationBackfillService`, `BackfillSummary` (Task 11), `siteRepositoryProvider`, `locationServiceProvider`, `placeNameLanguageProvider`, `validatedCurrentDiverIdProvider`, `siteListNotifierProvider`.
- Produces:

```dart
sealed class BackfillState { const BackfillState(); }
class BackfillIdle extends BackfillState { const BackfillIdle(); }
class BackfillRunning extends BackfillState { const BackfillRunning({required this.done, required this.total}); final int done; final int total; }
class BackfillFinished extends BackfillState { const BackfillFinished(this.summary); final BackfillSummary summary; }
class SiteLocationBackfillNotifier extends StateNotifier<BackfillState> { Future<int> countCandidates(); Future<void> start(); void cancel(); void reset(); }
final siteLocationBackfillProvider = StateNotifierProvider<SiteLocationBackfillNotifier, BackfillState>;
Future<void> showSiteLocationBackfillFlow(BuildContext context, WidgetRef ref);
```

- Produces l10n keys: `diveSites_list_menu_fillLocationDetails`, `diveSites_backfill_confirm_title`, `diveSites_backfill_confirm_body` (placeholders `count`, `minutes`), `diveSites_backfill_confirm_start`, `diveSites_backfill_nothingToFill`, `diveSites_backfill_progress_title`, `diveSites_backfill_progress_count` (placeholders `done`, `total`), `diveSites_backfill_cancel`, `diveSites_backfill_summary` (placeholders `updated`, `unchanged`, `failed`), `diveSites_backfill_offline`.

- [ ] **Step 1: Add the strings to every ARB**

`app_en.arb`, next to `diveSites_list_menu_select`:

```json
  "diveSites_list_menu_fillLocationDetails": "Fill in missing location details",
  "diveSites_backfill_confirm_title": "Fill in missing location details?",
  "diveSites_backfill_confirm_body": "{count, plural, =1{1 site with coordinates has an empty country, region, town or body of water.} other{{count} sites with coordinates have an empty country, region, town or body of water.}} Submersion will look each one up on OpenStreetMap and fill only the empty fields. This takes about {minutes} minutes.",
  "@diveSites_backfill_confirm_body": {
    "placeholders": {
      "count": {
        "type": "int"
      },
      "minutes": {
        "type": "int"
      }
    }
  },
  "diveSites_backfill_confirm_start": "Start",
  "diveSites_backfill_nothingToFill": "Every site with coordinates already has its location details.",
  "diveSites_backfill_progress_title": "Filling in location details",
  "diveSites_backfill_progress_count": "{done} of {total}",
  "@diveSites_backfill_progress_count": {
    "placeholders": {
      "done": {
        "type": "int"
      },
      "total": {
        "type": "int"
      }
    }
  },
  "diveSites_backfill_cancel": "Cancel",
  "diveSites_backfill_summary": "Updated {updated}, unchanged {unchanged}, failed {failed}",
  "@diveSites_backfill_summary": {
    "placeholders": {
      "updated": {
        "type": "int"
      },
      "unchanged": {
        "type": "int"
      },
      "failed": {
        "type": "int"
      }
    }
  },
  "diveSites_backfill_offline": "Location lookup is unavailable. Check your connection and try again.",
```

Translations, in the order menu / confirm_title / confirm_body / confirm_start / nothingToFill / progress_title / progress_count / cancel / summary / offline. Keep the ICU plural and placeholder syntax exactly as in English.

- `de`: "Fehlende Ortsangaben ergänzen" / "Fehlende Ortsangaben ergänzen?" / "{count, plural, =1{1 Tauchplatz mit Koordinaten hat kein Land, keine Region, keinen Ort oder kein Gewässer.} other{{count} Tauchplätze mit Koordinaten haben kein Land, keine Region, keinen Ort oder kein Gewässer.}} Submersion sucht jeden auf OpenStreetMap und füllt nur die leeren Felder aus. Das dauert etwa {minutes} Minuten." / "Starten" / "Alle Tauchplätze mit Koordinaten haben bereits ihre Ortsangaben." / "Ortsangaben werden ergänzt" / "{done} von {total}" / "Abbrechen" / "Aktualisiert {updated}, unverändert {unchanged}, fehlgeschlagen {failed}" / "Die Ortssuche ist nicht verfügbar. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut."
- `es`: "Completar datos de ubicación que faltan" / "¿Completar los datos de ubicación que faltan?" / "{count, plural, =1{1 punto de buceo con coordenadas no tiene país, región, localidad o masa de agua.} other{{count} puntos de buceo con coordenadas no tienen país, región, localidad o masa de agua.}} Submersion consultará cada uno en OpenStreetMap y rellenará solo los campos vacíos. Tarda unos {minutes} minutos." / "Iniciar" / "Todos los puntos de buceo con coordenadas ya tienen sus datos de ubicación." / "Completando datos de ubicación" / "{done} de {total}" / "Cancelar" / "Actualizados {updated}, sin cambios {unchanged}, fallidos {failed}" / "La consulta de ubicación no está disponible. Comprueba tu conexión e inténtalo de nuevo."
- `fr`: "Compléter les informations de lieu manquantes" / "Compléter les informations de lieu manquantes ?" / "{count, plural, =1{1 site avec coordonnées n'a pas de pays, de région, de ville ou de plan d'eau.} other{{count} sites avec coordonnées n'ont pas de pays, de région, de ville ou de plan d'eau.}} Submersion recherchera chacun sur OpenStreetMap et ne remplira que les champs vides. Cela prend environ {minutes} minutes." / "Démarrer" / "Tous les sites avec coordonnées ont déjà leurs informations de lieu." / "Complément des informations de lieu" / "{done} sur {total}" / "Annuler" / "Mis à jour {updated}, inchangés {unchanged}, échoués {failed}" / "La recherche de lieu est indisponible. Vérifiez votre connexion et réessayez."
- `it`: "Completa i dettagli di località mancanti" / "Completare i dettagli di località mancanti?" / "{count, plural, =1{1 sito con coordinate non ha paese, regione, città o specchio d'acqua.} other{{count} siti con coordinate non hanno paese, regione, città o specchio d'acqua.}} Submersion cercherà ciascuno su OpenStreetMap e compilerà solo i campi vuoti. Richiede circa {minutes} minuti." / "Avvia" / "Tutti i siti con coordinate hanno già i dettagli di località." / "Completamento dei dettagli di località" / "{done} di {total}" / "Annulla" / "Aggiornati {updated}, invariati {unchanged}, falliti {failed}" / "La ricerca della località non è disponibile. Controlla la connessione e riprova."
- `nl`: "Ontbrekende locatiegegevens aanvullen" / "Ontbrekende locatiegegevens aanvullen?" / "{count, plural, =1{1 duikstek met coördinaten heeft geen land, regio, plaats of water.} other{{count} duikstekken met coördinaten hebben geen land, regio, plaats of water.}} Submersion zoekt elke stek op via OpenStreetMap en vult alleen lege velden in. Dit duurt ongeveer {minutes} minuten." / "Starten" / "Elke duikstek met coördinaten heeft al locatiegegevens." / "Locatiegegevens aanvullen" / "{done} van {total}" / "Annuleren" / "Bijgewerkt {updated}, ongewijzigd {unchanged}, mislukt {failed}" / "Locatie opzoeken is niet beschikbaar. Controleer je verbinding en probeer het opnieuw."
- `pt`: "Preencher detalhes de localização em falta" / "Preencher os detalhes de localização em falta?" / "{count, plural, =1{1 local com coordenadas não tem país, região, cidade ou corpo de água.} other{{count} locais com coordenadas não têm país, região, cidade ou corpo de água.}} O Submersion consultará cada um no OpenStreetMap e preencherá apenas os campos vazios. Demora cerca de {minutes} minutos." / "Iniciar" / "Todos os locais com coordenadas já têm os seus detalhes de localização." / "A preencher detalhes de localização" / "{done} de {total}" / "Cancelar" / "Atualizados {updated}, inalterados {unchanged}, falhados {failed}" / "A consulta de localização não está disponível. Verifique a sua ligação e tente novamente."
- `hu`: "Hiányzó helyadatok kitöltése" / "Kitölti a hiányzó helyadatokat?" / "{count, plural, =1{1 koordinátával rendelkező merülőhelynek üres az országa, régiója, települése vagy víztestje.} other{{count} koordinátával rendelkező merülőhelynek üres az országa, régiója, települése vagy víztestje.}} A Submersion mindegyiket lekérdezi az OpenStreetMapról, és csak az üres mezőket tölti ki. Ez körülbelül {minutes} percet vesz igénybe." / "Indítás" / "Minden koordinátával rendelkező merülőhelynek megvannak a helyadatai." / "Helyadatok kitöltése" / "{done} / {total}" / "Mégse" / "Frissítve {updated}, változatlan {unchanged}, sikertelen {failed}" / "A helylekérdezés nem érhető el. Ellenőrizze a kapcsolatot, és próbálja újra."
- `ar`: "إكمال تفاصيل الموقع الناقصة" / "إكمال تفاصيل الموقع الناقصة؟" / "{count, plural, =1{موقع غوص واحد له إحداثيات ينقصه البلد أو المنطقة أو البلدة أو المسطح المائي.} other{{count} مواقع غوص لها إحداثيات ينقصها البلد أو المنطقة أو البلدة أو المسطح المائي.}} سيبحث Submersion عن كل منها في OpenStreetMap ويملأ الحقول الفارغة فقط. يستغرق ذلك نحو {minutes} دقائق." / "بدء" / "كل مواقع الغوص التي لها إحداثيات لديها تفاصيل الموقع بالفعل." / "جارٍ إكمال تفاصيل الموقع" / "{done} من {total}" / "إلغاء" / "تم تحديث {updated}، بدون تغيير {unchanged}، فشل {failed}" / "البحث عن الموقع غير متاح. تحقق من الاتصال وحاول مرة أخرى."
- `he`: "השלמת פרטי מיקום חסרים" / "להשלים פרטי מיקום חסרים?" / "{count, plural, =1{לאתר אחד עם קואורדינטות חסרים מדינה, אזור, עיר או גוף מים.} other{ל-{count} אתרים עם קואורדינטות חסרים מדינה, אזור, עיר או גוף מים.}} Submersion יחפש כל אחד מהם ב-OpenStreetMap וימלא רק שדות ריקים. זה נמשך כ-{minutes} דקות." / "התחלה" / "לכל האתרים עם קואורדינטות כבר יש פרטי מיקום." / "משלים פרטי מיקום" / "{done} מתוך {total}" / "ביטול" / "עודכנו {updated}, ללא שינוי {unchanged}, נכשלו {failed}" / "חיפוש המיקום אינו זמין. בדקו את החיבור ונסו שוב."
- `zh`: "补全缺失的地点信息" / "补全缺失的地点信息？" / "{count, plural, =1{1 个有坐标的潜点缺少国家、地区、城镇或水域。} other{{count} 个有坐标的潜点缺少国家、地区、城镇或水域。}} Submersion 将在 OpenStreetMap 上逐个查找，并仅填写空白字段。大约需要 {minutes} 分钟。" / "开始" / "所有有坐标的潜点都已有地点信息。" / "正在补全地点信息" / "{done} / {total}" / "取消" / "已更新 {updated}，未变 {unchanged}，失败 {failed}" / "地点查找不可用。请检查网络连接后重试。"

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing provider test**

`test/features/dive_sites/presentation/providers/site_location_backfill_provider_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Blocks each lookup until [release] is called, so a test can observe the
/// running state and cancel mid-run.
class _GatedLocationService implements LocationService {
  final List<Completer<void>> gates = [];
  final List<String> languages = [];

  void release() => gates.removeAt(0).complete();

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    languages.add(languageCode);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return const PlaceLookup(country: 'Switzerland', locality: 'Weggis');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late SiteRepository sites;
  late _GatedLocationService location;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    sites = SiteRepository();
    location = _GatedLocationService();
    container = ProviderContainer(
      overrides: [
        siteRepositoryProvider.overrideWithValue(sites),
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    await sites.createSite(
      const DiveSite(id: 'a', name: 'A', location: GeoPoint(47.0, 8.4)),
    );
    await sites.createSite(
      const DiveSite(id: 'b', name: 'B', location: GeoPoint(47.1, 8.5)),
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('starts idle and counts candidates', () async {
    expect(container.read(siteLocationBackfillProvider), isA<BackfillIdle>());
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    expect(await notifier.countCandidates(), 2);
  });

  test('reports progress while running and finishes with a summary', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(siteLocationBackfillProvider),
      isA<BackfillRunning>()
          .having((s) => s.done, 'done', 0)
          .having((s) => s.total, 'total', 2),
    );

    location.release();
    await Future<void>.delayed(Duration.zero);
    location.release();
    await run;

    final state = container.read(siteLocationBackfillProvider);
    expect(state, isA<BackfillFinished>());
    expect((state as BackfillFinished).summary.updated, 2);
    expect((await sites.getSiteById('a'))!.city, 'Weggis');
  });

  test('a second start while running is a no-op', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final first = notifier.start();
    await Future<void>.delayed(Duration.zero);
    await notifier.start();
    expect(location.gates, hasLength(1), reason: 'no second run began');

    location.release();
    await Future<void>.delayed(Duration.zero);
    location.release();
    await first;
  });

  test('cancel stops after the current site', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start();
    await Future<void>.delayed(Duration.zero);

    notifier.cancel();
    location.release();
    await run;

    final state = container.read(siteLocationBackfillProvider);
    expect((state as BackfillFinished).summary.cancelled, isTrue);
    expect(location.gates, isEmpty);
  });

  test('reset returns to idle', () async {
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start();
    await Future<void>.delayed(Duration.zero);
    location.release();
    await Future<void>.delayed(Duration.zero);
    location.release();
    await run;

    notifier.reset();
    expect(container.read(siteLocationBackfillProvider), isA<BackfillIdle>());
  });

  test('looks up in the place name language', () async {
    await container
        .read(settingsProvider.notifier)
        .setPlaceNameLanguage('de');
    final notifier = container.read(siteLocationBackfillProvider.notifier);
    final run = notifier.start();
    await Future<void>.delayed(Duration.zero);
    location.release();
    await Future<void>.delayed(Duration.zero);
    location.release();
    await run;
    expect(location.languages, ['de', 'de']);
  });
}
```

If `settingsProvider` in this container needs more overrides to save (it writes to the diver settings repository), replace the last test's first line with `container.read(settingsProvider.notifier).state = const AppSettings(placeNameLanguage: 'de');` guarded by whatever `SettingsNotifier` exposes for tests (`grep -n "visibleForTesting" lib/features/settings/presentation/providers/settings_providers.dart`).

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/providers/site_location_backfill_provider_test.dart`
Expected: compile error, provider file missing.

- [ ] **Step 4: Implement the provider**

`lib/features/dive_sites/presentation/providers/site_location_backfill_provider.dart`:

```dart
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Progress of the bulk location-details backfill (issue #1187).
sealed class BackfillState {
  const BackfillState();
}

class BackfillIdle extends BackfillState {
  const BackfillIdle();
}

class BackfillRunning extends BackfillState {
  const BackfillRunning({required this.done, required this.total});
  final int done;
  final int total;
}

class BackfillFinished extends BackfillState {
  const BackfillFinished(this.summary);
  final BackfillSummary summary;
}

/// Owns one backfill run at a time so the progress dialog can be rebuilt,
/// dismissed and reopened without losing the run.
class SiteLocationBackfillNotifier extends StateNotifier<BackfillState> {
  SiteLocationBackfillNotifier(this._ref) : super(const BackfillIdle());

  final Ref _ref;
  bool _cancelRequested = false;

  SiteLocationBackfillService _service() => SiteLocationBackfillService(
    sites: _ref.read(siteRepositoryProvider),
    location: _ref.read(locationServiceProvider),
    languageCode: _ref.read(placeNameLanguageProvider),
  );

  Future<String?> _diverId() =>
      _ref.read(validatedCurrentDiverIdProvider.future);

  /// How many sites a run would look up.
  Future<int> countCandidates() async =>
      (await _service().candidates(diverId: await _diverId())).length;

  /// Starts a run unless one is already running.
  Future<void> start() async {
    if (state is BackfillRunning) return;
    _cancelRequested = false;
    state = const BackfillRunning(done: 0, total: 0);
    final summary = await _service().run(
      diverId: await _diverId(),
      onProgress: (done, total) {
        if (mounted) state = BackfillRunning(done: done, total: total);
      },
      isCancelled: () => _cancelRequested,
    );
    if (!mounted) return;
    state = BackfillFinished(summary);
    if (summary.updated > 0) {
      await _ref.read(siteListNotifierProvider.notifier).refresh();
    }
  }

  void cancel() => _cancelRequested = true;

  void reset() => state = const BackfillIdle();
}

final siteLocationBackfillProvider =
    StateNotifierProvider<SiteLocationBackfillNotifier, BackfillState>(
      (ref) => SiteLocationBackfillNotifier(ref),
    );
```

Check `lib/core/providers/provider.dart` exports `Ref` and `StateNotifier`; if not, import `package:flutter_riverpod/flutter_riverpod.dart` the way `site_providers.dart` does.

- [ ] **Step 5: Run the provider test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/providers/site_location_backfill_provider_test.dart`
Expected: all pass.

- [ ] **Step 6: Write the failing dialog test**

`test/features/dive_sites/presentation/widgets/site_location_backfill_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_backfill_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A scripted notifier so the dialog can be driven without a database or
/// network: [candidates] answers the count, [start] walks [script].
class _ScriptedBackfill extends StateNotifier<BackfillState>
    implements SiteLocationBackfillNotifier {
  _ScriptedBackfill({required this.candidates, required this.script})
    : super(const BackfillIdle());

  final int candidates;
  final List<BackfillState> script;
  int startCalls = 0;
  bool cancelled = false;

  @override
  Future<int> countCandidates() async => candidates;

  @override
  Future<void> start() async {
    startCalls++;
    for (final s in script) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = s;
    }
  }

  @override
  void cancel() => cancelled = true;

  @override
  void reset() => state = const BackfillIdle();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host(_ScriptedBackfill notifier) => ProviderScope(
    overrides: [siteLocationBackfillProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showSiteLocationBackfillFlow(context, ref),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );

  testWidgets('says so when there is nothing to fill', (tester) async {
    final notifier = _ScriptedBackfill(candidates: 0, script: const []);
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Every site with coordinates already has its location details.',
      ),
      findsOneWidget,
    );
    expect(notifier.startCalls, 0);
  });

  testWidgets('confirms with the count and estimate, then shows progress and '
      'a summary', (tester) async {
    final notifier = _ScriptedBackfill(
      candidates: 104,
      script: const [
        BackfillRunning(done: 0, total: 104),
        BackfillRunning(done: 12, total: 104),
        BackfillFinished(
          BackfillSummary(total: 104, updated: 90, unchanged: 13, failed: 1),
        ),
      ],
    );
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Fill in missing location details?'), findsOneWidget);
    expect(find.textContaining('104 sites with coordinates'), findsOneWidget);
    expect(find.textContaining('about 4 minutes'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 15));
    expect(find.text('Filling in location details'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('12 of 104'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Filling in location details'), findsNothing);
    expect(find.text('Updated 90, unchanged 13, failed 1'), findsOneWidget);
  });

  testWidgets('cancel asks the notifier to stop', (tester) async {
    final notifier = _ScriptedBackfill(
      candidates: 3,
      script: const [
        BackfillRunning(done: 0, total: 3),
        BackfillFinished(
          BackfillSummary(
            total: 3,
            updated: 1,
            unchanged: 0,
            failed: 0,
            cancelled: true,
          ),
        ),
      ],
    );
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 15));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(notifier.cancelled, isTrue);
  });

  testWidgets('an offline run shows the offline message', (tester) async {
    final notifier = _ScriptedBackfill(
      candidates: 3,
      script: const [
        BackfillRunning(done: 0, total: 3),
        BackfillFinished(
          BackfillSummary(
            total: 3,
            updated: 0,
            unchanged: 0,
            failed: 0,
            offline: true,
          ),
        ),
      ],
    );
    await tester.pumpWidget(host(notifier));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Location lookup is unavailable. Check your connection and try again.',
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/site_location_backfill_dialog_test.dart`
Expected: compile error, dialog file missing.

- [ ] **Step 8: Implement the flow**

`lib/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_location_backfill_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Seconds per site: two Nominatim requests, one second apart.
const int _secondsPerSite = 2;

/// The bulk "fill in missing location details" flow (issue #1187):
/// count, confirm, run with a progress dialog, summarise in a snackbar.
Future<void> showSiteLocationBackfillFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final notifier = ref.read(siteLocationBackfillProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);

  final count = await notifier.countCandidates();
  if (!context.mounted) return;
  if (count == 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveSites_backfill_nothingToFill)),
    );
    return;
  }

  final minutes = ((count * _secondsPerSite) / 60).ceil();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.diveSites_backfill_confirm_title),
      content: Text(l10n.diveSites_backfill_confirm_body(count, minutes)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.diveSites_backfill_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.diveSites_backfill_confirm_start),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  notifier.reset();
  final run = notifier.start();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BackfillProgressDialog(),
  );
  await run;
  if (!context.mounted) return;

  final state = ref.read(siteLocationBackfillProvider);
  if (state is! BackfillFinished) return;
  final summary = state.summary;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        summary.offline
            ? l10n.diveSites_backfill_offline
            : l10n.diveSites_backfill_summary(
                summary.updated,
                summary.unchanged,
                summary.failed,
              ),
      ),
    ),
  );
  notifier.reset();
}

/// Watches the run and closes itself when it finishes.
class _BackfillProgressDialog extends ConsumerWidget {
  const _BackfillProgressDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(siteLocationBackfillProvider);

    ref.listen<BackfillState>(siteLocationBackfillProvider, (_, next) {
      if (next is BackfillFinished && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final running = state is BackfillRunning ? state : null;
    final total = running?.total ?? 0;
    final done = running?.done ?? 0;
    return AlertDialog(
      title: Text(l10n.diveSites_backfill_progress_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: total == 0 ? null : done / total),
          const SizedBox(height: 12),
          Text(l10n.diveSites_backfill_progress_count(done, total)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              ref.read(siteLocationBackfillProvider.notifier).cancel(),
          child: Text(l10n.diveSites_backfill_cancel),
        ),
      ],
    );
  }
}
```

If `BackfillFinished` arrives before the progress dialog is first built (a run with zero sites cannot happen here, but a very fast run can), the `ref.listen` never fires; guard by checking `if (state is BackfillFinished)` at the top of `build` and scheduling `Navigator.of(context).pop()` in a post-frame callback.

- [ ] **Step 9: Add the menu items**

In `lib/features/dive_sites/presentation/widgets/site_list_content.dart`, in both `PopupMenuButton<String>` blocks (lines 515 and 777): add to `onSelected`

```dart
                        } else if (value == 'fill_location_details') {
                          showSiteLocationBackfillFlow(context, ref);
```

and add to the item list, after the `'import'` item (find it with `grep -n "value: 'import'" lib/features/dive_sites/presentation/widgets/site_list_content.dart`):

```dart
                          PopupMenuItem(
                            value: 'fill_location_details',
                            child: ListTile(
                              leading: const Icon(Icons.travel_explore),
                              title: Text(
                                context.l10n
                                    .diveSites_list_menu_fillLocationDetails,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
```

with `import 'package:submersion/features/dive_sites/presentation/widgets/site_location_backfill_dialog.dart';`.

In `lib/features/dive_sites/presentation/pages/site_list_page.dart` (`PopupMenuButton<String>` at line 173), add the same `onSelected` branch and the same `PopupMenuItem` after the view-mode items, preceded by `const PopupMenuDivider(),`, with the same import.

- [ ] **Step 10: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites`
Expected: all pass. `flutter analyze`: `No issues found!`

- [ ] **Step 11: Commit**

```bash
dart format . && git add lib/features/dive_sites lib/l10n test/features/dive_sites && git commit -m "feat(sites): bulk fill of missing location details from the sites list (#1187)"
```

---

### Task 13: Whole-tree verification

**Files:**
- No new files. Fixes only where the checks below fail.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: `Formatted N files (0 changed)` and `No issues found!`. If format changed anything, commit it as `style: format`.

- [ ] **Step 2: Confirm nothing still uses the old geocode shape**

Run: `grep -rn "String? locality})\|_geocoderLocale\|accept-language=en" lib/ test/`
Expected: no output. Fix and commit anything found.

- [ ] **Step 3: Confirm every locale has every new key**

Run:

```bash
for k in settings_placeNameLanguage_title settings_placeNameLanguage_subtitle diveSites_edit_gps_lookupFromCoordinates diveSites_edit_snackbar_lookupNothingFound diveSites_edit_snackbar_lookupFailed diveSites_edit_lookupReplace_title diveSites_edit_lookupReplace_body diveSites_edit_lookupReplace_replace diveSites_edit_lookupReplace_keep diveSites_list_menu_fillLocationDetails diveSites_backfill_confirm_title diveSites_backfill_confirm_body diveSites_backfill_confirm_start diveSites_backfill_nothingToFill diveSites_backfill_progress_title diveSites_backfill_progress_count diveSites_backfill_cancel diveSites_backfill_summary diveSites_backfill_offline; do for f in lib/l10n/arb/app_*.arb; do grep -q "\"$k\"" "$f" || echo "MISSING $k in $f"; done; done
```

Expected: no output.

- [ ] **Step 4: Run the full suite once**

Run: `flutter test 2>&1 | tail -3`
Expected: `All tests passed!`. If exactly one file unrelated to this branch fails, rerun that file alone; a repeat failure is real and must be fixed before finishing. Do not run the full suite twice on a green result.

- [ ] **Step 5: Final commit and hand-off**

If any step above changed files, `dart format . && git add -A && git commit -m "chore(sites): verification fixes for location details from coordinates (#1187)"`. Then report: the branch name, the commit list (`git log --oneline origin/main..HEAD`), and the full-suite line. Do not push; the user opens the PR.
