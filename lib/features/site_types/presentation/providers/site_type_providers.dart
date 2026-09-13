import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

final siteTypeRepositoryProvider = Provider<SiteTypeRepository>((ref) {
  return SiteTypeRepository();
});

/// Built-ins plus the current diver's custom types (issue #1765).
final siteTypesProvider = FutureProvider<List<SiteTypeEntity>>((ref) async {
  final repository = ref.watch(siteTypeRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSiteTypesChanges());
  return repository.getAllSiteTypes(diverId: diverId);
});

/// [siteTypesProvider] keyed by id, for resolving stored type ids.
final siteTypesByIdProvider = FutureProvider<Map<String, SiteTypeEntity>>((
  ref,
) async {
  final types = await ref.watch(siteTypesProvider.future);
  return {for (final t in types) t.id: t};
});

/// Every visible type with the number of sites that carry it.
final siteTypeStatisticsProvider = FutureProvider<List<SiteTypeStatistic>>((
  ref,
) async {
  final repository = ref.watch(siteTypeRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSiteTypesChanges());
  return repository.getSiteTypeStatistics(diverId: diverId);
});

/// Mutable list behind the Site Types management page.
class SiteTypeListNotifier
    extends StateNotifier<AsyncValue<List<SiteTypeEntity>>> {
  final SiteTypeRepository _repository;
  final Ref _ref;

  SiteTypeListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    logFailure(_load(), SiteTypeListNotifier, 'load');
    final sub = _repository.watchSiteTypesChanges().listen(
      (_) => logFailure(_load(), SiteTypeListNotifier, 'reload'),
    );
    _ref.onDispose(sub.cancel);
  }

  Future<void> _load() async {
    try {
      final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
      final types = await _repository.getAllSiteTypes(diverId: diverId);
      if (mounted) state = AsyncValue.data(types);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _invalidate() {
    _ref.invalidate(siteTypesProvider);
    _ref.invalidate(siteTypeStatisticsProvider);
  }

  Future<SiteTypeEntity> addSiteTypeByName(String name) async {
    final diverId = await _ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) {
      throw Exception('Cannot create a custom site type without a diver');
    }
    final created = await _repository.createSiteType(
      SiteTypeEntity.create(
        id: SiteTypeEntity.generateSlug(name),
        name: name.trim(),
        diverId: diverId,
      ),
    );
    await _load();
    _invalidate();
    return created;
  }

  Future<void> updateSiteType(SiteTypeEntity type) async {
    await _repository.updateSiteType(type);
    await _load();
    _invalidate();
  }

  Future<void> deleteSiteType(String id) async {
    await _repository.deleteSiteType(id);
    await _load();
    _invalidate();
  }
}

final siteTypeListNotifierProvider =
    StateNotifierProvider.autoDispose<
      SiteTypeListNotifier,
      AsyncValue<List<SiteTypeEntity>>
    >((ref) {
      final repository = ref.watch(siteTypeRepositoryProvider);
      // Rebuild the notifier (and its list) when the active diver changes.
      ref.watch(currentDiverIdProvider);
      return SiteTypeListNotifier(repository, ref);
    });
