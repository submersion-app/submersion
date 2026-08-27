import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// Provider for the dive repository.
///
/// Lives in its own dependency-only module (no feature-presentation imports)
/// so other feature providers can subscribe to dive-table change ticks via
/// `diveRepositoryProvider` without importing the full `dive_providers.dart`
/// — which imports those same feature providers and would create cross-feature
/// import cycles. `dive_providers.dart` re-exports this so existing
/// `diveRepositoryProvider` consumers are unaffected.
final diveRepositoryProvider = Provider<DiveRepository>((ref) {
  return DiveRepository();
});
