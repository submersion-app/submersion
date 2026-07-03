import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Repository singletons
final checklistTemplateRepositoryProvider =
    Provider<ChecklistTemplateRepository>(
      (ref) => ChecklistTemplateRepository(),
    );

final tripChecklistRepositoryProvider = Provider<TripChecklistRepository>(
  (ref) => TripChecklistRepository(),
);

/// All checklist templates for the active diver.
final checklistTemplatesProvider =
    FutureProvider<List<domain.ChecklistTemplate>>((ref) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getAllTemplates(diverId: diverId);
    });

/// Single template by id.
final checklistTemplateProvider =
    FutureProvider.family<domain.ChecklistTemplate?, String>((ref, id) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getTemplateById(id);
    });

/// Items of a template, ordered by sortOrder.
final checklistTemplateItemsProvider =
    FutureProvider.family<List<domain.ChecklistTemplateItem>, String>((
      ref,
      templateId,
    ) async {
      final repository = ref.watch(checklistTemplateRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTemplatesChanges());
      return repository.getItemsForTemplate(templateId);
    });

/// A trip's checklist items, ordered by sortOrder. Self-invalidates on
/// table changes so sync-applied edits render live.
final tripChecklistProvider =
    FutureProvider.family<List<domain.TripChecklistItem>, String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());
      return repository.getByTripId(tripId);
    });

/// Done/total progress for a trip's checklist.
final tripChecklistProgressProvider =
    FutureProvider.family<({int done, int total}), String>((ref, tripId) async {
      final repository = ref.watch(tripChecklistRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripChecklistChanges());
      return repository.getProgress(tripId);
    });
