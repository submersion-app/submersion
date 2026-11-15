import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Which kinds of built-in catalogue record the Sites map draws.
///
/// Dive sites are on unless the diver turns them off. Charted wrecks and
/// reefs are off unless the diver turns them on: there are four of them
/// for every dive site, and around Britain or Florida they alone fill
/// the map.
class BuiltInMapLayers extends Equatable {
  const BuiltInMapLayers({this.diveSites = true, this.registers = false});

  /// Records from sources that list places people dive.
  final bool diveSites;

  /// Records from wreck registers and reef deployment lists.
  final bool registers;

  /// Whether the map draws any built-in record at all.
  bool get any => diveSites || registers;

  /// The kinds that are on, as the catalogue is asked for them.
  Set<CatalogueKind> get kinds => {
    if (diveSites) CatalogueKind.site,
    if (registers) CatalogueKind.register,
  };

  bool shows(CatalogueKind kind) => switch (kind) {
    CatalogueKind.site => diveSites,
    CatalogueKind.register => registers,
  };

  /// These layers with [kind] turned [on] or off.
  BuiltInMapLayers withKind(CatalogueKind kind, bool on) => switch (kind) {
    CatalogueKind.site => BuiltInMapLayers(diveSites: on, registers: registers),
    CatalogueKind.register => BuiltInMapLayers(
      diveSites: diveSites,
      registers: on,
    ),
  };

  @override
  List<Object?> get props => [diveSites, registers];
}

/// The diver's [BuiltInMapLayers] choice, stored per device.
///
/// Device-local like `ViewerFullscreenModeNotifier`: how many pins a map
/// has room for is a property of the screen, and it needs no settings
/// column. Seeded synchronously from SharedPreferences, so the first map
/// opened already draws the right layers.
///
/// Only a change the diver makes is written. A layer the diver never
/// touched has no key and reads as the default, whatever the default is
/// in the version that reads it.
class BuiltInMapLayersNotifier extends StateNotifier<BuiltInMapLayers> {
  BuiltInMapLayersNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(_read(prefs));

  /// Fixed state with nothing behind it, for a container without
  /// SharedPreferences; [setLayer] then changes only the live state.
  BuiltInMapLayersNotifier.unstored([super.layers = const BuiltInMapLayers()])
    : _prefs = null;

  static final _log = LoggerService.forClass(BuiltInMapLayersNotifier);

  final SharedPreferences? _prefs;

  /// Writes are sent one after another, so a layer ticked and unticked in
  /// quick succession can never have its older value stored last and
  /// shown at the next launch. The store is not asked to keep the order
  /// itself: nothing in its interface says it does.
  Future<void> _writes = Future.value();

  static BuiltInMapLayers _read(SharedPreferences prefs) {
    const defaults = BuiltInMapLayers();
    return BuiltInMapLayers(
      diveSites: _stored(prefs, CatalogueKind.site) ?? defaults.diveSites,
      registers: _stored(prefs, CatalogueKind.register) ?? defaults.registers,
    );
  }

  /// The stored choice for [kind], or null with none. A value that is not
  /// a bool (a damaged or hand-edited store) counts as none: `getBool`
  /// would throw on it, and a map must still open.
  static bool? _stored(SharedPreferences prefs, CatalogueKind kind) {
    final value = prefs.get(_key(kind));
    return value is bool ? value : null;
  }

  static String _key(CatalogueKind kind) => switch (kind) {
    CatalogueKind.site => SettingsKeys.builtInDiveSitesOnMap,
    CatalogueKind.register => SettingsKeys.builtInRegistersOnMap,
  };

  /// Turns the layer of [kind] on or off, and remembers it.
  ///
  /// The map changes at once. The returned future completes when the
  /// choice has been stored, after any change made before it. It never
  /// fails: the menu that calls this does not wait for it, and a choice
  /// that could not be stored still stands until the app is closed.
  Future<void> setLayer(CatalogueKind kind, bool on) async {
    if (state.shows(kind) == on) return;
    state = state.withKind(kind, on);
    final prefs = _prefs;
    if (prefs == null) return;
    final write = _writes.then((_) async {
      try {
        await prefs.setBool(_key(kind), on);
      } catch (error, stackTrace) {
        _log.warning(
          'Could not remember the built-in map layers; the next launch '
          'will show them as they were',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    _writes = write;
    await write;
  }
}

/// Defaults to the built-in defaults with no storage behind them, so a
/// container without SharedPreferences (most widget tests) still draws a
/// map. `rootProviderOverrides` swaps in the stored notifier for the app.
final builtInMapLayersNotifierProvider =
    StateNotifierProvider<BuiltInMapLayersNotifier, BuiltInMapLayers>(
      (ref) => BuiltInMapLayersNotifier.unstored(),
    );
