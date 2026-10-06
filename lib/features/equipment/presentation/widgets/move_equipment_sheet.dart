import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/move_time.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Where, when and why, as the move sheet returns it.
class MoveDraft {
  const MoveDraft({required this.pick, required this.movedAt, this.note = ''});
  final LocationPick pick;
  final DateTime movedAt;
  final String note;
}

/// Moves [items]: the sheet, then the parts and status prompts, then a
/// SnackBar. Returns how many items moved, or null when cancelled or when
/// the move failed (a SnackBar says so).
Future<int?> showMoveEquipmentFlow(
  BuildContext context,
  WidgetRef ref, {
  required List<EquipmentItem> items,
}) async {
  if (items.isEmpty) return null;
  final draft = await showMoveEquipmentSheet(
    context,
    ref,
    itemCount: items.length,
  );
  if (draft == null || !context.mounted) return null;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(equipmentListNotifierProvider.notifier);
  // A prompt the page can no longer show is a no: after the moves are
  // written, a throw here would report a saved move as failed.
  Future<bool> ask(String title, String body, String yes, String no) async =>
      context.mounted &&
      (await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(no),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(yes),
                ),
              ],
            ),
          ) ??
          false);
  final flow = EquipmentMoveFlow(
    moves: ref.read(equipmentLocationMoveRepositoryProvider),
    askMoveParts: (n) => ask(
      l10n.equipment_location_parts_title,
      l10n.equipment_location_parts_body(n),
      l10n.equipment_location_parts_yes,
      l10n.equipment_location_parts_no,
    ),
    askStatus: (status, n) => ask(
      l10n.equipment_location_status_title,
      l10n.equipment_location_status_body(n, status.localizedName(l10n)),
      l10n.equipment_location_status_yes,
      l10n.equipment_location_status_no,
    ),
    setStatus: notifier.setStatusForMany,
    onStatusFailed: () => messenger.showSnackBar(
      SnackBar(content: Text(l10n.common_error_tryAgain)),
    ),
  );
  final int moved;
  try {
    moved = await flow.run(
      items: items,
      target: switch (draft.pick) {
        PlacePick(:final location) => location,
        NoLocationPick() => null,
      },
      movedAt: draft.movedAt,
      note: draft.note,
    );
  } catch (_) {
    // The flow fails only before or while the moves are written (a failed
    // status write is reported apart), so the diver can simply try again.
    messenger.showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
    return null;
  }
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.equipment_location_moved(moved))),
  );
  return moved;
}

/// The move sheet: destination, date and note. Null when dismissed.
Future<MoveDraft?> showMoveEquipmentSheet(
  BuildContext context,
  WidgetRef ref, {
  required int itemCount,
}) {
  return showModalBottomSheet<MoveDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoveEquipmentSheet(itemCount: itemCount),
  );
}

class _MoveEquipmentSheet extends ConsumerStatefulWidget {
  const _MoveEquipmentSheet({required this.itemCount});
  final int itemCount;

  @override
  ConsumerState<_MoveEquipmentSheet> createState() =>
      _MoveEquipmentSheetState();
}

class _MoveEquipmentSheetState extends ConsumerState<_MoveEquipmentSheet> {
  LocationPick? _pick;
  DateTime _day = DateTime.now();

  /// Null until the diver picks a time; see [resolveMovedAt].
  ({int hour, int minute})? _time;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _movedAt =>
      resolveMovedAt(day: _day, time: _time, now: DateTime.now());

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_movedAt),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = (hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final pick = _pick;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.equipment_location_move_title(widget.itemCount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('move_equipment_to'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (pick) {
                PlacePick(:final location) => location.kind.icon,
                NoLocationPick() => Icons.location_off_outlined,
                null => Icons.place_outlined,
              }),
              title: Text(l10n.equipment_location_move_to),
              subtitle: Text(switch (pick) {
                PlacePick(:final location) => location.name,
                NoLocationPick() => l10n.equipment_location_noLocation,
                null => l10n.equipment_location_move_choose,
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showEquipmentLocationPickerSheet(
                  context,
                  ref,
                );
                if (picked != null) setState(() => _pick = picked);
              },
            ),
            ListTile(
              key: const ValueKey('move_equipment_date'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l10n.equipment_location_move_date),
              subtitle: Text(units.formatDate(_day)),
              onTap: () async {
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(1970),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _day = picked);
              },
            ),
            ListTile(
              key: const ValueKey('move_equipment_time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(l10n.equipment_location_move_time),
              subtitle: Text(units.formatTime(_movedAt)),
              onTap: _pickTime,
            ),
            TextField(
              key: const ValueKey('move_equipment_note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.equipment_location_move_note,
                hintText: l10n.equipment_location_move_noteHint,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('move_equipment_confirm'),
              onPressed: pick == null
                  ? null
                  : () => Navigator.of(context).pop(
                      MoveDraft(
                        pick: pick,
                        movedAt: _movedAt,
                        note: _note.text,
                      ),
                    ),
              child: Text(l10n.equipment_location_move_confirm),
            ),
          ],
        ),
      ),
    );
  }
}
