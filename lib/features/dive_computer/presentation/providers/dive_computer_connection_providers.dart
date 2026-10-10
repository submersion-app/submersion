import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

/// The connections each dive computer has reached the library by (issue
/// #3106).
final diveComputerConnectionRepositoryProvider =
    Provider<DiveComputerConnectionRepository>(
      (ref) => DiveComputerConnectionRepository(),
    );

/// One computer's connections, the most recently used first.
final diveComputerConnectionsProvider =
    FutureProvider.family<List<DiveComputerConnection>, String>((
      ref,
      computerId,
    ) async {
      final repository = ref.watch(diveComputerConnectionRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.forComputer(computerId);
    });

/// The connections of every computer the current diver can see, keyed by
/// computer id, each list the most recently used first. A computer with no
/// connection yet is absent.
final allDiveComputerConnectionsProvider =
    FutureProvider<Map<String, List<DiveComputerConnection>>>((ref) async {
      final repository = ref.watch(diveComputerConnectionRepositoryProvider);
      final computers = await ref.watch(allDiveComputersProvider.future);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.forComputers(computers.map((c) => c.id));
    });
