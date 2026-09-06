import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database_provenance.dart';

/// The parser is the half of the frozen contract that runs on files it did
/// not write. An OLDER build reads these rows out of a database a NEWER build
/// produced (issue #1593), so every case here is "a future build wrote
/// something this build has never seen" and the only acceptable answer is a
/// degraded record, never a throw.
void main() {
  group('DatabaseProvenanceRecord.parse', () {
    test('an empty table reads back as an empty record', () {
      final record = DatabaseProvenanceRecord.parse(const {});
      expect(record.isEmpty, isTrue);
      expect(record.lastOpen, isNull);
      expect(record.previousOpen, isNull);
      expect(record.lastUpgrade, isNull);
    });

    test('reads a full three-entry record', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '1.7.7.8064',
        'release_train': 'beta',
        'schema_version': '194',
        'written_at': '2026-09-05T10:11:12.000Z',
        'install_id': 'device-a',
        'previous_app_version': '1.7.6.7161',
        'previous_release_train': 'stable',
        'previous_schema_version': '191',
        'previous_written_at': '2026-08-01T00:00:00.000Z',
        'previous_install_id': 'device-a',
        'upgrade_app_version': '1.7.7.8064',
        'upgrade_release_train': 'beta',
        'upgrade_to_schema_version': '194',
        'upgrade_from_schema_version': '191',
        'upgrade_written_at': '2026-09-05T10:11:12.000Z',
        'upgrade_install_id': 'device-a',
      });

      expect(record.lastOpen!.appVersion, '1.7.7.8064');
      expect(record.lastOpen!.releaseTrain, 'beta');
      expect(record.lastOpen!.schemaVersion, 194);
      expect(record.lastOpen!.installId, 'device-a');
      expect(record.lastOpen!.writtenAt, DateTime.utc(2026, 9, 5, 10, 11, 12));

      expect(record.previousOpen!.appVersion, '1.7.6.7161');
      expect(record.previousOpen!.schemaVersion, 191);

      expect(record.lastUpgrade!.schemaVersion, 194);
      expect(record.lastUpgrade!.fromSchemaVersion, 191);
      expect(record.lastUpgrade!.releaseTrain, 'beta');
    });

    test('keys this build has never heard of are ignored', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '2.0.0.1',
        'a_fact_invented_in_2028': 'whatever this means',
        'upgrade_reason': 'sidegrade',
      });
      expect(record.lastOpen!.appVersion, '2.0.0.1');
      expect(record.lastUpgrade, isNull);
    });

    test('an unparseable schema version degrades to null, not a throw', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '2.0.0.1',
        'schema_version': '194-rc1',
      });
      expect(record.lastOpen!.schemaVersion, isNull);
      expect(record.lastOpen!.appVersion, '2.0.0.1');
    });

    test('an unparseable timestamp degrades to null', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '2.0.0.1',
        'written_at': 'last Tuesday',
      });
      expect(record.lastOpen!.writtenAt, isNull);
    });

    test('an offset timestamp is normalised to UTC', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'written_at': '2026-09-05T12:00:00+02:00',
      });
      final writtenAt = record.lastOpen!.writtenAt!;
      expect(writtenAt.isUtc, isTrue);
      expect(writtenAt, DateTime.utc(2026, 9, 5, 10));
    });

    test('blank and whitespace-only values are treated as absent', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '',
        'release_train': '   ',
      });
      expect(record.isEmpty, isTrue);
    });

    test('a train name that did not exist yet still round-trips', () {
      // The train is free text precisely so a build older than the train can
      // still name it on the mismatch screen.
      final record = DatabaseProvenanceRecord.parse(const {
        'release_train': 'nightly',
      });
      expect(record.lastOpen!.releaseTrain, 'nightly');
    });

    test('an entry with nothing usable is dropped rather than surfaced', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '2.0.0.1',
        'previous_app_version': '   ',
      });
      expect(record.lastOpen, isNotNull);
      expect(record.previousOpen, isNull);
    });
  });

  group('toString', () {
    // Self-describing bug reports are one of the stated payoffs of recording
    // provenance at all (issue #1593): a record that reaches a log line has to
    // carry the facts a reader needs without them going back to the file.
    test('a record names every entry it holds', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '1.7.8.8200',
        'previous_app_version': '1.7.6.7161',
        'upgrade_app_version': '1.7.7.8064',
      });

      final rendered = record.toString();
      expect(rendered, contains('1.7.8.8200'));
      expect(rendered, contains('1.7.6.7161'));
      expect(rendered, contains('1.7.7.8064'));
    });

    test('an entry names the build, the train, and both rungs', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'upgrade_app_version': '1.7.7.8064',
        'upgrade_release_train': 'beta',
        'upgrade_to_schema_version': '194',
        'upgrade_from_schema_version': '191',
        'upgrade_written_at': '2026-09-05T10:11:12.000Z',
        'upgrade_install_id': 'device-a',
      });

      final rendered = record.lastUpgrade.toString();
      expect(rendered, contains('1.7.7.8064'));
      expect(rendered, contains('beta'));
      // Both rungs: "upgraded TO 194" and "FROM 191" are the pair that makes a
      // mismatch report actionable, and one without the other is not.
      expect(rendered, contains('194'));
      expect(rendered, contains('191'));
      expect(rendered, contains('device-a'));
      expect(rendered, contains('2026-09-05'));
    });

    test('an absent entry renders as null rather than an empty shell', () {
      final record = DatabaseProvenanceRecord.parse(const {
        'app_version': '1.7.8.8200',
      });
      expect(record.toString(), contains('previousOpen: null'));
      expect(record.toString(), contains('lastUpgrade: null'));
    });
  });
}
