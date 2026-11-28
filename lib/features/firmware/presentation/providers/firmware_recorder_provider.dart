import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/firmware/data/firmware_update_recorder.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_catalogue_providers.dart';

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

/// The one way a download hands a reported firmware version to the history,
/// for every download path: the download notifier and the import wizard's
/// adapter, which writes a computer it finds by serial itself. The cached
/// catalogue tells two spellings of one release apart from a real change.
final firmwareReportProvider = Provider<FirmwareReport>(
  (ref) =>
      (computer, version, previous) => ref
          .read(firmwareUpdateRecorderProvider)
          .recordReported(
            equipmentId: computer.equipmentId!,
            reportedVersion: version,
            at: DateTime.now(),
            catalogue: ref.read(firmwareCatalogueProvider).value,
            // A gear twin may have no maker or model of its own.
            fallbackBrand: computer.manufacturer,
            fallbackModel: computer.model,
            previousVersion: previous,
          ),
);
