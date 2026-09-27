import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

/// MacDive stores `ZRAWDATE` to the minute; `ZIDENTIFIER` keeps the seconds
/// the computer reported (#2509).
void main() {
  late Uint8List losAngelesBplist;

  setUpAll(() async {
    losAngelesBplist = Uint8List.fromList(
      await File(
        'test/fixtures/macdive_sqlite/bplist_samples/macdive_ztimezone.bplist',
      ).readAsBytes(),
    );
  });

  MacDiveRawLogbook logbook(List<MacDiveRawDive> dives) => MacDiveRawLogbook(
    dives: dives,
    sitesByPk: const {},
    buddiesByPk: const {},
    tagsByPk: const {},
    gearByPk: const {},
    tanksByPk: const {},
    gasesByPk: const {},
    tankAndGases: const [],
    crittersByPk: const {},
    certifications: const [],
    serviceRecords: const [],
    events: const [],
    diveToBuddyPks: const {},
    diveToTagPks: const {},
    diveToGearPks: const {},
    diveToCritterPks: const {},
    unitsPreference: 'Metric',
  );

  Future<DateTime?> startOf(MacDiveRawDive dive) async {
    final payload = await MacDiveDiveMapper.toPayload(logbook([dive]));
    return payload.entitiesOf(ImportEntityType.dives).single['dateTime']
        as DateTime?;
  }

  test('restores the seconds from the identifier', () async {
    // Logged at 10:05:17 PDT; MacDive kept 17:05:00 UTC.
    final start = await startOf(
      MacDiveRawDive(
        pk: 1,
        uuid: 'dive-1',
        identifier: '20240701100517-1234567890',
        rawDate: DateTime.utc(2024, 7, 1, 17, 5),
        timezoneBplist: losAngelesBplist,
      ),
    );
    expect(start, DateTime.utc(2024, 7, 1, 10, 5, 17));
  });

  test('keeps the minute when the identifier is not a timestamp', () async {
    final start = await startOf(
      MacDiveRawDive(
        pk: 1,
        uuid: 'dive-1',
        identifier: '2015122911130-822199',
        rawDate: DateTime.utc(2024, 7, 1, 17, 5),
        timezoneBplist: losAngelesBplist,
      ),
    );
    expect(start, DateTime.utc(2024, 7, 1, 10, 5));
  });
}
