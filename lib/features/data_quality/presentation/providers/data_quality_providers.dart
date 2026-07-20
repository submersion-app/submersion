import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_state_store.dart';

final qualityFindingsRepositoryProvider = Provider<QualityFindingsRepository>(
  (ref) => QualityFindingsRepository(),
);

final qualityScanServiceProvider = Provider<QualityScanService>(
  (ref) => QualityScanService(),
);

/// Drives the Dives app-bar badge; live under sync because findings are
/// ordinary synced rows. autoDispose so the Drift stream subscription is
/// cancelled when no widget is watching (also drains its pending timer in
/// widget tests).
final openQualityFindingsCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(qualityFindingsRepositoryProvider).watchOpenCount(),
);

final qualityScanStateStoreProvider = Provider<QualityScanStateStore>(
  (ref) => QualityScanStateStore(ref.watch(sharedPreferencesProvider)),
);
