import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Creates a place (no [existing]) or edits one. Returns the saved place, or
/// null when cancelled. [initialName] prefills a new place's name, as the
/// picker does from its search text.
Future<EquipmentLocation?> showEquipmentLocationEditDialog(
  BuildContext context,
  WidgetRef ref, {
  EquipmentLocation? existing,
  String initialName = '',
}) {
  return showDialog<EquipmentLocation>(
    context: context,
    builder: (_) => _EquipmentLocationEditDialog(
      existing: existing,
      initialName: initialName,
    ),
  );
}

class _EquipmentLocationEditDialog extends ConsumerStatefulWidget {
  const _EquipmentLocationEditDialog({
    this.existing,
    required this.initialName,
  });

  final EquipmentLocation? existing;
  final String initialName;

  @override
  ConsumerState<_EquipmentLocationEditDialog> createState() =>
      _EquipmentLocationEditDialogState();
}

class _EquipmentLocationEditDialogState
    extends ConsumerState<_EquipmentLocationEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late EquipmentLocationKind _kind;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existing?.name ?? widget.initialName.trim(),
    );
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _kind = widget.existing?.kind ?? EquipmentLocationKind.storage;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// A warning, not a block: two devices or a diver merge can produce the
  /// same name anyway, and the diver may mean two different places.
  bool _isDuplicate(List<EquipmentLocation> places) {
    final wanted = _name.text.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    return places.any(
      (p) => p.id != widget.existing?.id && p.name.toLowerCase() == wanted,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(equipmentLocationRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.common_error_tryAgain;
    try {
      final existing = widget.existing;
      final EquipmentLocation saved;
      if (existing == null) {
        saved = await repo.createLocation(
          diverId: await ref.read(validatedCurrentDiverIdProvider.future),
          name: _name.text,
          kind: _kind,
          notes: _notes.text,
        );
      } else {
        saved = existing.copyWith(
          name: _name.text.trim(),
          kind: _kind,
          notes: _notes.text.trim(),
        );
        await repo.updateLocation(saved);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      // Keep the dialog and what the diver typed.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final places =
        ref.watch(equipmentLocationsProvider).value ??
        const <EquipmentLocation>[];
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.equipment_locations_newTitle
            : l10n.equipment_locations_editTitle,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('equipment_location_name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.equipment_locations_nameLabel,
                  helperText: _isDuplicate(places)
                      ? l10n.equipment_locations_duplicateWarning
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.equipment_locations_nameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EquipmentLocationKind>(
                key: const ValueKey('equipment_location_kind'),
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: l10n.equipment_locations_kindLabel,
                ),
                items: [
                  for (final kind in EquipmentLocationKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Row(
                        children: [
                          Icon(kind.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(kind.localizedName(l10n)),
                        ],
                      ),
                    ),
                ],
                onChanged: (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('equipment_location_notes'),
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.equipment_locations_notesLabel,
                  hintText: l10n.equipment_locations_notesHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const ValueKey('equipment_location_save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
