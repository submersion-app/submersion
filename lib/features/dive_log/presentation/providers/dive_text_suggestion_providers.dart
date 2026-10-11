import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The active diver's earlier values for one free-text dive field, most
/// recent first (#3229). Refreshes whenever the dives table is written, so a
/// boat logged on another device appears after sync.
///
/// Scoped by the validated diver id: the raw id can be null before the stored
/// selection resolves, and a null id would drop the diver filter and offer
/// every diver's values.
final diveTextSuggestionsProvider =
    FutureProvider.family<List<String>, DiveTextSuggestionField>((
      ref,
      field,
    ) async {
      final repository = ref.watch(diveRepositoryProvider);
      // Subscribe before the first await so no write can slip past.
      ref.invalidateSelfWhen(repository.watchDivesChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repository.getRecentTextValues(field, diverId: diverId);
    });
