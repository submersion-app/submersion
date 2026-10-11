import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';

/// Record that an import reached [computerId] through [kind] / [detail]
/// (issue #3106). Bookkeeping after the dives are written: a missing
/// repository records nothing and a failure is logged, never thrown, so it
/// cannot cost the user the import.
Future<void> recordImportConnection(
  DiveComputerConnectionRepository? repository, {
  required String computerId,
  required DiveComputerConnectionKind kind,
  String? detail,
  required LoggerService log,
}) async {
  if (repository == null) return;
  try {
    await repository.recordConnection(
      computerId: computerId,
      kind: kind,
      detail: detail,
    );
  } catch (e, stackTrace) {
    log.error(
      'Could not record the ${kind.name} connection for computer $computerId',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
