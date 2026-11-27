import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/firmware/data/firmware_catalogue_client.dart';
import 'package:submersion/features/firmware/data/firmware_catalogue_store.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_catalogue_providers.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The daily catalogue refresh (issue #5104): at most once a day, only while
/// checks are on, and a failed fetch keeps the last good copy.
void main() {
  late String sample;
  late Directory dir;
  late int requests;
  late http.Response Function() respond;

  setUpAll(() {
    sample = File(
      p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
    ).readAsStringSync();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('firmware_providers_test');
    addTearDown(() => dir.delete(recursive: true));
    requests = 0;
    respond = () => http.Response(sample, 200);
  });

  Future<ProviderContainer> container({bool checksOn = true}) async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.firmwareChecksEnabled: checksOn,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firmwareCatalogueStoreProvider.overrideWith(
          (ref) async => FirmwareCatalogueStore(dir),
        ),
        firmwareCatalogueClientProvider.overrideWithValue(
          FirmwareCatalogueClient(
            client: MockClient((_) async {
              requests++;
              return respond();
            }),
            url: Uri.parse('https://example.com/c.json'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  final t0 = DateTime.utc(2026, 11, 27, 8);

  test('a first refresh fetches and keeps the file', () async {
    final c = await container();
    expect(await c.read(firmwareCatalogueProvider.future), isNull);

    await c.read(firmwareCatalogueProvider.notifier).refreshIfDue(now: t0);

    expect(requests, 1);
    expect(c.read(firmwareCatalogueProvider).value!.models, hasLength(2));
    expect(await FirmwareCatalogueStore(dir).lastFetchedAt(), t0);
  });

  test('no second fetch within a day, one after', () async {
    final c = await container();
    final notifier = c.read(firmwareCatalogueProvider.notifier);
    await notifier.refreshIfDue(now: t0);
    await notifier.refreshIfDue(now: t0.add(const Duration(hours: 23)));
    expect(requests, 1);
    await notifier.refreshIfDue(now: t0.add(const Duration(hours: 24)));
    expect(requests, 2);
  });

  test('a failed or missing fetch keeps the stored copy', () async {
    await FirmwareCatalogueStore(dir).save(sample, t0);
    final later = t0.add(const Duration(days: 2));

    for (final response in [
      http.Response('Not Found', 404),
      http.Response('oops', 500),
      http.Response('{"format":9,"models":[]}', 200),
    ]) {
      respond = () => response;
      final c = await container();
      await c.read(firmwareCatalogueProvider.notifier).refreshIfDue(now: later);
      expect(
        (await c.read(firmwareCatalogueProvider.future))!.models,
        hasLength(2),
      );
    }
    expect(await FirmwareCatalogueStore(dir).lastFetchedAt(), t0);
  });

  test('with checks off nothing is fetched and nothing is shown', () async {
    await FirmwareCatalogueStore(dir).save(sample, t0);
    final c = await container(checksOn: false);

    await c
        .read(firmwareCatalogueProvider.notifier)
        .refreshIfDue(now: t0.add(const Duration(days: 2)));

    expect(requests, 0);
    expect(await c.read(firmwareCatalogueProvider.future), isNull);
  });

  test('turning checks back on shows the stored copy again', () async {
    await FirmwareCatalogueStore(dir).save(sample, t0);
    final c = await container(checksOn: false);
    expect(await c.read(firmwareCatalogueProvider.future), isNull);

    await c.read(firmwareChecksEnabledProvider.notifier).set(true);

    expect(
      (await c.read(firmwareCatalogueProvider.future))!.models,
      hasLength(2),
    );
  });

  test('both switches default on', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(firmwareChecksEnabledProvider), isTrue);
    expect(c.read(firmwareNotificationsEnabledProvider), isTrue);

    await c.read(firmwareNotificationsEnabledProvider.notifier).set(false);
    expect(prefs.getBool(SettingsKeys.firmwareNotificationsEnabled), isFalse);
  });
}
