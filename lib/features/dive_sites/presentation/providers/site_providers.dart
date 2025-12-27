import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/site_repository_impl.dart';
import '../../data/services/dive_site_api_service.dart';
import '../../domain/entities/dive_site.dart' as domain;

/// Repository provider
final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return SiteRepository();
});

/// All sites provider
final sitesProvider = FutureProvider<List<domain.DiveSite>>((ref) async {
  final repository = ref.watch(siteRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllSites(diverId: validatedDiverId);
});

/// Sites with dive counts provider
final sitesWithCountsProvider = FutureProvider<List<SiteWithDiveCount>>((ref) async {
  final repository = ref.watch(siteRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getSitesWithDiveCounts(diverId: validatedDiverId);
});

/// Single site provider
final siteProvider = FutureProvider.family<domain.DiveSite?, String>((ref, id) async {
  final repository = ref.watch(siteRepositoryProvider);
  return repository.getSiteById(id);
});

/// Site search provider
final siteSearchProvider = FutureProvider.family<List<domain.DiveSite>, String>((ref, query) async {
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (query.isEmpty) {
    return ref.watch(sitesProvider).value ?? [];
  }
  final repository = ref.watch(siteRepositoryProvider);
  return repository.searchSites(query, diverId: validatedDiverId);
});

/// Dive count for a specific site
final siteDiveCountProvider = FutureProvider.family<int, String>((ref, siteId) async {
  final sitesWithCounts = await ref.watch(sitesWithCountsProvider.future);
  final siteWithCount = sitesWithCounts.where((s) => s.site.id == siteId).firstOrNull;
  return siteWithCount?.diveCount ?? 0;
});

/// Site list notifier for mutations
class SiteListNotifier extends StateNotifier<AsyncValue<List<domain.DiveSite>>> {
  final SiteRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  SiteListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
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
    StateNotifierProvider<SiteListNotifier, AsyncValue<List<domain.DiveSite>>>((ref) {
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

  const ExternalSiteSearchState({
    this.query = '',
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  ExternalSiteSearchState copyWith({
    String? query,
    bool? isLoading,
    DiveSiteSearchResult? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExternalSiteSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<ExternalDiveSite> get sites => result?.sites ?? [];
  bool get hasResults => sites.isNotEmpty;
  bool get hasError => errorMessage != null;
}

/// Notifier for searching external dive site APIs.
class ExternalSiteSearchNotifier extends StateNotifier<ExternalSiteSearchState> {
  final DiveSiteApiService _apiService;
  final SiteListNotifier _siteListNotifier;
  final Ref _ref;

  ExternalSiteSearchNotifier(
    this._apiService,
    this._siteListNotifier,
    this._ref,
  ) : super(const ExternalSiteSearchState());

  /// Search for dive sites by query.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const ExternalSiteSearchState();
      return;
    }

    state = state.copyWith(
      query: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _apiService.searchSites(query);

      if (result.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          result: result,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.errorMessage ?? 'Search failed',
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
    state = state.copyWith(
      query: country,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await _apiService.searchByCountry(country);

      if (result.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          result: result,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.errorMessage ?? 'Search failed',
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
      final validatedDiverId =
          await _ref.read(validatedCurrentDiverIdProvider.future);

      // Convert to local dive site
      final site = externalSite.toDiveSite(diverId: validatedDiverId);

      // Save to database
      final savedSite = await _siteListNotifier.addSite(site);

      return savedSite;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to import site: $e',
      );
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
    StateNotifierProvider<ExternalSiteSearchNotifier, ExternalSiteSearchState>(
  (ref) {
    final apiService = ref.watch(diveSiteApiServiceProvider);
    final siteListNotifier = ref.watch(siteListNotifierProvider.notifier);
    return ExternalSiteSearchNotifier(apiService, siteListNotifier, ref);
  },
);
