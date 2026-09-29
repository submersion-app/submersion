import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

const _log = LoggerService('importTagFill');

/// Adds the fill an own cylinder's [tag] carries to its history, once (spec
/// section 11). Every tag the app opens goes through here. Never throws: the
/// fill is an extra, so a failure is logged and whatever opened the tag
/// carries on. Resolves with the fill it added, or null.
Future<CylinderFill?> importTagFill(
  WidgetRef ref, {
  required CylinderPassportPayload tag,
  required String equipmentId,
}) async {
  if (tag.fill == null) return null;
  try {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    return await ref
        .read(tagFillImporterProvider)
        .importIfNew(tag: tag, equipmentId: equipmentId, diverId: diverId);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to import the fill on a scanned tag',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}
