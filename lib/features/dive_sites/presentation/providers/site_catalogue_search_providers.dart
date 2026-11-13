import 'package:submersion/core/providers/provider.dart';
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

  /// The catalogue records the diver's sites were adopted from.
  final Set<String> linkedCatalogueIds;
  final String? errorMessage;
  final List<domain.DiveSite> localSites;

  const ExternalSiteSearchState({
    this.query = '',
    this.isLoading = false,
    this.sites = const [],
    this.linkedCatalogueIds = const {},
    this.errorMessage,
    this.localSites = const [],
  });

  ExternalSiteSearchState copyWith({
    String? query,
    bool? isLoading,
    List<CatalogueSite>? sites,
    Set<String>? linkedCatalogueIds,
    String? errorMessage,
    bool clearError = false,
    List<domain.DiveSite>? localSites,
  }) {
    return ExternalSiteSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      sites: sites ?? this.sites,
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

  /// Search for dive sites by query.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const ExternalSiteSearchState();
      return;
    }

    state = state.copyWith(query: query, isLoading: true, clearError: true);

    try {
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final localResults = await _siteRepository.searchSites(
        query,
        diverId: validatedDiverId,
      );
      // Every site of the diver's, not only the matches: a site they
      // adopted and then renamed still marks its catalogue record.
      final ownSites = await _siteRepository.getAllSites(
        diverId: validatedDiverId,
      );
      final matches = await _catalogue.search(query, limit: _searchLimit);

      state = state.copyWith(
        isLoading: false,
        sites: matches,
        linkedCatalogueIds: linkedCatalogueIds(ownSites),
        localSites: localResults,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search error: $e',
      );
    }
  }

  /// The quick-search chips: a search for a country or region name.
  Future<void> searchByCountry(String country) => search(country);

  /// Adopts [site] as one of the diver's sites, or finds the one they
  /// already adopted from it. Null, with an error in the state, on failure.
  Future<CatalogueAdoption?> importSite(CatalogueSite site) async {
    try {
      final adoption = await _siteListNotifier.adoptCatalogueSite(site);
      state = state.copyWith(
        linkedCatalogueIds: {...state.linkedCatalogueIds, site.id},
      );
      return adoption;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to import site: $e');
      return null;
    }
  }

  /// Clear search results.
  void clear() {
    state = const ExternalSiteSearchState();
  }
}

/// The import page's search.
// no-tick: a search the page runs on demand; it re-reads the diver's sites
// each time it runs.
final externalSiteSearchProvider =
    StateNotifierProvider<ExternalSiteSearchNotifier, ExternalSiteSearchState>((
      ref,
    ) {
      return ExternalSiteSearchNotifier(
        ref.watch(siteCatalogueProvider),
        ref.watch(siteListNotifierProvider.notifier),
        ref.watch(siteRepositoryProvider),
        ref,
      );
    });
