import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_firmware_version.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What a reported firmware version did to an item's record.
enum FirmwareReportOutcome {
  /// The item had no version; it now has one, with no history entry.
  recordedFirst,

  /// The same release as recorded, perhaps spelled differently; nothing
  /// changed.
  unchanged,

  /// A different version: recorded, and a history entry logged.
  logged,
}

/// Writes firmware history (issue #5104): an update the diver logs, and a
/// version a dive computer download reports. Each keeps the item's
/// `firmware_version` attribute and its service history in step.
class FirmwareUpdateRecorder {
  FirmwareUpdateRecorder({
    EquipmentRepository? equipment,
    ServiceRecordRepository? serviceRecords,
  }) : _equipment = equipment ?? EquipmentRepository(),
       _records = serviceRecords ?? ServiceRecordRepository();

  final EquipmentRepository _equipment;
  final ServiceRecordRepository _records;

  /// Logs an update to [version] installed on [date], and makes it the
  /// item's recorded version.
  Future<void> logUpdate({
    required String equipmentId,
    required String version,
    required DateTime date,
    String notes = '',
  }) async {
    // The repository makes it the recorded version when it is the item's
    // newest firmware update, so a back-dated entry never overwrites one;
    // the record and the version land together or not at all.
    await DatabaseService.instance.database.transaction(
      () => _log(equipmentId, version.trim(), date, notes: notes),
    );
  }

  /// Records [reportedVersion], reported by a live download at [at]. A first
  /// report sets the version quietly; the same release in another spelling
  /// (equal ignoring case, or listed under one release of [catalogue])
  /// changes nothing and keeps the stored spelling; any other version is
  /// logged as a change.
  Future<FirmwareReportOutcome> recordReported({
    required String equipmentId,
    required String reportedVersion,
    required DateTime at,
    FirmwareCatalogue? catalogue,
    String? fallbackBrand,
    String? fallbackModel,
    String? previousVersion,
  }) async {
    final reported = reportedVersion.trim();
    final item = await _equipment.getEquipmentById(equipmentId);
    if (item == null || reported.isEmpty) {
      return FirmwareReportOutcome.unchanged;
    }
    // The item's own version, else the one the registration held before
    // this download (read through, never copied).
    final stored =
        _nonBlank(item.firmwareVersion) ?? _nonBlank(previousVersion) ?? '';
    if (stored.isEmpty) {
      await setRecordedFirmwareVersion(_equipment, equipmentId, reported);
      return FirmwareReportOutcome.recordedFirst;
    }
    final model = catalogue == null
        ? null
        : matchFirmwareModel(
            catalogue,
            type: item.type,
            brand: _nonBlank(item.brand) ?? fallbackBrand,
            model: _nonBlank(item.model) ?? fallbackModel,
          );
    if (sameFirmwareRelease(stored, reported, model: model)) {
      // Known only from the registration so far: now the item has it too.
      if (_nonBlank(item.firmwareVersion) == null) {
        await setRecordedFirmwareVersion(_equipment, equipmentId, stored);
      }
      return FirmwareReportOutcome.unchanged;
    }
    // What the device reports is what it runs, whatever the history says.
    await DatabaseService.instance.database.transaction(() async {
      await _log(equipmentId, reported, at);
      await setRecordedFirmwareVersion(_equipment, equipmentId, reported);
    });
    return FirmwareReportOutcome.logged;
  }

  Future<void> _log(
    String equipmentId,
    String version,
    DateTime date, {
    String notes = '',
  }) async {
    final now = DateTime.now();
    await _records.createRecord(
      ServiceRecord(
        id: '',
        equipmentId: equipmentId,
        serviceCategory: ServiceCategory.firmwareUpdate,
        serviceDate: date,
        notes: notes,
        firmwareVersion: version,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// How a firmware history entry reads: "Firmware updated to V95", or
/// "Firmware changed to V94" when [model]'s release list ranks the version
/// below [previous] (a downgrade). Without a ranking it is an update.
String firmwareHistoryLabel(
  AppLocalizations l10n,
  ServiceRecord record, {
  FirmwareModel? model,
  String? previous,
}) {
  final version = record.firmwareVersion?.trim() ?? '';
  if (model != null && previous != null) {
    final now = releaseIndexOf(model, version);
    final before = releaseIndexOf(model, previous);
    // Newest first: a larger index is an older release.
    if (now != null && before != null && now > before) {
      return l10n.firmware_history_changedTo(version);
    }
  }
  return l10n.firmware_history_updatedTo(version);
}
