import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EstablishedProviderStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = EstablishedProviderStore(await SharedPreferences.getInstance());
  });

  test('unknown provider is not established', () {
    expect(store.contains('s3'), isFalse);
  });

  test('add marks a provider established and is idempotent', () async {
    await store.add('s3');
    await store.add('s3');
    expect(store.contains('s3'), isTrue);
  });

  test('is scoped per provider', () async {
    await store.add('s3');
    expect(store.contains('s3'), isTrue);
    expect(store.contains('icloud'), isFalse);
  });

  test('survives a new store instance over the same prefs (restore)', () async {
    await store.add('s3');
    final reopened = EstablishedProviderStore(
      await SharedPreferences.getInstance(),
    );
    expect(reopened.contains('s3'), isTrue);
  });

  test('clear forgets all providers', () async {
    await store.add('s3');
    await store.clear();
    expect(store.contains('s3'), isFalse);
  });
}
