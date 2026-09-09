import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('collapsedTripIdsProvider', () {
    test('starts empty', () async {
      final container = await makeContainer();
      expect(container.read(collapsedTripIdsProvider), isEmpty);
    });

    test('toggle adds then removes a trip id', () async {
      final container = await makeContainer();
      final notifier = container.read(collapsedTripIdsProvider.notifier);

      notifier.toggle('t1');
      expect(container.read(collapsedTripIdsProvider), {'t1'});

      notifier.toggle('t1');
      expect(container.read(collapsedTripIdsProvider), isEmpty);
    });

    test(
      'a collapsed id survives a new container over the same prefs',
      () async {
        final container = await makeContainer();
        container.read(collapsedTripIdsProvider.notifier).toggle('t1');

        final second = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(second.dispose);

        expect(second.read(collapsedTripIdsProvider), {'t1'});
      },
    );

    test('collapseAll keeps what is already collapsed', () async {
      final container = await makeContainer();
      final notifier = container.read(collapsedTripIdsProvider.notifier);

      notifier.toggle('t1');
      notifier.collapseAll(['t2', 't3']);

      expect(container.read(collapsedTripIdsProvider), {'t1', 't2', 't3'});
    });

    test('expandAll clears everything', () async {
      final container = await makeContainer();
      final notifier = container.read(collapsedTripIdsProvider.notifier);

      notifier.collapseAll(['t1', 't2']);
      notifier.expandAll();

      expect(container.read(collapsedTripIdsProvider), isEmpty);
    });
  });
}
