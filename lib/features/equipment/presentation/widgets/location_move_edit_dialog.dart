import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/domain/services/move_time.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_confirm_dialogs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Edits one history entry's place, date and note, or deletes it. The
/// current location recomputes from what is left.
Future<void> showLocationMoveEditDialog(
  BuildContext context,
  WidgetRef ref,
  EquipmentLocationMove move,
) => showDialog<void>(
  context: context,
  builder: (_) => _LocationMoveEditDialog(move: move),
);

class _LocationMoveEditDialog extends ConsumerStatefulWidget {
  const _LocationMoveEditDialog({required this.move});
  final EquipmentLocationMove move;

  @override
  ConsumerState<_LocationMoveEditDialog> createState() =>
      _LocationMoveEditDialogState();
}

class _LocationMoveEditDialogState
    extends ConsumerState<_LocationMoveEditDialog> {
  late String? _locationId = widget.move.locationId;
  late DateTime _movedAt = widget.move.movedAt;
  late final TextEditingController _note = TextEditingController(
    text: widget.move.note,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPlace() async {
    final picked = await showEquipmentLocationPickerSheet(context, ref);
    if (picked == null) return;
    setState(
      () => _locationId = switch (picked) {
        PlacePick(:final location) => location.id,
        NoLocationPick() => null,
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _movedAt,
      firstDate: DateTime(1970),
      // A peer whose clock runs ahead can sync a move dated after today;
      // the picker asserts its initial date is not past the last one.
      lastDate: _movedAt.isAfter(now) ? _movedAt : now,
    );
    if (picked == null) return;
    // Keep the time of day, so editing the date never reorders two moves
    // made on the same day; held at now if that lands it in the future.
    setState(
      () => _movedAt = notAfterNow(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          _movedAt.hour,
          _movedAt.minute,
          _movedAt.second,
          _movedAt.millisecond,
        ),
        DateTime.now(),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_movedAt),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _movedAt = notAfterNow(
        DateTime(
          _movedAt.year,
          _movedAt.month,
          _movedAt.day,
          picked.hour,
          picked.minute,
        ),
        DateTime.now(),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(equipmentLocationMoveRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.common_error_tryAgain;
    final locationId = _locationId;
    try {
      await repo.updateMove(
        locationId == null
            ? widget.move.copyWith(
                clearLocation: true,
                movedAt: _movedAt,
                note: _note.text,
              )
            : widget.move.copyWith(
                locationId: locationId,
                movedAt: _movedAt,
                note: _note.text,
              ),
      );
    } catch (_) {
      // Keep the dialog and the diver's edits so they can try again.
      showLocationWriteFailed(messenger, failed);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmLocationDelete(
      context,
      l10n.equipment_location_deleteMoveConfirm,
    )) {
      return;
    }
    try {
      await ref
          .read(equipmentLocationMoveRepositoryProvider)
          .deleteMove(widget.move.id);
    } catch (_) {
      showLocationWriteFailed(messenger, l10n.common_error_tryAgain);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final places =
        ref.watch(allEquipmentLocationsByIdProvider).value ??
        const <String, EquipmentLocation>{};
    return AlertDialog(
      title: Text(l10n.equipment_location_editMove_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('location_move_place'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.equipment_location_move_to),
            subtitle: Text(
              places[_locationId]?.name ?? l10n.equipment_location_noLocation,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickPlace,
          ),
          ListTile(
            key: const ValueKey('location_move_date'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.equipment_location_move_date),
            subtitle: Text(units.formatDate(_movedAt)),
            trailing: const Icon(Icons.event),
            onTap: _pickDate,
          ),
          ListTile(
            key: const ValueKey('location_move_time'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.equipment_location_move_time),
            subtitle: Text(units.formatTime(_movedAt)),
            trailing: const Icon(Icons.schedule),
            onTap: _pickTime,
          ),
          TextField(
            key: const ValueKey('location_move_note'),
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.equipment_location_move_note,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('location_move_delete'),
          onPressed: _delete,
          child: Text(l10n.equipment_location_editMove_delete),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const ValueKey('location_move_save'),
          onPressed: _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
