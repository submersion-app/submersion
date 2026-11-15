import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Preferences holding [values], put back to empty when the test ends: the
/// mock store is process-wide, and other files run in this isolate.
Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  addTearDown(() => SharedPreferences.setMockInitialValues({}));
  return SharedPreferences.getInstance();
}

/// Preferences whose writes finish only when the test lets them, in
/// whatever order it chooses, and which can be told to fail.
class _GatedPrefs implements SharedPreferences {
  /// Every write as it was started, in order.
  final started = <(String, bool)>[];

  /// What has landed, as a store that takes the last write to finish.
  final stored = <String, bool>{};

  final _gates = <Completer<void>>[];

  /// The write to fail when it is released, by its place in [started].
  int? failAt;

  /// Lets the write at [index] of [started] finish.
  void release(int index) => _gates[index].complete();

  @override
  Object? get(String key) => stored[key];

  @override
  Future<bool> setBool(String key, bool value) async {
    final index = started.length;
    started.add((key, value));
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    if (failAt == index) throw StateError('the store refused the write');
    stored[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BuiltInMapLayers', () {
    test('by default shows dive sites and not register records', () {
      const layers = BuiltInMapLayers();
      expect(layers.diveSites, isTrue);
      expect(layers.registers, isFalse);
      expect(layers.any, isTrue);
      expect(layers.kinds, {CatalogueKind.site});
      expect(layers.shows(CatalogueKind.site), isTrue);
      expect(layers.shows(CatalogueKind.register), isFalse);
    });

    test('with both off shows nothing', () {
      const layers = BuiltInMapLayers(diveSites: false);
      expect(layers.any, isFalse);
      expect(layers.kinds, isEmpty);
    });

    test('withKind changes one layer and leaves the other', () {
      const layers = BuiltInMapLayers();
      expect(
        layers.withKind(CatalogueKind.register, true),
        const BuiltInMapLayers(registers: true),
      );
      expect(
        layers.withKind(CatalogueKind.site, false),
        const BuiltInMapLayers(diveSites: false),
      );
    });
  });

  group('BuiltInMapLayersNotifier', () {
    test('with nothing stored starts on the defaults', () async {
      final notifier = BuiltInMapLayersNotifier(await _prefs());
      addTearDown(notifier.dispose);
      expect(notifier.state, const BuiltInMapLayers());
    });

    test('each stored combination is read back', () async {
      for (final diveSites in [true, false]) {
        for (final registers in [true, false]) {
          final notifier = BuiltInMapLayersNotifier(
            await _prefs({
              SettingsKeys.builtInDiveSitesOnMap: diveSites,
              SettingsKeys.builtInRegistersOnMap: registers,
            }),
          );
          expect(
            notifier.state,
            BuiltInMapLayers(diveSites: diveSites, registers: registers),
          );
          notifier.dispose();
        }
      }
    });

    test('nothing is written at start', () async {
      final prefs = await _prefs();
      BuiltInMapLayersNotifier(prefs).dispose();
      expect(prefs.getKeys(), isEmpty);
    });

    test('a change is written under its own key and nothing else is', () async {
      final prefs = await _prefs();
      final notifier = BuiltInMapLayersNotifier(prefs);
      addTearDown(notifier.dispose);

      await notifier.setLayer(CatalogueKind.register, true);

      expect(notifier.state, const BuiltInMapLayers(registers: true));
      expect(prefs.getKeys(), {SettingsKeys.builtInRegistersOnMap});
      expect(prefs.getBool(SettingsKeys.builtInRegistersOnMap), isTrue);

      await notifier.setLayer(CatalogueKind.site, false);

      expect(
        notifier.state,
        const BuiltInMapLayers(diveSites: false, registers: true),
      );
      expect(prefs.getBool(SettingsKeys.builtInDiveSitesOnMap), isFalse);
    });

    test('setting a layer to what it already is writes nothing', () async {
      final prefs = await _prefs();
      final notifier = BuiltInMapLayersNotifier(prefs);
      addTearDown(notifier.dispose);

      await notifier.setLayer(CatalogueKind.site, true);

      expect(prefs.getKeys(), isEmpty);
    });

    test('a value of the wrong type reads as the default', () async {
      final notifier = BuiltInMapLayersNotifier(
        await _prefs({
          SettingsKeys.builtInDiveSitesOnMap: 'no',
          SettingsKeys.builtInRegistersOnMap: 1,
        }),
      );
      addTearDown(notifier.dispose);
      expect(notifier.state, const BuiltInMapLayers());
    });

    test('the unstored notifier changes only the live state', () async {
      final notifier = BuiltInMapLayersNotifier.unstored();
      addTearDown(notifier.dispose);
      expect(notifier.state, const BuiltInMapLayers());

      await notifier.setLayer(CatalogueKind.register, true);

      expect(notifier.state, const BuiltInMapLayers(registers: true));
    });
  });

  group('writes are stored in the order they were made', () {
    const key = SettingsKeys.builtInRegistersOnMap;

    test('a second change waits for the first to be stored', () async {
      final prefs = _GatedPrefs();
      final notifier = BuiltInMapLayersNotifier(prefs);
      addTearDown(notifier.dispose);

      // Ticked and unticked at once, before the store has answered.
      final on = notifier.setLayer(CatalogueKind.register, true);
      final off = notifier.setLayer(CatalogueKind.register, false);
      await pumpEventQueue();

      // The live state is the newest at once; only the first write has
      // been sent. Sent together, a store that finishes them out of order
      // would keep the older one, and the next launch would show wrecks
      // the diver had turned off.
      expect(notifier.state.registers, isFalse);
      expect(prefs.started, [(key, true)]);

      prefs.release(0);
      await pumpEventQueue();
      expect(prefs.started, [(key, true), (key, false)]);

      prefs.release(1);
      await Future.wait([on, off]);
      expect(prefs.stored[key], isFalse);
    });

    test('a write that fails is not the caller\'s to catch, and does not '
        'hold up the next', () async {
      final prefs = _GatedPrefs()..failAt = 0;
      final notifier = BuiltInMapLayersNotifier(prefs);
      addTearDown(notifier.dispose);

      // The menu drops this future: a failure must not escape through it.
      final first = notifier.setLayer(CatalogueKind.register, true);
      final second = notifier.setLayer(CatalogueKind.site, false);
      await pumpEventQueue();
      prefs.release(0);
      await expectLater(first, completes);

      await pumpEventQueue();
      prefs.release(1);
      await expectLater(second, completes);

      // The choice still stands for this run, and the later one is kept.
      expect(
        notifier.state,
        const BuiltInMapLayers(diveSites: false, registers: true),
      );
      expect(prefs.stored, {SettingsKeys.builtInDiveSitesOnMap: false});
    });
  });

  test('the provider defaults to the unstored defaults', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(builtInMapLayersNotifierProvider),
      const BuiltInMapLayers(),
    );
  });
}
