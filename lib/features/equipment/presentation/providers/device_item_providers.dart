import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

/// A Dive Computer item and the registrations behind it, most recently
/// downloaded first; empty for an item added by hand (issue #3676).
typedef ComputerItem = ({EquipmentItem item, List<DiveComputer> computers});

/// A Transmitter item and the registry keys behind it (issue #3676).
typedef TransmitterItem = ({EquipmentItem item, List<Transmitter> keys});

/// Deletes a device's Equipment item, and with it the device (issue
/// #3676). Returns false when the diver does not own the item. Its own
/// provider so the lists' bulk delete can be tested without the notifier.
final deviceItemDeleterProvider = Provider<Future<bool> Function(String)>(
  (ref) =>
      (itemId) => ref
          .read(equipmentListNotifierProvider.notifier)
          .deleteEquipment(itemId),
);

/// The Dive Computers list (issue #3676): every Dive Computer item the
/// active diver has, whether discovered, imported or added by hand, except
/// gear only wanted. A Wanted item a computer stands for is still listed:
/// the device downloads whatever the item's status says. Derived from the
/// equipment and computer lists, so it refreshes when either does.
final computerItemsProvider = FutureProvider<List<ComputerItem>>((ref) async {
  final items = await ref.watch(allEquipmentProvider.future);
  final computers = await ref.watch(allDiveComputersProvider.future);
  final byItem = <String, List<DiveComputer>>{};
  for (final c in computers) {
    final id = c.equipmentId;
    if (id != null) byItem.putIfAbsent(id, () => []).add(c);
  }
  int newestFirst(DiveComputer a, DiveComputer b) {
    final at = a.lastDownload?.millisecondsSinceEpoch ?? -1;
    final bt = b.lastDownload?.millisecondsSinceEpoch ?? -1;
    return bt.compareTo(at);
  }

  return [
    for (final item in items)
      if (item.type == EquipmentType.computer &&
          (item.status != EquipmentStatus.wanted ||
              byItem.containsKey(item.id)))
        (item: item, computers: [...?byItem[item.id]]..sort(newestFirst)),
  ];
});

/// The Transmitters list (issue #3676): every Transmitter item the active
/// diver has, with its registry keys, except gear only wanted (a Wanted
/// item with keys is still a transmitter the downloads see).
final transmitterItemsProvider = FutureProvider<List<TransmitterItem>>((
  ref,
) async {
  final items = await ref.watch(allEquipmentProvider.future);
  final keys = await ref.watch(transmittersProvider.future);
  final byItem = <String, List<Transmitter>>{};
  for (final k in keys) {
    final id = k.transmitterEquipmentId;
    if (id != null) byItem.putIfAbsent(id, () => []).add(k);
  }
  return [
    for (final item in items)
      if (item.type == EquipmentType.transmitter &&
          (item.status != EquipmentStatus.wanted ||
              byItem.containsKey(item.id)))
        (item: item, keys: byItem[item.id] ?? const []),
  ];
});
