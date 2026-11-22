import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

const _log = LoggerService('NewRecordDiver');

/// The active diver a new record (a [record], for the log) is made for
/// (issue #4527, phase 3, plan 11), read through [read]: null when there is
/// none, or when it cannot be read, so the record's Save takes the diver
/// active then, as the forms do at Save.
Future<String?> newRecordDiverId(
  RecordSeedRead read, {
  required String record,
}) async {
  try {
    return await read(validatedCurrentDiverIdProvider.future);
  } catch (error, stackTrace) {
    _log.warning(
      'Could not read the diver for a new $record',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}
