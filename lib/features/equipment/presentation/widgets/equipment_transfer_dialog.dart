import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the owner chose in the transfer dialog (issue #2852).
typedef EquipmentTransferRequest = ({
  String toDiverId,
  bool keepAccess,
  bool moveRegistry,
});

/// Asks which profile receives [equipmentIds] and how; null when cancelled.
/// [profiles] is every profile except [activeDiverId].
Future<EquipmentTransferRequest?> showEquipmentTransferDialog(
  BuildContext context, {
  required List<String> equipmentIds,
  required String activeDiverId,
  required List<Diver> profiles,
}) => showDialog<EquipmentTransferRequest>(
  context: context,
  builder: (_) => _EquipmentTransferDialog(
    equipmentIds: equipmentIds,
    activeDiverId: activeDiverId,
    profiles: profiles,
  ),
);

class _EquipmentTransferDialog extends ConsumerStatefulWidget {
  const _EquipmentTransferDialog({
    required this.equipmentIds,
    required this.activeDiverId,
    required this.profiles,
  });

  final List<String> equipmentIds;
  final String activeDiverId;
  final List<Diver> profiles;

  @override
  ConsumerState<_EquipmentTransferDialog> createState() =>
      _EquipmentTransferDialogState();
}

class _EquipmentTransferDialogState
    extends ConsumerState<_EquipmentTransferDialog> {
  String? _target;
  bool _keepAccess = true;
  bool _moveRegistry = true;
  EquipmentTransferPreview? _preview;

  /// The profile [_preview] was read for. Until it matches [_target] the
  /// preview on screen describes another choice (its clash notes most of
  /// all), so Transfer waits for the new one.
  String? _previewTarget;
  List<EquipmentItem> _extraItems = const [];
  int _request = 0;

  /// The latest preview could not be read, so the dialog cannot say what
  /// would move and Transfer stays off until a later preview succeeds.
  bool _previewFailed = false;

  static final _log = LoggerService.forClass(_EquipmentTransferDialog);

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  /// Reloads the preview for the chosen profile. Only the latest request
  /// lands, so a slow answer for an earlier choice cannot overwrite it, and
  /// the previous preview stays on screen while the next one loads.
  Future<void> _loadPreview() async {
    final request = ++_request;
    final target = _target;
    try {
      final preview = await ref
          .read(equipmentTransferServiceProvider)
          .preview(
            equipmentIds: widget.equipmentIds,
            actingDiverId: widget.activeDiverId,
            toDiverId: target,
          );
      final extraIds = [
        for (final id in preview.unitIds)
          if (!widget.equipmentIds.contains(id)) id,
      ];
      final extras = extraIds.isEmpty
          ? const <EquipmentItem>[]
          : await ref
                .read(equipmentRepositoryProvider)
                .getEquipmentByIds(extraIds);
      if (!mounted || request != _request) return;
      setState(() {
        _preview = preview;
        _previewTarget = target;
        _extraItems = extras;
        _previewFailed = false;
      });
    } catch (e, stackTrace) {
      _log.warning(
        'Could not preview an equipment transfer',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted || request != _request) return;
      setState(() => _previewFailed = true);
    }
  }

  String _nameOf(String id) {
    for (final p in widget.profiles) {
      if (p.id == id) return p.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preview = _preview;
    final target = _target;
    final labels = _extraItems.isEmpty
        ? null
        : equipmentRowLabelsOf(context, ref, _extraItems);
    final registryLabels = [
      for (final r in [...?preview?.computers, ...?preview?.transmitters])
        r.label,
    ];
    final note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(l10n.equipment_transfer_dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.equipment_transfer_dialogBody),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: target,
              onChanged: (v) {
                setState(() => _target = v);
                _loadPreview();
              },
              child: Column(
                children: [
                  for (final p in widget.profiles)
                    RadioListTile<String>(
                      value: p.id,
                      title: Text(p.name),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_extraItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.equipment_transfer_alsoMoves,
                style: theme.textTheme.titleSmall,
              ),
              for (final item in _extraItems)
                Text(labels?[item.id]?.title ?? item.name),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              value: _keepAccess,
              onChanged: (v) => setState(() => _keepAccess = v),
              title: Text(l10n.equipment_transfer_keepAccess),
              subtitle: Text(l10n.equipment_transfer_keepAccessHint),
              contentPadding: EdgeInsets.zero,
            ),
            if (_previewFailed)
              Text(
                l10n.common_error_tryAgain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (preview != null && preview.hasRegistry) ...[
              SwitchListTile(
                value: _moveRegistry,
                onChanged: (v) => setState(() => _moveRegistry = v),
                title: Text(l10n.equipment_transfer_moveRegistry),
                subtitle: Text(registryLabels.join(', ')),
                contentPadding: EdgeInsets.zero,
              ),
              if (target != null && _moveRegistry && _previewTarget == target)
                for (final t in preview.transmitters)
                  if (t.clashes)
                    Text(
                      l10n.equipment_transfer_transmitterClash(
                        t.label,
                        _nameOf(target),
                      ),
                      style: note,
                    ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          // Off until the preview has said what would move.
          onPressed:
              target == null ||
                  preview == null ||
                  _previewFailed ||
                  _previewTarget != target
              ? null
              : () => Navigator.of(context).pop((
                  toDiverId: target,
                  keepAccess: _keepAccess,
                  moveRegistry: _moveRegistry,
                )),
          child: Text(l10n.equipment_transfer_confirm),
        ),
      ],
    );
  }
}
