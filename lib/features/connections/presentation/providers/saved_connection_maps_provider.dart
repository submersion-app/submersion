import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final connectionMapRepositoryProvider = Provider<ConnectionMapRepository>(
  (ref) => ConnectionMapRepository(),
);

/// The current diver's saved maps, sorted for the preset grid.
final savedConnectionMapsProvider =
    FutureProvider.autoDispose<List<SavedConnectionMap>>((ref) async {
      final repository = ref.watch(connectionMapRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConnectionMapsChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      return repository.getAll(diverId);
    });
