import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart'
    as domain;
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart'
    as domain;

final preDiveTemplateRepositoryProvider = Provider<PreDiveTemplateRepository>(
  (ref) => PreDiveTemplateRepository(),
);

final preDiveSessionRepositoryProvider = Provider<PreDiveSessionRepository>(
  (ref) => PreDiveSessionRepository(),
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

final preDiveActiveSessionProvider = FutureProvider<domain.PreDiveSession?>((
  ref,
) async {
  final repository = ref.watch(preDiveSessionRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchSessionsChanges());
  return repository.getActiveSession(diverId: diverId);
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
