import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/excel/pre_dive_excel_export_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/models/pre_dive_session_filter.dart';

final preDiveTemplateRepositoryProvider = Provider<PreDiveTemplateRepository>(
  (ref) => PreDiveTemplateRepository(),
);

final preDiveSessionRepositoryProvider = Provider<PreDiveSessionRepository>(
  (ref) => PreDiveSessionRepository(),
);

/// Injected rather than constructed at the call site so a test can observe
/// what the checklist export was actually handed.
final preDiveExcelExportServiceProvider = Provider<PreDiveExcelExportService>(
  (ref) => PreDiveExcelExportService(),
);

final preDiveTemplatesProvider =
    FutureProvider<List<domain.PreDiveChecklistTemplate>>((ref) async {
      final repository = ref.watch(preDiveTemplateRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getAllTemplates(diverId: diverId);
    });

final preDiveTemplateProvider =
    FutureProvider.family<domain.PreDiveChecklistTemplate?, String>((
      ref,
      templateId,
    ) async {
      final repository = ref.watch(preDiveTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getTemplateById(templateId);
    });

final preDiveTemplateItemsProvider =
    FutureProvider.family<List<domain.PreDiveChecklistTemplateItem>, String>((
      ref,
      templateId,
    ) async {
      final repository = ref.watch(preDiveTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getItemsForTemplate(templateId);
    });

final preDiveSessionsProvider = FutureProvider<List<domain.PreDiveSession>>((
  ref,
) async {
  final repository = ref.watch(preDiveSessionRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSessionsChanges());
  return repository.getAllSessions(diverId: diverId);
});

/// Item tallies for every session, keyed by session id. One aggregate query
/// serves the whole list, so a session row never fetches its own items just to
/// show progress or a flag badge.
final preDiveSessionStatsProvider =
    FutureProvider<Map<String, domain.PreDiveSessionStats>>((ref) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getSessionStats(diverId: diverId);
    });

final preDiveActiveSessionProvider = FutureProvider<domain.PreDiveSession?>((
  ref,
) async {
  final repository = ref.watch(preDiveSessionRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSessionsChanges());
  return repository.getActiveSession(diverId: diverId);
});

/// Facets narrowing the session history. Ephemeral by design, matching the
/// dive-list and trip-list filters: a filter is a view of the current screen,
/// not a stored preference.
final preDiveSessionFilterProvider = StateProvider<PreDiveSessionFilter>(
  (ref) => const PreDiveSessionFilter(),
);

/// Sessions surviving the active filter, newest first.
final filteredPreDiveSessionsProvider =
    Provider<AsyncValue<List<domain.PreDiveSession>>>((ref) {
      final sessionsAsync = ref.watch(preDiveSessionsProvider);
      final filter = ref.watch(preDiveSessionFilterProvider);
      final stats =
          ref.watch(preDiveSessionStatsProvider).value ??
          const <String, domain.PreDiveSessionStats>{};
      return sessionsAsync.whenData(
        (sessions) => filter.apply(sessions, stats),
      );
    });

/// Distinct checklist names present in the history, sorted, for the filter
/// picker. Names come from the sessions themselves so runs of a since-deleted
/// template remain selectable.
final preDiveSessionTemplateNamesProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(preDiveSessionsProvider).value ?? const [];
  final names = {for (final session in sessions) session.templateName};
  return names.toList()..sort();
});

final preDiveSessionProvider =
    FutureProvider.family<domain.PreDiveSession?, String>((
      ref,
      sessionId,
    ) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getSessionById(sessionId);
    });

final preDiveSessionItemsProvider =
    FutureProvider.family<List<domain.PreDiveSessionItem>, String>((
      ref,
      sessionId,
    ) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getItemsForSession(sessionId);
    });

final preDiveSessionForDiveProvider =
    FutureProvider.family<domain.PreDiveSession?, String>((ref, diveId) async {
      final repository = ref.watch(preDiveSessionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSessionsChanges());
      return repository.getSessionForDive(diveId);
    });
