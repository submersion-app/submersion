import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/l10n/l10n_extension.dart';
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
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.universalImport_preset_saveTitle),
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
                  decoration: InputDecoration(
                    labelText: l10n.universalImport_preset_nameLabel,
                    hintText: l10n.universalImport_preset_nameHint,
                  ),
                  autofocus: true,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? l10n.universalImport_preset_nameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SourceApp?>(
                  initialValue: _sourceApp,
                  decoration: InputDecoration(
                    labelText: l10n.universalImport_preset_sourceAppLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.universalImport_preset_sourceAppNone),
                    ),
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
                Text(
                  l10n.universalImport_preset_entityTypesLabel,
                  style: theme.textTheme.labelLarge,
                ),
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
                Text(
                  l10n.universalImport_preset_matchThresholdLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.universalImport_preset_matchThresholdHelp,
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
                  l10n.universalImport_preset_signatureHeaders(
                    widget.csvHeaders.length,
                  ),
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
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.common_action_save)),
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
