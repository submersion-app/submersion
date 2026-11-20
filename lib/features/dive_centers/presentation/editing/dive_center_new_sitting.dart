import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

const _log = LoggerService('DiveCenterNewSitting');

/// A new dive centre's sitting (issue #4527, phase 3, plan 11): its seed
/// and the cards laid out open.

/// A new dive centre's starting record under [id]: the active diver's,
/// with no name, as the form starts one. A diver that cannot be read
/// leaves none, for Save to take the one active then.
Future<DiveCenter> newDiveCenterSeed(
  RecordSeedRead read, {
  required String id,
}) async {
  String? diverId;
  try {
    diverId = await read(validatedCurrentDiverIdProvider.future);
  } catch (error, stackTrace) {
    _log.warning(
      'Could not read the diver for a new dive centre',
      error: error,
      stackTrace: stackTrace,
    );
  }
  final now = DateTime.now();
  return DiveCenter(
    id: id,
    diverId: diverId,
    name: '',
    createdAt: now,
    updatedAt: now,
  );
}

/// The cards a new dive centre opens with: the header block, Contact and
/// the Map.
final List<String> newDiveCenterLaidOut = List.unmodifiable([
  DiveCenterCardId.header.name,
  DiveCenterCardId.contact.name,
  DiveCenterCardId.map.name,
]);
