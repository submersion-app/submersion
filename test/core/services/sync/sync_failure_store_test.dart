import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/sync_failure_store.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SyncFailureStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = SyncFailureStore(prefs);
  });

  test('empty by default', () {
    expect(store.last, isNull);
  });

  test('record round-trips every field and survives a new instance', () async {
    final at = DateTime(2026, 10, 17, 8, 15);
    await store.record(
      SyncFailureRecord(
        providerId: 'dropbox',
        at: at,
        kind: SyncFailureKind.network,
        message: 'timed out',
      ),
    );

    final read = SyncFailureStore(prefs).last!;
    expect(read.providerId, 'dropbox');
    expect(read.at, at);
    expect(read.kind, SyncFailureKind.network);
    expect(read.message, 'timed out');
  });

  test('clear removes the record', () async {
    await store.record(
      SyncFailureRecord(
        providerId: 'icloud',
        at: DateTime(2026),
        kind: SyncFailureKind.other,
        message: 'x',
      ),
    );
    await store.clear();
    expect(store.last, isNull);
  });

  test('malformed JSON reads as null', () async {
    await prefs.setString('sync_last_failure', '{not json');
    expect(store.last, isNull);
  });
}
