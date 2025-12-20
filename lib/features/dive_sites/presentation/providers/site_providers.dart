import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/site_repository_impl.dart';
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
  return repository.getSitesWithDiveCounts();
});

/// Single site provider
final siteProvider = FutureProvider.family<domain.DiveSite?, String>((ref, id) async {
  final repository = ref.watch(siteRepositoryProvider);
  return repository.getSiteById(id);
});

/// Site search provider
final siteSearchProvider = FutureProvider.family<List<domain.DiveSite>, String>((ref, query) async {
  if (query.isEmpty) {
    return ref.watch(sitesProvider).value ?? [];
  }
  final repository = ref.watch(siteRepositoryProvider);
  return repository.searchSites(query);
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
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
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
    await _loadSites();
    _ref.invalidate(sitesProvider);
    _ref.invalidate(sitesWithCountsProvider);
  }

  Future<domain.DiveSite> addSite(domain.DiveSite site) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new sites
    final siteWithDiver = site.diverId == null && validatedId != null
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
}

final siteListNotifierProvider =
    StateNotifierProvider<SiteListNotifier, AsyncValue<List<domain.DiveSite>>>((ref) {
  final repository = ref.watch(siteRepositoryProvider);
  return SiteListNotifier(repository, ref);
});
