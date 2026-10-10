import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_state_store.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final qualityFindingsRepositoryProvider = Provider<QualityFindingsRepository>(
  (ref) => QualityFindingsRepository(),
);

final qualityScanServiceProvider = Provider<QualityScanService>(
  (ref) => QualityScanService(),
);

/// Drives the Dives app-bar badge; live under sync because findings are
/// ordinary synced rows. autoDispose so the Drift stream subscription is
/// cancelled when no widget is watching (also drains its pending timer in
/// widget tests). Scoped to the active diver: another profile's findings
/// must not badge this one (issue #3049).
final openQualityFindingsCountProvider = StreamProvider.autoDispose<int>((
  ref,
) async* {
  final repository = ref.watch(qualityFindingsRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  yield* repository.watchOpenCount(diverId: diverId);
});

final qualityScanStateStoreProvider = Provider<QualityScanStateStore>(
  (ref) => QualityScanStateStore(ref.watch(sharedPreferencesProvider)),
);
