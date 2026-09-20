import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// A retirement rejoin replays the pending snapshot with fresh clocks so the
/// rows sort above the adopted watermark. A media row pending only because
/// of a fact write must not get a fresh ROW clock: that would republish this
/// device's whole snapshot of it and let a stale caption beat a peer's newer
/// edit (media sync program spec 5.1).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await SyncRepository().ensureSyncClockConfigured();
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  /// Real clocks: an issued HLC is a canonical zero-padded string, so a
  /// letter stand-in would compare the wrong way round.
  late String earlier;
  late String later;

  setUp(() {
    earlier = SyncClock.instance.issue()!;
    later = SyncClock.instance.issue()!;
    expect(later.compareTo(earlier), greaterThan(0));
  });

  Map<String, dynamic> mediaRow({
    required String hlc,
    String? upload,
    String? verify,
  }) => {
    'id': 'm1',
    'caption': 'mine',
    'hlc': hlc,
    'uploadFactsHlc': upload,
    'verifyFactsHlc': verify,
  };

  test('a fact-only pending row keeps its row clock', () {
    final row = mediaRow(hlc: earlier, upload: later);
    final out = SyncService.restampRowForReplay('media', row);

    expect(
      out['hlc'],
      earlier,
      reason: 'the last local write was a fact write',
    );
    expect(
      (out['uploadFactsHlc'] as String).compareTo(later),
      greaterThan(0),
      reason: 'the facts must still republish',
    );
    expect(out['verifyFactsHlc'], isNull, reason: 'absent stays absent');
  });

  test('a row whose last write was a user edit is restamped', () {
    final row = mediaRow(hlc: later, upload: earlier);
    final out = SyncService.restampRowForReplay('media', row);

    expect((out['hlc'] as String).compareTo(later), greaterThan(0));
    expect(
      (out['uploadFactsHlc'] as String).compareTo(earlier),
      greaterThan(0),
    );
  });

  test('an entity with no fact groups is restamped as before', () {
    final out = SyncService.restampRowForReplay('dives', {
      'id': 'd1',
      'hlc': earlier,
    });

    expect((out['hlc'] as String).compareTo(earlier), greaterThan(0));
  });
}
