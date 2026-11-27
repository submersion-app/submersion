import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
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
/// `firmware_version` attribute and its service history in step, in one
/// transaction.
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
    final trimmed = version.trim();
    await DatabaseService.instance.database.transaction(() async {
      await _log(equipmentId, trimmed, date, notes: notes);
      await _setVersion(equipmentId, trimmed);
    });
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
  }) async {
    final reported = reportedVersion.trim();
    final item = await _equipment.getEquipmentById(equipmentId);
    if (item == null || reported.isEmpty) {
      return FirmwareReportOutcome.unchanged;
    }
    final stored = item.firmwareVersion?.trim() ?? '';
    if (stored.isEmpty) {
      await _setVersion(equipmentId, reported);
      return FirmwareReportOutcome.recordedFirst;
    }
    final model = catalogue == null
        ? null
        : matchFirmwareModel(
            catalogue,
            type: item.type,
            brand: item.brand,
            model: item.model,
          );
    if (sameFirmwareRelease(stored, reported, model: model)) {
      return FirmwareReportOutcome.unchanged;
    }
    await DatabaseService.instance.database.transaction(() async {
      await _log(equipmentId, reported, at);
      await _setVersion(equipmentId, reported);
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

  /// Replaces only the curated `firmware_version` row; every other attribute
  /// is written back as it was.
  Future<void> _setVersion(String equipmentId, String version) async {
    final item = await _equipment.getEquipmentById(equipmentId);
    if (item == null) return;
    await _equipment.saveAttributes(equipmentId, [
      for (final a in item.attributes)
        if (a.isCustom || a.key != EquipmentAttrKeys.firmwareVersion) a,
      EquipmentAttribute.curated(
        equipmentId: equipmentId,
        key: EquipmentAttrKeys.firmwareVersion,
        valueText: version,
      ),
    ]);
  }
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
