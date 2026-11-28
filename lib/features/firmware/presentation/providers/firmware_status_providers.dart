import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_catalogue_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [registrations] newest download first; a computer never downloaded last.
List<DiveComputer> _newestFirst(List<DiveComputer> registrations) {
  int at(DiveComputer c) => c.lastDownload?.millisecondsSinceEpoch ?? -1;
  return [...registrations]..sort((a, b) => at(b).compareTo(at(a)));
}

String? _nonBlank(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// The firmware [item] runs: its own recorded version, else the version the
/// newest download of a computer it stands for reported (issue #5104). The
/// second is read through, never copied: nothing stored is rewritten.
String? installedFirmwareOf(
  EquipmentItem item,
  List<DiveComputer> registrations,
) {
  final own = _nonBlank(item.firmwareVersion);
  if (own != null) return own;
  for (final c in _newestFirst(registrations)) {
    if (_nonBlank(c.firmwareVersion) case final v?) return v;
  }
  return null;
}

/// The firmware status of every fitted, firmware-capable item the active
/// diver has, by item id. A gear twin with no maker or model of its own is
/// matched by its newest registration's.
final firmwareStatusesProvider = FutureProvider<Map<String, FirmwareStatus>>((
  ref,
) async {
  final items = await ref.watch(allEquipmentProvider.future);
  final computers = await ref.watch(allDiveComputersProvider.future);
  final catalogue = await ref.watch(firmwareCatalogueProvider.future);
  final byItem = <String, List<DiveComputer>>{};
  for (final c in computers) {
    if (c.equipmentId case final id?) byItem.putIfAbsent(id, () => []).add(c);
  }
  return {
    for (final item in items)
      if (item.isFitted && EquipmentAttributeCatalog.hasFirmware(item.type))
        item.id: _statusOf(item, byItem[item.id] ?? const [], catalogue),
  };
});

FirmwareStatus _statusOf(
  EquipmentItem item,
  List<DiveComputer> registrations,
  FirmwareCatalogue? catalogue,
) {
  final newest = _newestFirst(registrations).firstOrNull;
  return firmwareStatusFor(
    catalogue: catalogue,
    type: item.type,
    brand: _nonBlank(item.brand) ?? newest?.manufacturer,
    model: _nonBlank(item.model) ?? newest?.model,
    installedVersion: installedFirmwareOf(item, registrations),
  );
}

/// One item's firmware status, or null while loading or when the item is
/// not one that records firmware.
final firmwareStatusProvider = Provider.family<FirmwareStatus?, String>(
  (ref, itemId) => ref.watch(firmwareStatusesProvider).value?[itemId],
);

typedef FirmwareUpdateEntry = ({
  EquipmentItem item,
  FirmwareUpdateAvailable status,
});

/// Whether any release above the installed one is a safety fix.
bool isSafetyUpdate(FirmwareUpdateAvailable status) =>
    status.newer.any((r) => r.safety);

/// The items with a newer release listed, safety updates first, then by
/// item name.
final firmwareUpdatesProvider = FutureProvider<List<FirmwareUpdateEntry>>((
  ref,
) async {
  final statuses = await ref.watch(firmwareStatusesProvider.future);
  final items = await ref.watch(allEquipmentProvider.future);
  final updates = <FirmwareUpdateEntry>[
    for (final item in items)
      if (statuses[item.id] case final FirmwareUpdateAvailable status)
        (item: item, status: status),
  ];
  updates.sort((a, b) {
    final safety = (isSafetyUpdate(b.status) ? 1 : 0).compareTo(
      isSafetyUpdate(a.status) ? 1 : 0,
    );
    if (safety != 0) return safety;
    return compareTextForSort(a.item.name, b.item.name);
  });
  return updates;
});

/// One equipment table Firmware cell: the installed version, and the newest
/// listed release when it is newer.
typedef FirmwareCell = ({String installed, String? latest});

/// The text of a [FirmwareCell] in the diver's language.
String firmwareCellLabel(AppLocalizations l10n, FirmwareCell cell) =>
    switch (cell.latest) {
      final latest? => l10n.firmware_column_update(cell.installed, latest),
      null => cell.installed,
    };

/// The equipment table's Firmware cells by item id (issue #5104). Items with
/// no version known are absent.
final firmwareColumnCellsProvider = FutureProvider<Map<String, FirmwareCell>>((
  ref,
) async {
  final items = await ref.watch(allEquipmentProvider.future);
  final computers = await ref.watch(allDiveComputersProvider.future);
  final statuses = await ref.watch(firmwareStatusesProvider.future);
  final byItem = <String, List<DiveComputer>>{};
  for (final c in computers) {
    if (c.equipmentId case final id?) byItem.putIfAbsent(id, () => []).add(c);
  }
  return {
    for (final item in items)
      if (installedFirmwareOf(item, byItem[item.id] ?? const [])
          case final installed?)
        item.id: (
          installed: installed,
          latest: switch (statuses[item.id]) {
            FirmwareUpdateAvailable(:final latest) => latest.version,
            _ => null,
          },
        ),
  };
});
