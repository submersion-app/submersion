import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

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

  /// Held while the kind changes, so a mistaken change loses nothing; only
  /// a Dive center place saves it.
  String? _centerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existing?.name ?? widget.initialName.trim(),
    );
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _kind = widget.existing?.kind ?? EquipmentLocationKind.storage;
    _centerId = widget.existing?.diveCenterId;
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

  /// Choosing among the diver's saved centers only: one not saved yet can
  /// be typed as a name now and linked later.
  Future<void> _pickCenter(DiveCenter? current) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => DiveCenterPickerSheet(
        scrollController: scrollController,
        selectedCenter: current,
        onCenterSelected: (center) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _centerId = center.id;
            // A name the last pick filled in follows the new pick; one the
            // diver typed stays.
            final name = _name.text.trim();
            if (name.isEmpty || name == current?.name) _name.text = center.name;
          });
        },
      ),
    ),
  );

  Widget _centerField(AppLocalizations l10n) {
    final id = _centerId;
    final center = id == null
        ? null
        : ref.watch(diveCenterByIdProvider(id)).value;
    return InkWell(
      key: const ValueKey('equipment_location_center'),
      onTap: () => _pickCenter(center),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.equipment_locations_savedCenterLabel,
          suffixIcon: id == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  key: const ValueKey('equipment_location_center_clear'),
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.equipment_locations_savedCenterClear,
                  onPressed: () => setState(() => _centerId = null),
                ),
        ),
        child: Text(center?.name ?? l10n.equipment_locations_savedCenterNone),
      ),
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
      // Only a change of kind drops the link: an older device can retype a
      // linked place to Other, and editing its notes here must not unlink it.
      final centerId =
          _kind == EquipmentLocationKind.diveCenter || _kind == existing?.kind
          ? _centerId
          : null;
      final EquipmentLocation saved;
      if (existing == null) {
        saved = await repo.createLocation(
          diverId: await ref.read(validatedCurrentDiverIdProvider.future),
          name: _name.text,
          kind: _kind,
          diveCenterId: centerId,
          notes: _notes.text,
        );
      } else {
        saved = existing.copyWith(
          name: _name.text.trim(),
          kind: _kind,
          diveCenterId: centerId,
          clearDiveCenterId: centerId == null,
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
              if (_kind == EquipmentLocationKind.diveCenter) ...[
                const SizedBox(height: 16),
                _centerField(l10n),
              ],
              const SizedBox(height: 16),
              MarkdownNotesField(
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
