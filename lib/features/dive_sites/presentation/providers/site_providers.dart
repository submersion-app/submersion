import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;

// ============================================================================
// Site Filter State
// ============================================================================

/// Immutable filter state for dive sites.
///
/// All filters use AND logic - a site must match ALL active filters.
/// Uses "clear" flags in copyWith to allow granular filter clearing.
class SiteFilterState {
  final String? country;
  final String? region;
  final domain.SiteDifficulty? difficulty;
  final double? minDepth;
  final double? maxDepth;
  final double? minRating;
  final bool? hasCoordinates;
  final bool? hasDives;

  const SiteFilterState({
    this.country,
    this.region,
    this.difficulty,
    this.minDepth,
    this.maxDepth,
    this.minRating,
    this.hasCoordinates,
    this.hasDives,
  });

  /// Whether any filter is currently active.
  bool get hasActiveFilters =>
      country != null ||
      region != null ||
      difficulty != null ||
      minDepth != null ||
      maxDepth != null ||
      minRating != null ||
      hasCoordinates != null ||
      hasDives != null;

  /// Apply all active filters to a list of sites with dive counts.
  List<SiteWithDiveCount> apply(List<SiteWithDiveCount> sites) {
    return sites.where((siteWithCount) {
      final site = siteWithCount.site;
      final diveCount = siteWithCount.diveCount;

      // Country filter (case-insensitive contains)
      if (country != null && country!.isNotEmpty) {
        if (site.country == null ||
            !site.country!.toLowerCase().contains(country!.toLowerCase())) {
          return false;
        }
      }

      // Region filter (case-insensitive contains)
      if (region != null && region!.isNotEmpty) {
        if (site.region == null ||
            !site.region!.toLowerCase().contains(region!.toLowerCase())) {
          return false;
        }
      }

      // Difficulty filter
      if (difficulty != null) {
        if (site.difficulty != difficulty) {
          return false;
        }
      }

      // Depth range filter
      if (minDepth != null) {
        if (site.maxDepth == null || site.maxDepth! < minDepth!) {
          return false;
        }
      }
      if (maxDepth != null) {
        if (site.maxDepth == null || site.maxDepth! > maxDepth!) {
          return false;
        }
      }

      // Minimum rating filter
      if (minRating != null) {
        if (site.rating == null || site.rating! < minRating!) {
          return false;
        }
      }

      // Has coordinates filter
      if (hasCoordinates != null) {
        if (site.hasCoordinates != hasCoordinates) {
          return false;
        }
      }

      // Has dives filter
      if (hasDives != null) {
        final siteHasDives = diveCount > 0;
        if (siteHasDives != hasDives) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  SiteFilterState copyWith({
    String? country,
    String? region,
    domain.SiteDifficulty? difficulty,
    double? minDepth,
    double? maxDepth,
    double? minRating,
    bool? hasCoordinates,
    bool? hasDives,
    // Clear flags
    bool clearCountry = false,
    bool clearRegion = false,
    bool clearDifficulty = false,
    bool clearMinDepth = false,
    bool clearMaxDepth = false,
    bool clearMinRating = false,
    bool clearHasCoordinates = false,
    bool clearHasDives = false,
  }) {
    return SiteFilterState(
      country: clearCountry ? null : (country ?? this.country),
      region: clearRegion ? null : (region ?? this.region),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      minDepth: clearMinDepth ? null : (minDepth ?? this.minDepth),
      maxDepth: clearMaxDepth ? null : (maxDepth ?? this.maxDepth),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      hasCoordinates: clearHasCoordinates
          ? null
          : (hasCoordinates ?? this.hasCoordinates),
      hasDives: clearHasDives ? null : (hasDives ?? this.hasDives),
    );
  }
}

/// Site filter provider
final siteFilterProvider = StateProvider<SiteFilterState>(
  (ref) => const SiteFilterState(),
);

// ============================================================================
// Repository and Data Providers
// ============================================================================

/// Repository provider
final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return SiteRepository();
});

/// All sites provider
final sitesProvider = FutureProvider<List<domain.DiveSite>>((ref) async {
  final repository = ref.watch(siteRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllSites(diverId: validatedDiverId);
});

/// Sites with dive counts provider
final sitesWithCountsProvider = FutureProvider<List<SiteWithDiveCount>>((
  ref,
) async {
  final repository = ref.watch(siteRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getSitesWithDiveCounts(diverId: validatedDiverId);
});

/// Site sort state provider
final siteSortProvider = StateProvider<SortState<SiteSortField>>(
  (ref) => const SortState(
    field: SiteSortField.name,
    direction: SortDirection.descending,
  ),
);

/// Filtered sites with counts provider
/// Applies active filters to the full site list.
final filteredSitesWithCountsProvider =
    Provider<AsyncValue<List<SiteWithDiveCount>>>((ref) {
      final sitesAsync = ref.watch(sitesWithCountsProvider);
      final filter = ref.watch(siteFilterProvider);

      return sitesAsync.whenData((sites) => filter.apply(sites));
    });

/// Sorted and filtered sites with counts provider
/// First filters, then sorts the results.
final sortedSitesWithCountsProvider =
    Provider<AsyncValue<List<SiteWithDiveCount>>>((ref) {
      final sitesAsync = ref.watch(filteredSitesWithCountsProvider);
      final sort = ref.watch(siteSortProvider);

      return sitesAsync.whenData((sites) => _applySiteSorting(sites, sort));
    });

/// Apply sorting to a list of sites
List<SiteWithDiveCount> _applySiteSorting(
  List<SiteWithDiveCount> sites,
  SortState<SiteSortField> sort,
) {
  final sorted = List<SiteWithDiveCount>.from(sites);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText = sort.field == SiteSortField.name;

    switch (sort.field) {
      case SiteSortField.name:
        comparison = a.site.name.compareTo(b.site.name);
      case SiteSortField.rating:
        comparison = (a.site.rating ?? 0).compareTo(b.site.rating ?? 0);
      case SiteSortField.difficulty:
        comparison = (a.site.difficulty?.index ?? 0).compareTo(
          b.site.difficulty?.index ?? 0,
        );
      case SiteSortField.depth:
        comparison = (a.site.maxDepth ?? 0).compareTo(b.site.maxDepth ?? 0);
      case SiteSortField.diveCount:
        comparison = a.diveCount.compareTo(b.diveCount);
    }

    if (invertForText) {
      return sort.direction == SortDirection.ascending
          ? -comparison
          : comparison;
    }
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}

/// Single site provider
final siteProvider = FutureProvider.family<domain.DiveSite?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(siteRepositoryProvider);
  return repository.getSiteById(id);
});

/// Site search provider
final siteSearchProvider = FutureProvider.family<List<domain.DiveSite>, String>(
  (ref, query) async {
    final validatedDiverId = await ref.watch(
      validatedCurrentDiverIdProvider.future,
    );
    if (query.isEmpty) {
      return ref.watch(sitesProvider).value ?? [];
    }
    final repository = ref.watch(siteRepositoryProvider);
    return repository.searchSites(query, diverId: validatedDiverId);
  },
);

/// Dive count for a specific site
final siteDiveCountProvider = FutureProvider.family<int, String>((
  ref,
  siteId,
) async {
  final sitesWithCounts = await ref.watch(sitesWithCountsProvider.future);
  final siteWithCount = sitesWithCounts
      .where((s) => s.site.id == siteId)
      .firstOrNull;
  return siteWithCount?.diveCount ?? 0;
});

/// Site list notifier for mutations
class SiteListNotifier
    extends StateNotifier<AsyncValue<List<domain.DiveSite>>> {
  final SiteRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  SiteListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(sitesProvider);
        _ref.invalidate(sitesWithCountsProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadSites();
  }

  Future<void> _loadSites() async {
    state = const AsyncValue.loading();
    try {
      final sites = await _repository.getAllSites(diverId: _validatedDiverId);
      state = AsyncValue.data(sites);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadSites();
    _ref.invalidate(sitesProvider);
    _ref.invalidate(sitesWithCountsProvider);
  }

  Future<domain.DiveSite> addSite(domain.DiveSite site) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final siteWithDiver = validatedId != null
        ? site.copyWith(diverId: validatedId)
        : site;
    final newSite = await _repository.createSite(siteWithDiver);
    await _loadSites();
    return newSite;
  }

  Future<void> updateSite(domain.DiveSite site) async {
    await _repository.updateSite(site);
    await _loadSites();
  }

  Future<void> deleteSite(String id) async {
    await _repository.deleteSite(id);
    await _loadSites();
  }

  /// Bulk delete multiple sites
  /// Returns the deleted sites for potential undo
  Future<List<domain.DiveSite>> bulkDeleteSites(List<String> ids) async {
    // Get the sites before deleting for undo capability
    final sitesToDelete = await _repository.getSitesByIds(ids);
    await _repository.bulkDeleteSites(ids);
    await _loadSites();
    _ref.invalidate(sitesProvider);
    _ref.invalidate(sitesWithCountsProvider);
    return sitesToDelete;
  }

  /// Restore multiple sites (for undo functionality)
  Future<void> restoreSites(List<domain.DiveSite> sites) async {
    for (final site in sites) {
      await _repository.createSite(site);
    }
    await _loadSites();
    _ref.invalidate(sitesProvider);
    _ref.invalidate(sitesWithCountsProvider);
  }
}

final siteListNotifierProvider =
    StateNotifierProvider<SiteListNotifier, AsyncValue<List<domain.DiveSite>>>((
      ref,
    ) {
      final repository = ref.watch(siteRepositoryProvider);
      return SiteListNotifier(repository, ref);
    });

// ============================================================================
// External Dive Site API Providers
// ============================================================================

/// Provider for the dive site API service.
final diveSiteApiServiceProvider = Provider<DiveSiteApiService>((ref) {
  return DiveSiteApiService();
});

/// State for external dive site search.
class ExternalSiteSearchState {
  final String query;
  final bool isLoading;
  final DiveSiteSearchResult? result;
  final String? errorMessage;
  final List<domain.DiveSite> localSites;

  const ExternalSiteSearchState({
    this.query = '',
    this.isLoading = false,
    this.result,
    this.errorMessage,
    this.localSites = const [],
  });

  ExternalSiteSearchState copyWith({
    String? query,
    bool? isLoading,
    DiveSiteSearchResult? result,
    String? errorMessage,
    bool clearError = false,
    List<domain.DiveSite>? localSites,
  }) {
    return ExternalSiteSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      localSites: localSites ?? this.localSites,
    );
  }

  List<ExternalDiveSite> get sites => result?.sites ?? [];
  bool get hasResults => sites.isNotEmpty || localSites.isNotEmpty;
  bool get hasError => errorMessage != null;
  bool get hasLocalResults => localSites.isNotEmpty;
  bool get hasExternalResults => sites.isNotEmpty;
}

/// Notifier for searching external dive site APIs.
class ExternalSiteSearchNotifier
    extends StateNotifier<ExternalSiteSearchState> {
  final DiveSiteApiService _apiService;
  final SiteListNotifier _siteListNotifier;
  final SiteRepository _siteRepository;
  final Ref _ref;

  ExternalSiteSearchNotifier(
    this._apiService,
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
      // Search local database first
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final localResults = await _siteRepository.searchSites(
        query,
        diverId: validatedDiverId,
      );

      // Search external sources (API/bundled)
      final result = await _apiService.searchSites(query);

      if (result.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          result: result,
          localSites: localResults,
        );
      } else {
        // Even if external search fails, show local results
        state = state.copyWith(
          isLoading: false,
          result: result,
          localSites: localResults,
          errorMessage: localResults.isEmpty
              ? (result.errorMessage ?? 'Search failed')
              : null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search error: $e',
      );
    }
  }

