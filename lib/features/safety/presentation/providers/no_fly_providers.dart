import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Active flying-after-diving restriction for the current diver, or null.
///
/// Self-invalidates on dive-table writes (import, sync, edit). The countdown
/// display refreshes in the UI layer; this provider anchors the deadline.
final noFlyStatusProvider = FutureProvider<NoFlyStatus?>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());

  final diverId = ref.watch(currentDiverIdProvider);
  final preset = ref.watch(settingsProvider.select((s) => s.noFlyPreset));

  final now = DateTime.now().toUtc();
  final dives = await repository.getNoFlyDiveInputs(
    since: now.subtract(NoFlyService.lookback),
    diverId: diverId,
  );
  return const NoFlyService().evaluate(dives: dives, preset: preset, now: now);
});
