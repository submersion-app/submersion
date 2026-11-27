import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/firmware/data/firmware_update_recorder.dart';

/// The firmware history writer (issue #5104). Its own provider so the
/// download hook and the Log firmware update sheet can be tested with a fake.
final firmwareUpdateRecorderProvider = Provider<FirmwareUpdateRecorder>(
  (ref) => FirmwareUpdateRecorder(),
);