  /// Search for dive sites by country.
  Future<void> searchByCountry(String country) async {
    state = state.copyWith(query: country, isLoading: true, clearError: true);

    try {
      // Search local database first
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final localResults = await _siteRepository.searchSites(
        country,
        diverId: validatedDiverId,
      );

      final result = await _apiService.searchByCountry(country);

      if (result.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          result: result,
          localSites: localResults,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          result: result,
          localSites: localResults,
          errorMessage: localResults.isEmpty
              ? (result.errorMessage ?? 'Search failed')
              : null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search error: $e',
      );
    }
  }

  /// Import an external dive site into the local database.
  Future<domain.DiveSite?> importSite(ExternalDiveSite externalSite) async {
    try {
      // Get the validated diver ID
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );

      // Convert to local dive site
      final site = externalSite.toDiveSite(diverId: validatedDiverId);

      // Save to database
      final savedSite = await _siteListNotifier.addSite(site);

      return savedSite;
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

/// Provider for external site search.
final externalSiteSearchProvider =
    StateNotifierProvider<ExternalSiteSearchNotifier, ExternalSiteSearchState>((
      ref,
    ) {
      final apiService = ref.watch(diveSiteApiServiceProvider);
      final siteListNotifier = ref.watch(siteListNotifierProvider.notifier);
      final siteRepository = ref.watch(siteRepositoryProvider);
      return ExternalSiteSearchNotifier(
        apiService,
        siteListNotifier,
        siteRepository,
        ref,
      );
    });
