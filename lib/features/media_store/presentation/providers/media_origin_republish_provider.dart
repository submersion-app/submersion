import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/data/media_origin_republish_sweep.dart';

/// Runs [MediaOriginRepublishSweep] once per device, at launch.
///
/// Checks the done flag before reading the resolver registry: building the
/// registry constructs every resolver in the app, which is fine on the one
/// launch that repairs and waste on every launch after.
///
/// Contains its own failures: the call site is fire-and-forget, so an
/// escaping throw would land in the zone handler with nothing to catch it
/// (the shape of #942). A failure leaves the flag unset and the next launch
/// tries again.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final mediaOriginRepublishProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (MediaOriginRepublishSweep.isDone(prefs)) return;
      final repository = ref.read(mediaRepositoryProvider);
      await MediaOriginRepublishSweep(
        mediaRepository: repository,
        verifier: MediaItemVerifier(
          registry: ref.read(mediaSourceResolverRegistryProvider),
          repository: repository,
        ),
        deviceId: () => SyncRepository().getDeviceId(),
        prefs: prefs,
      ).run();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(MediaOriginRepublishSweep).warning(
        'Could not run the origin republish',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});
