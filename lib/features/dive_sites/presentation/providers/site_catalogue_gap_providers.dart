import 'dart:async';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// The write behind applying a catalogue pair to an existing site.
// no-tick: a repository that writes; it holds no data.
final siteCatalogueFillRepositoryProvider =
    Provider<SiteCatalogueFillRepository>((ref) {
      return SiteCatalogueFillRepository(
        classification: ref.watch(siteClassificationRepositoryProvider),
        sites: ref.watch(siteRepositoryProvider),
      );
    });

/// Finds and applies catalogue pairs for the diver's existing sites.
// no-tick: a service; it holds no data.
final catalogueGapServiceProvider = Provider<CatalogueGapService>((ref) {
  return CatalogueGapService(
    siteRepository: ref.watch(siteRepositoryProvider),
    catalogue: ref.watch(siteCatalogueProvider),
    classification: ref.watch(siteClassificationRepositoryProvider),
    fills: ref.watch(siteCatalogueFillRepositoryProvider),
    fetchElevation: (point) => ref
        .read(elevationServiceProvider)
        .fetchElevation(latitude: point.latitude, longitude: point.longitude),
    loadSeas: SeaAreaService.load,
    placeNameLanguage: () => ref.read(placeNameLanguageProvider),
  );
});

/// The catalogue pairs the current diver can be offered: their existing
/// sites that a built-in record matches and has something to give.
///
/// The notice on the Sites page, the review list and the line on a site's
/// page all read this one list. It is found again when a site or a site's
/// types change, when a catalogue import lands and when the diver changes.
/// Nothing waits on it: until it is ready there are simply no pairs.
final catalogueGapPairsProvider = FutureProvider<List<CataloguePair>>((
  ref,
) async {
  // The catalogue's tables carry no change tick; an import bumps this.
  ref.watch(siteCatalogueRevisionProvider);
  final sites = ref.watch(siteRepositoryProvider);
  final classification = ref.watch(siteClassificationRepositoryProvider);
  final service = ref.watch(catalogueGapServiceProvider);
  // A search reads the catalogue once per site. When a change replaces it
  // with a newer one, it is told to stop: a burst of site writes (a file
  // import, a bulk lookup) then costs one read per write and one full
  // search at the end, not a full search per write.
  var superseded = false;
  ref.onDispose(() => superseded = true);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(sites.watchSitesChanges());
  ref.invalidateSelfWhen(classification.watchChanges());
  return service.findPairs(diverId: diverId, isCancelled: () => superseded);
});

/// What follows every write made from a catalogue pair: the pairs are
/// found again, and the site list some screens hold in memory is told.
///
/// Takes the container, not a Ref. The diver may leave the screen that
/// started the write while it is under way, and this must still happen
/// once that screen's own state has gone.
void catalogueGapWritten(ProviderContainer container) {
  container.invalidate(catalogueGapPairsProvider);
  container.invalidate(siteListNotifierProvider);
}

/// The pair for one site, or null: none, or the pairs are not found yet.
final catalogueGapPairForSiteProvider = Provider.family<CataloguePair?, String>(
  (ref, siteId) => ref
      .watch(catalogueGapPairsProvider)
      .value
      ?.firstWhereOrNull((pair) => pair.site.id == siteId),
);

const String kCatalogueGapNoticeSeenPrefsKey = 'site_catalogue_gap_notice_seen';

String catalogueGapNoticeSeenPrefsKeyFor(String? diverId) => diverId == null
    ? kCatalogueGapNoticeSeenPrefsKey
    : '$kCatalogueGapNoticeSeenPrefsKey:$diverId';

/// The pairs that were waiting when the diver last dismissed the notice
/// on the Sites page, each by its [CataloguePair.key].
///
/// Device-local on purpose. Having waved a notice away is not logbook
/// data: the pairs themselves stay on the review list, and what the diver
/// answered about them is stored with the site and synced. Kept per diver.
class CatalogueGapNoticeNotifier extends StateNotifier<Set<String>> {
  CatalogueGapNoticeNotifier(this._prefs, this._diverId)
    : super(
        _prefs
                .getStringList(catalogueGapNoticeSeenPrefsKeyFor(_diverId))
                ?.toSet() ??
            {},
      );

  static final _log = LoggerService.forClass(CatalogueGapNoticeNotifier);

  final SharedPreferences _prefs;
  final String? _diverId;

  /// Writes are sent one after another, so a later dismissal can never be
  /// stored before an earlier one and then be overwritten by it.
  Future<void> _writes = Future.value();

  /// Remembers [keys] as the pairs the diver has seen the notice for,
  /// replacing what was remembered: a pair that has since left the list
  /// need not be kept.
  void dismiss(Iterable<String> keys) {
    final next = keys.toSet();
    state = next;
    _writes = _writes.then((_) async {
      try {
        await _prefs.setStringList(
          catalogueGapNoticeSeenPrefsKeyFor(_diverId),
          next.toList(),
        );
      } catch (error, stackTrace) {
        _log.warning(
          'Could not remember the dismissed catalogue notice; it will '
          'show again on the next launch',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }
}

final catalogueGapNoticeSeenProvider =
    StateNotifierProvider<CatalogueGapNoticeNotifier, Set<String>>((ref) {
      return CatalogueGapNoticeNotifier(
        ref.watch(sharedPreferencesProvider),
        ref.watch(currentDiverIdProvider),
      );
    });

/// How many pairs the notice on the Sites page announces; 0 hides it.
///
/// Every waiting pair is counted, and the notice shows only while at
/// least one of them is new since the diver last dismissed it: a pair
/// that was not there, or one whose offer has grown.
final catalogueGapNoticeCountProvider = Provider<int>((ref) {
  final pairs = ref.watch(catalogueGapPairsProvider).value ?? const [];
  // With no pairs there is nothing to compare against what was dismissed,
  // and the device's preferences are not read at all.
  if (pairs.isEmpty) return 0;
  final seen = ref.watch(catalogueGapNoticeSeenProvider);
  return pairs.any((pair) => !seen.contains(pair.key)) ? pairs.length : 0;
});
