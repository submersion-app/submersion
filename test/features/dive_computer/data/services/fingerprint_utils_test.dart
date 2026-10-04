import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

void main() {
  group('selectNewestFingerprint', () {
    test('returns null for empty list', () {
      expect(selectNewestFingerprint([]), isNull);
    });

    test('returns null when no dives have fingerprints', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 1, 1),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: [],
        ),
      ];
      expect(selectNewestFingerprint(dives), isNull);
    });

    test('returns fingerprint of the newest dive by startTime', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 1, 1, 10, 0),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: [],
          fingerprint: 'aabb01',
        ),
        DownloadedDive(
          startTime: DateTime(2026, 1, 3, 14, 0),
          durationSeconds: 2400,
          maxDepth: 25.0,
          profile: [],
          fingerprint: 'ccdd02',
        ),
        DownloadedDive(
          startTime: DateTime(2026, 1, 2, 8, 0),
          durationSeconds: 1800,
          maxDepth: 15.0,
          profile: [],
          fingerprint: 'eeff03',
        ),
      ];
      expect(selectNewestFingerprint(dives), equals('ccdd02'));
    });

    test('skips dives without fingerprints when selecting newest', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 1, 5),
          durationSeconds: 3600,
          maxDepth: 30.0,
          profile: [],
          // no fingerprint
        ),
        DownloadedDive(
          startTime: DateTime(2026, 1, 3),
          durationSeconds: 2400,
          maxDepth: 20.0,
          profile: [],
          fingerprint: 'aabb01',
        ),
      ];
      expect(selectNewestFingerprint(dives), equals('aabb01'));
    });

    test('handles single dive with fingerprint', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 3, 1),
          durationSeconds: 3000,
          maxDepth: 18.0,
          profile: [],
          fingerprint: 'single01',
        ),
      ];
      expect(selectNewestFingerprint(dives), equals('single01'));
    });
  });

  group('selectResumeFingerprint (issue #2902)', () {
    // A newest-first backend that stopped after one dive: the newest dive on
    // the device arrived, the dives between it and the saved fingerprint did
    // not.
    final older = DownloadedDive(
      startTime: DateTime(2026, 9, 19),
      durationSeconds: 3000,
      maxDepth: 17.0,
      profile: [],
      fingerprint: 'older',
    );
    final newer = DownloadedDive(
      startTime: DateTime(2026, 9, 20),
      durationSeconds: 3000,
      maxDepth: 18.0,
      profile: [],
      fingerprint: 'newer',
    );

    test('a complete download resumes from its newest dive', () {
      expect(
        selectResumeFingerprint(
          [newer, older],
          downloadComplete: true,
          deliversOldestFirst: false,
        ),
        'newer',
      );
    });

    test('an interrupted newest-first download keeps the saved one', () {
      // Advancing to 'newer' here hid every older dive the failed session
      // never reached.
      expect(
        selectResumeFingerprint(
          [newer],
          downloadComplete: false,
          deliversOldestFirst: false,
        ),
        isNull,
      );
      expect(
        selectResumeFingerprint(
          [newer, older],
          downloadComplete: false,
          deliversOldestFirst: false,
        ),
        isNull,
      );
    });

    test('an interrupted oldest-first download resumes from its newest', () {
      // The delivered dives are the oldest new ones, so nothing older than
      // the newest of them is still missing.
      expect(
        selectResumeFingerprint(
          [older, newer],
          downloadComplete: false,
          deliversOldestFirst: true,
        ),
        'newer',
      );
    });

    test('nothing imported leaves nothing to resume from', () {
      expect(
        selectResumeFingerprint(
          [],
          downloadComplete: true,
          deliversOldestFirst: true,
        ),
        isNull,
      );
    });
  });

  group('modelDeliversOldestFirst (issue #2902)', () {
    final descriptors = [
      pigeon.DeviceDescriptor(
        vendor: 'Shearwater',
        product: 'Perdix 3',
        model: 14,
        transports: [pigeon.TransportType.ble],
        deliversOldestFirst: true,
      ),
      pigeon.DeviceDescriptor(
        vendor: 'Halcyon',
        product: 'Symbios HUD',
        model: 1,
        transports: [pigeon.TransportType.ble],
      ),
    ];

    DeviceModel model(String vendor, String product, int? dcModel) =>
        DeviceModel(
          id: '$vendor $product',
          manufacturer: vendor,
          model: product,
          connectionTypes: const [DeviceConnectionType.ble],
          dcModel: dcModel,
        );

    test('reads the flag of the matching descriptor', () {
      expect(
        modelDeliversOldestFirst(
          descriptors,
          model('Shearwater', 'Perdix 3', 14),
        ),
        isTrue,
      );
      expect(
        modelDeliversOldestFirst(
          descriptors,
          model('Halcyon', 'Symbios HUD', 1),
        ),
        isFalse,
      );
    });

    test('an unknown or unmatched model counts as newest-first', () {
      // Newest-first is libdivecomputer's own order, and assuming it only
      // costs re-offering already imported dives as duplicates.
      expect(modelDeliversOldestFirst(descriptors, null), isFalse);
      expect(
        modelDeliversOldestFirst(
          descriptors,
          model('Shearwater', 'Perdix 3', 99),
        ),
        isFalse,
      );
      expect(
        modelDeliversOldestFirst(const [], model('Shearwater', 'Perdix 3', 14)),
        isFalse,
      );
    });

    test('a model without a model code matches on vendor and product', () {
      expect(
        modelDeliversOldestFirst(
          descriptors,
          model('Shearwater', 'Perdix 3', null),
        ),
        isTrue,
      );
    });
  });
}
