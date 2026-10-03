import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/services/shared_gear_notes.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';

export 'package:submersion/features/dive_log/data/services/shared_gear_notes.dart'
    show SharedGearNote;

/// The dive being edited, with its unsaved times (issue #2853). [diveId] is
/// null for a new dive; [exit] is null while the dive has no duration.
typedef SharedGearOverlapQuery = ({
  String? diveId,
  String? diverId,
  DateTime entry,
  DateTime? exit,
});

/// Gear on the edited dive's time span that is also on another profile's
/// overlapping dive, keyed by equipment id. Empty with one profile, without
/// a profile, or without an exit time.
final sharedGearOverlapProvider = FutureProvider.autoDispose
    .family<Map<String, SharedGearNote>, SharedGearOverlapQuery>((
      ref,
      query,
    ) async {
      final diverId = query.diverId;
      final exit = query.exit;
      if (!ref.watch(hasMultipleDiversProvider) ||
          diverId == null ||
          exit == null) {
        return const {};
      }
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return sharedGearNotesFor(
        DatabaseService.instance.database,
        diveId: query.diveId,
        diverId: diverId,
        entry: query.entry,
        exit: exit,
      );
    });
