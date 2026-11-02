import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/data/services/equipment_return_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/move_time.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Takes [items] back from [buddyId]: the sheet, then the parts and status
/// prompts, then a SnackBar. Returns how many items came back, or null when
/// cancelled or when the return failed (a SnackBar says so).
Future<int?> showEquipmentReturnFlow(
  BuildContext context,
  WidgetRef ref, {
  required List<EquipmentItem> items,
  required String buddyId,
}) async {
  if (items.isEmpty) return null;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(equipmentListNotifierProvider.notifier);
  void failed() => messenger.showSnackBar(
    SnackBar(content: Text(l10n.common_error_tryAgain)),
  );
  final flow = EquipmentReturnFlow(
    moves: ref.read(equipmentLocationMoveRepositoryProvider),
    askMoveParts: (n) => askMoveParts(context, n),
    askStatus: (status, n) => askMoveStatus(context, status, n),
    setStatus: notifier.setStatusForMany,
    onStatusFailed: failed,
  );
  try {
    final places = await ref.read(allEquipmentLocationsByIdProvider.future);
    final destinations = await flow.destinations(
      items: items,
      buddyId: buddyId,
      places: places,
    );
    if (!context.mounted) return null;
    final draft = await showModalBottomSheet<_ReturnDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReturnEquipmentSheet(
        itemCount: items.length,
        destinations: destinations,
      ),
    );
    if (draft == null) return null;
    final returned = await flow.run(
      items: items,
      buddyId: buddyId,
      places: places,
      movedAt: draft.movedAt,
      note: draft.note,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.equipment_location_returned(returned))),
    );
    return returned;
  } catch (_) {
    // The flow fails only before or while the moves are written (a failed
    // status write is reported apart), so the diver can simply try again.
    failed();
    return null;
  }
}

class _ReturnDraft {
  const _ReturnDraft({required this.movedAt, required this.note});
  final DateTime movedAt;
  final String note;
}

class _ReturnEquipmentSheet extends ConsumerStatefulWidget {
  const _ReturnEquipmentSheet({
    required this.itemCount,
    required this.destinations,
  });

  final int itemCount;

  /// Where the items go. Null stands for No location.
  final Set<EquipmentLocation?> destinations;

  @override
  ConsumerState<_ReturnEquipmentSheet> createState() =>
      _ReturnEquipmentSheetState();
}

class _ReturnEquipmentSheetState extends ConsumerState<_ReturnEquipmentSheet> {
  DateTime _day = DateTime.now();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _where() {
    final l10n = context.l10n;
    if (widget.destinations.length != 1) {
      return l10n.equipment_location_return_eachToOwn;
    }
    return l10n.equipment_location_return_to(
      widget.destinations.single?.name ?? l10n.equipment_location_noLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
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
              l10n.equipment_location_return_title(widget.itemCount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.keyboard_return),
              title: Text(_where()),
            ),
            ListTile(
              key: const ValueKey('return_equipment_date'),
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
            TextField(
              key: const ValueKey('return_equipment_note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.equipment_location_move_note,
                hintText: l10n.equipment_location_move_noteHint,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('return_equipment_confirm'),
              onPressed: () => Navigator.of(context).pop(
                _ReturnDraft(
                  movedAt: resolveMovedAt(day: _day, now: DateTime.now()),
                  note: _note.text,
                ),
              ),
              child: Text(l10n.equipment_location_return_confirm),
            ),
          ],
        ),
      ),
    );
  }
}
