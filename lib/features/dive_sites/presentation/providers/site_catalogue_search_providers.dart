import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

const _log = LoggerService('ExternalSiteSearch');

/// How many catalogue matches the import page lists for one search.
const _searchLimit = 200;

/// What the "Import from Database" page shows for one search: the diver's
/// own matching sites and the built-in catalogue's.
class ExternalSiteSearchState {
  final String query;
  final bool isLoading;

  /// The catalogue's matches. A site the diver already adopted stays in the
  /// list; [linkedCatalogueIds] says which those are.
  final List<CatalogueSite> sites;

  /// Whether the catalogue has more matches than [sites] lists, so the
  /// page can say the list is cut short.
  final bool isTruncated;

  /// The catalogue records the diver's sites were adopted from.
  final Set<String> linkedCatalogueIds;
  final String? errorMessage;
  final List<domain.DiveSite> localSites;

  const ExternalSiteSearchState({
    this.query = '',
    this.isLoading = false,
    this.sites = const [],
    this.isTruncated = false,
    this.linkedCatalogueIds = const {},
    this.errorMessage,
    this.localSites = const [],
  });

  ExternalSiteSearchState copyWith({
    String? query,
    bool? isLoading,
    List<CatalogueSite>? sites,
    bool? isTruncated,
    Set<String>? linkedCatalogueIds,
    String? errorMessage,
    bool clearError = false,
    List<domain.DiveSite>? localSites,
  }) {
    return ExternalSiteSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      sites: sites ?? this.sites,
      isTruncated: isTruncated ?? this.isTruncated,
      linkedCatalogueIds: linkedCatalogueIds ?? this.linkedCatalogueIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      localSites: localSites ?? this.localSites,
    );
  }

  bool get hasResults => sites.isNotEmpty || localSites.isNotEmpty;
  bool get hasError => errorMessage != null;
  bool get hasLocalResults => localSites.isNotEmpty;
  bool get hasExternalResults => sites.isNotEmpty;
}

/// Searches the diver's sites and the built-in catalogue for the import
/// page, and adopts the catalogue sites the diver picks.
class ExternalSiteSearchNotifier
    extends StateNotifier<ExternalSiteSearchState> {
  final SiteCatalogue _catalogue;
  final SiteListNotifier _siteListNotifier;
  final SiteRepository _siteRepository;
  final Ref _ref;

  ExternalSiteSearchNotifier(
    this._catalogue,
    this._siteListNotifier,
    this._siteRepository,
    this._ref,
  ) : super(const ExternalSiteSearchState());

  /// Goes up with every search and every clear. A search that finds a
  /// newer number when it comes back was overtaken, and drops its answer:
  /// the page would otherwise show one search's sites under another's text.
  int _generation = 0;

  /// Search for dive sites by query.
  Future<void> search(String query) async {
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      state = const ExternalSiteSearchState();
      return;
    }

    state = state.copyWith(query: query, isLoading: true, clearError: true);

    try {
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      // Three independent reads, started together so none waits for
      // another. Future.wait observes all three and rethrows the first
      // error as it was thrown (a record's .wait would wrap it in a
      // ParallelWaitError, and the page shows the error's own text).
      final localFuture = _siteRepository.searchSites(
        query,
        diverId: validatedDiverId,
      );
      // Every site of the diver's, not only the matches: a site they
      // adopted and then renamed still marks its catalogue record.
      final ownFuture = _siteRepository.getAllSites(diverId: validatedDiverId);
      // One more than the page lists: the extra one says there are more.
      final matchesFuture = _catalogue.search(query, limit: _searchLimit + 1);
      await Future.wait<Object>([localFuture, ownFuture, matchesFuture]);
      final localResults = await localFuture;
      final ownSites = await ownFuture;
      final matches = await matchesFuture;
      if (generation != _generation) return;

      state = state.copyWith(
        isLoading: false,
        sites: matches.take(_searchLimit).toList(),
        isTruncated: matches.length > _searchLimit,
        linkedCatalogueIds: linkedCatalogueIds(ownSites),
        localSites: localResults,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        // The error as it is: the page shows it under its own translated
        // title, so an English prefix here would only repeat that title.
        errorMessage: '$e',
      );
    }
  }

  /// Runs the search on the page again, if there is one. For when the
  /// catalogue changes under it: an import that lands after the search.
  Future<void> refresh() async {
    if (state.query.trim().isEmpty) return;
    await search(state.query);
  }

  /// Adopts [site] as one of the diver's sites, or finds the one they
  /// already adopted from it. Null on failure, which the page reports in a
  /// snackbar; the state keeps its results, because an error in the state
  /// swaps the whole list for the search error screen.
  Future<CatalogueAdoption?> importSite(CatalogueSite site) async {
    try {
      final adoption = await _siteListNotifier.adoptCatalogueSite(site);
      state = state.copyWith(
        linkedCatalogueIds: {...state.linkedCatalogueIds, site.id},
      );
      return adoption;
    } catch (error, stackTrace) {
      _log.warning(
        'Could not import catalogue site ${site.id}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Clear search results, and drop the answer of a search still out.
  void clear() {
    _generation++;
    state = const ExternalSiteSearchState();
  }
}

/// The import page's search.
// no-tick: a search the page runs on demand; it re-reads the diver's sites
// each time it runs, and runs again when the catalogue is replaced.
final externalSiteSearchProvider =
    StateNotifierProvider<ExternalSiteSearchNotifier, ExternalSiteSearchState>((
      ref,
    ) {
      final notifier = ExternalSiteSearchNotifier(
        ref.watch(siteCatalogueProvider),
        ref.watch(siteListNotifierProvider.notifier),
        ref.watch(siteRepositoryProvider),
        ref,
      );
      // The catalogue is imported after the first frame of an app run. A
      // search made before it landed found nothing: run it again, rather
      // than leave an empty page until the diver searches a second time.
      // Listened to, not watched: watching would rebuild the notifier and
      // drop the page's results.
      ref.listen(siteCatalogueRevisionProvider, (_, _) => notifier.refresh());
      return notifier;
    });
