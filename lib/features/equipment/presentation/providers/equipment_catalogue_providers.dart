import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_cache.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_client.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_parser.dart';
import 'package:submersion/features/equipment/data/catalogue/equipment_catalogue_refresher.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _log = LoggerService('EquipmentCatalogueProviders');

/// The catalogue copy bundled with this build (issue #5118).
const String kBundledEquipmentCataloguePath =
    'assets/data/equipment_catalogue.json';

/// The bundled catalogue's text, or null when the asset cannot be read.
final equipmentCatalogueBundledTextProvider = FutureProvider<String?>((
  ref,
) async {
  try {
    return await rootBundle.loadString(kBundledEquipmentCataloguePath);
  } on Object catch (e) {
    _log.warning('Bundled equipment catalogue unreadable: $e');
    return null;
  }
});

/// The last downloaded catalogue's text, or null when there is none.
final equipmentCatalogueCachedTextProvider = FutureProvider<String?>(
  (ref) => readEquipmentCatalogueCache(),
);

EquipmentCatalogueFile? _parse(String? text) =>
    text == null ? null : parseEquipmentCatalogue(text);

/// The catalogue the app reads: the newer of the bundled and downloaded
/// copies. Never an error: with neither readable, the empty catalogue, and
/// the gear editor simply suggests nothing.
final equipmentCatalogueProvider = FutureProvider<EquipmentCatalogue>((
  ref,
) async {
  try {
    final bundled = await ref.watch(
      equipmentCatalogueBundledTextProvider.future,
    );
    final cached = await ref.watch(equipmentCatalogueCachedTextProvider.future);
    final chosen = chooseEquipmentCatalogue(
      await compute(_parse, bundled),
      await compute(_parse, cached),
    );
    return chosen == null
        ? EquipmentCatalogue.empty
        : EquipmentCatalogue(chosen);
  } on Object catch (e) {
    _log.warning('Equipment catalogue could not be loaded: $e');
    return EquipmentCatalogue.empty;
  }
});

/// Whether this device downloads newer catalogue releases. Per device,
/// default on, seeded from preferences so the switch is right on frame one.
class EquipmentCatalogueUpdatesNotifier extends StateNotifier<bool> {
  EquipmentCatalogueUpdatesNotifier(this._prefs)
    : super(_prefs.getBool(SettingsKeys.equipmentCatalogueUpdates) ?? true);

  final SharedPreferences _prefs;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _prefs.setBool(SettingsKeys.equipmentCatalogueUpdates, enabled);
  }
}

final equipmentCatalogueUpdatesEnabledProvider =
    StateNotifierProvider<EquipmentCatalogueUpdatesNotifier, bool>(
      (ref) => EquipmentCatalogueUpdatesNotifier(
        ref.watch(sharedPreferencesProvider),
      ),
    );

final equipmentCatalogueHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Downloads a newer catalogue when one is due, and reloads the catalogue
/// when it kept one. Called at launch and on every resume; contains its own
/// failures, so it is safe to leave unawaited.
final equipmentCatalogueRefreshProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    final refresher = EquipmentCatalogueRefresher(
      fetch: EquipmentCatalogueClient(
        client: ref.read(equipmentCatalogueHttpClientProvider),
      ).fetch,
      writeCache: writeEquipmentCatalogueCache,
      prefs: ref.read(sharedPreferencesProvider),
      enabled: () => ref.read(equipmentCatalogueUpdatesEnabledProvider),
      isBrowser: ref.read(deviceCapabilitiesProvider).isBrowser,
    );
    if (await refresher.refreshIfDue()) {
      ref.invalidate(equipmentCatalogueCachedTextProvider);
    }
  };
});
