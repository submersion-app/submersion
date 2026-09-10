import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  ProviderContainer containerOver(
    SharedPreferences existing, {
    String? diverId,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(existing),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverId(diverId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderContainer> makeContainer({String? diverId}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    return containerOver(prefs, diverId: diverId);
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

    test('one diver\'s collapsed trips do not fold them for another', () async {
      final first = await makeContainer(diverId: 'diver-a');
      first.read(collapsedTripIdsProvider.notifier).toggle('t1');
      expect(first.read(collapsedTripIdsProvider), {'t1'});

      final second = containerOver(prefs, diverId: 'diver-b');

      expect(
        second.read(collapsedTripIdsProvider),
        isEmpty,
        reason: 'collapse state is scoped to the diver who folded the trip',
      );
    });

    test('each diver keeps their own collapsed set', () async {
      final a = await makeContainer(diverId: 'diver-a');
      a.read(collapsedTripIdsProvider.notifier).toggle('t1');

      final b = containerOver(prefs, diverId: 'diver-b');
      b.read(collapsedTripIdsProvider.notifier).toggle('t2');

      expect(
        containerOver(prefs, diverId: 'diver-a').read(collapsedTripIdsProvider),
        {'t1'},
      );
      expect(
        containerOver(prefs, diverId: 'diver-b').read(collapsedTripIdsProvider),
        {'t2'},
      );
    });

    test(
      'a failing write does not escape as an unhandled async error',
      () async {
        SharedPreferences.setMockInitialValues({});
        final failing = _ThrowingPrefs(await SharedPreferences.getInstance());
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(failing),
            currentDiverIdProvider.overrideWith((ref) => _FixedDiverId(null)),
          ],
        );
        addTearDown(container.dispose);

        container.read(collapsedTripIdsProvider.notifier).toggle('t1');

        // The in-memory set still moved; only the disk write failed.
        expect(container.read(collapsedTripIdsProvider), {'t1'});
        // Give the rejected future a turn to surface if it were unhandled.
        await Future<void>.delayed(Duration.zero);
        expect(failing.writeAttempts, 1);
      },
    );

    test(
      'expand opens one trip and leaves the collapse control usable',
      () async {
        final container = await makeContainer();
        final notifier = container.read(collapsedTripIdsProvider.notifier);

        notifier.collapseAll(['t1', 't2']);
        notifier.expand('t1');

        expect(container.read(collapsedTripIdsProvider), {'t2'});

        // The point of expanding for real rather than overriding at render
        // time: the header's own toggle still works afterwards.
        notifier.toggle('t1');
        expect(container.read(collapsedTripIdsProvider), {'t1', 't2'});
      },
    );

    test('expand is a no-op on a trip that is already open', () async {
      final container = await makeContainer();
      final notifier = container.read(collapsedTripIdsProvider.notifier);

      notifier.collapseAll(['t2']);
      notifier.expand('t1');

      expect(container.read(collapsedTripIdsProvider), {'t2'});
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

/// Pins the active diver for a container, standing in for the real notifier.
class _FixedDiverId extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverId(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// SharedPreferences whose writes always reject, standing in for a full disk
/// or a revoked container.
class _ThrowingPrefs implements SharedPreferences {
  _ThrowingPrefs(this._inner);

  final SharedPreferences _inner;
  int writeAttempts = 0;

  @override
  Future<bool> setStringList(String key, List<String> value) {
    writeAttempts++;
    return Future<bool>.error(Exception('disk full'));
  }

  @override
  List<String>? getStringList(String key) => _inner.getStringList(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
