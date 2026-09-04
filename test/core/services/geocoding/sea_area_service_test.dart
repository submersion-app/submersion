import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SeaAreaService.resetCacheForTesting();
    // rootBundle is a process-wide CachingAssetBundle, so a load in an
    // earlier test would otherwise be served from its cache and the mock
    // below would never be consulted.
    rootBundle.clear();
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
    SeaAreaService.resetCacheForTesting();
    rootBundle.clear();
  });

  test('parses the bundled asset once and reuses it', () async {
    final first = SeaAreaService.load();
    final second = SeaAreaService.load();

    expect(
      identical(first, second),
      isTrue,
      reason: 'concurrent callers must share one 1.3 MB parse',
    );
    expect(await first, isNotNull);
    expect(await SeaAreaService.load(), same(await first));
  });

  test('an unreadable asset is read once, not once per lookup', () async {
    // A backfill calls this per site. Retrying a failed 1.3 MB read every
    // time would burn I/O and repeat the same warning for a whole logbook.
    var reads = 0;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      reads++;
      return null; // rootBundle turns this into "Unable to load asset".
    });

    expect(await SeaAreaService.load(), isNull);
    expect(await SeaAreaService.load(), isNull);
    expect(await SeaAreaService.load(), isNull);

    expect(reads, 1, reason: 'the failure must be remembered, not retried');
  });

  test('a missing table leaves the geocode without a body of water', () {
    SeaAreaService.setIndexForTesting(null);
    expect(SeaAreaService.load(), completion(isNull));
  });

  test('registers the attribution the CC-BY licence requires', () async {
    // Shipping the table means carrying its credit. This is a licence
    // obligation, so it is asserted rather than assumed.
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);

    SeaAreaService.registerLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final entry = entries.singleWhere(
      (e) => e.packages.contains('IHO Sea Areas'),
    );
    final text = entry.paragraphs.map((p) => p.text).join(' ');

    expect(text, contains('CC-BY 4.0'));
    expect(text, contains('Flanders Marine Institute'));
    expect(text, contains('10.14284/323'));
  });

  test('a seeded table is handed back as-is', () async {
    const seeded = SeaAreaIndex([]);
    SeaAreaService.setIndexForTesting(seeded);
    expect(await SeaAreaService.load(), same(seeded));
  });
}
