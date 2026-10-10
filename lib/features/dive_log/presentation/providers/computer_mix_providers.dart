import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_computer/data/services/computer_mix_reader.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Reads a tank's computer-recorded mix from the stored download bytes
/// (issue #3021), through the native parser.
final computerMixReaderProvider = Provider<ComputerMixReader>(
  (ref) => ComputerMixReader(
    db: DatabaseService.instance.database,
    parseFn: pigeon.DiveComputerHostApi().parseRawDiveData,
  ),
);

/// What identifies one tank's computer reading: the row's computer-owned
/// fields, never its mix, so typing in the O2 field does not parse again.
typedef ComputerMixKey = ({
  String diveId,
  String tankId,
  String? computerId,
  String? sourceId,
  int? sourceTankIndex,
  int order,
});

ComputerMixKey computerMixKeyFor(String diveId, DiveTank tank) => (
  diveId: diveId,
  tankId: tank.id,
  computerId: tank.computerId,
  sourceId: tank.sourceId,
  sourceTankIndex: tank.sourceTankIndex,
  order: tank.order,
);

/// The mix [ComputerMixKey]'s computer recorded, or null when it cannot be
/// known (see [ComputerMixReader.recordedMix]).
final recordedComputerMixProvider = FutureProvider.autoDispose
    .family<GasMix?, ComputerMixKey>(
      (ref, key) => ref
          .watch(computerMixReaderProvider)
          .recordedMix(
            diveId: key.diveId,
            tank: DiveTank(
              id: key.tankId,
              computerId: key.computerId,
              sourceId: key.sourceId,
              sourceTankIndex: key.sourceTankIndex,
              order: key.order,
            ),
          ),
    );
