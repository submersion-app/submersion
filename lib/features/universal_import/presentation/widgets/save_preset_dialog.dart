import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Dialog for saving the current CSV field mapping as a reusable preset.
///
/// Returns the created [CsvPreset] on save, or null on cancel.
class SavePresetDialog extends StatefulWidget {
  /// Current field mapping to save.
  final FieldMapping mapping;

  /// CSV headers from the current file (used as signature headers).
  final List<String> csvHeaders;

  /// Detected source app, if any.
  final SourceApp? detectedSourceApp;

  /// Entity types enabled in the current import configuration.
  final Set<ImportEntityType> currentEntityTypes;

  const SavePresetDialog({
    super.key,
    required this.mapping,
    required this.csvHeaders,
    this.detectedSourceApp,
    this.currentEntityTypes = const {
      ImportEntityType.dives,
      ImportEntityType.sites,
    },
  });

  @override
  State<SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends State<SavePresetDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late SourceApp? _sourceApp;
  late Set<ImportEntityType> _entityTypes;
  double _matchThreshold = 0.5;

  static const _entityOptions = [
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.buddies,
    ImportEntityType.tags,
    ImportEntityType.equipment,
  ];

  @override
  void initState() {
    super.initState();
    _sourceApp = widget.detectedSourceApp;
    _entityTypes = Set.from(widget.currentEntityTypes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Save as Preset'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Preset Name',
                    hintText: 'e.g., My Dive Log CSV',
                  ),
                  autofocus: true,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SourceApp?>(
                  initialValue: _sourceApp,
                  decoration: const InputDecoration(
                    labelText: 'Source Application',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final app in SourceApp.values)
                      if (app != SourceApp.generic)
                        DropdownMenuItem(
                          value: app,
                          child: Text(app.displayName),
                        ),
                  ],
                  onChanged: (v) => setState(() => _sourceApp = v),
                ),
                const SizedBox(height: 20),
                Text('Entity Types', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final type in _entityOptions)
                      FilterChip(
                        label: Text(type.displayName),
                        selected: _entityTypes.contains(type),
                        onSelected: type == ImportEntityType.dives
                            ? null // dives always required
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _entityTypes.add(type);
                                  } else {
                                    _entityTypes.remove(type);
                                  }
                                });
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Match Threshold', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  'How closely CSV headers must match for auto-detection',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: _matchThreshold,
                  min: 0.3,
                  max: 0.9,
                  divisions: 6,
                  label: '${(_matchThreshold * 100).round()}%',
                  onChanged: (v) => setState(() => _matchThreshold = v),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.csvHeaders.length} signature headers '
                  'from current file',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final preset = CsvPreset(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      source: PresetSource.userSaved,
      sourceApp: _sourceApp,
      signatureHeaders:
          widget.csvHeaders
              .map((h) => h.trim().toLowerCase())
              .where((h) => h.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
      matchThreshold: _matchThreshold,
      mappings: {'primary': widget.mapping},
      supportedEntities: _entityTypes,
    );

    Navigator.of(context).pop(preset);
  }
}
