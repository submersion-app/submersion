import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/firmware/data/firmware_update_recorder.dart';

/// The firmware history writer (issue #5104). Its own provider so the
/// download hook and the Log firmware update sheet can be tested with a fake.
final firmwareUpdateRecorderProvider = Provider<FirmwareUpdateRecorder>(
  (ref) => FirmwareUpdateRecorder(),
);

/// Hands a version a download reported to the firmware history, with the
/// version the registration held before it.
typedef FirmwareReport =
    Future<void> Function(
      DiveComputer computer,
      String version,
      String? previousVersion,
    );
