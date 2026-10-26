import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/csv_preset_providers.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/save_preset_dialog.dart';
import 'package:submersion/features/universal_import/presentation/widgets/select_preset_sheet.dart';

/// Step 2: CSV field mapping editor (only shown for CSV imports).
///
/// Shows the auto-detected or preset column mappings and allows users
/// to add, remove, or modify individual column-to-field mappings.
class FieldMappingStep extends ConsumerStatefulWidget {
  const FieldMappingStep({super.key});

  @override
  ConsumerState<FieldMappingStep> createState() => _FieldMappingStepState();
}

class _FieldMappingStepState extends ConsumerState<FieldMappingStep> {
  late FieldMapping _mapping;
  bool _initialized = false;

  static const _targetFields = [
    'diveNumber',
    'date',
    'time',
    'dateTime',
    'maxDepth',
    'avgDepth',
    'duration',
    'waterTemp',
    'airTemp',
    'siteName',
    'gps',
    'buddy',
    'diveMaster',
    'instructor',
    'buddyInstructorCenter',
    'diveCenter',
    'suit',
    'rating',
    'notes',
    'visibility',
    'weight',
    'sac',
    'tags',
    'startPressure',
    'endPressure',
    'tankVolume',
    'o2Percent',
    'diveType',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(universalImportNotifierProvider);
    final theme = Theme.of(context);

    if (!_initialized && state.options != null) {
      // Use the preset-based mapping if one was detected, otherwise fall
      // back to header-based detection via PresetRegistry.
      if (state.fieldMapping != null) {
        _mapping = state.fieldMapping!;
      } else if (state.detectedCsvPreset?.primaryMapping != null) {
        _mapping = state.detectedCsvPreset!.primaryMapping!;
      } else {
        final headers = state.detectionResult?.csvHeaders ?? [];
        final registry = PresetRegistry(builtInPresets: builtInCsvPresets);
        final matches = registry.detectPreset(headers);
        _mapping = matches.isNotEmpty
            ? matches.first.preset.primaryMapping ??
                  const FieldMapping(name: 'Auto-detected', columns: [])
            : const FieldMapping(name: 'Auto-detected', columns: []);
      }
      _initialized = true;

      // Persist the initial mapping to the notifier so the wizard's
      // canAdvance provider and onBeforeAdvance callback can access it.
      // Deferred to a post-frame callback to avoid modifying provider
      // state during build.
      if (state.fieldMapping == null && state.payload == null) {
        final initialMapping = _mapping;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(universalImportNotifierProvider.notifier)
                .updateFieldMapping(initialMapping);
          }
        });
      }
    }

    if (!_initialized) return const SizedBox.shrink();

    final headers = state.detectionResult?.csvHeaders ?? [];

    // With no columns there is nothing to map, and the preset and save
    // controls act on an empty list. Rendering the normal editor here is what
    // produced the reported "Column Mapping / 0 of 0 columns mapped" dead end,
    // so say what happened instead.
    if (headers.isEmpty) {
      // ...unless nothing went wrong. A non-CSV file never has csvHeaders, and
      // the wizard skips this step once a payload exists -- but PageView
      // builds and mounts every page it animates over, so a successful UDDF
      // import renders this step during the sweep to review. Stay silent for
      // that frame rather than flashing an error at a working import.
      if (state.payload != null) return const SizedBox.shrink();
      return _NoColumnsNotice(error: state.error);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.universalImport_label_columnMapping,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showSelectPresetSheet(headers),
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    label: Text(
                      context.l10n.universalImport_preset_presetsButton,
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _mapping.columns.isNotEmpty
                        ? () => _showSavePresetDialog(headers)
                        : null,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text(context.l10n.common_action_save),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.universalImport_label_columnsMapped(
                  _mapping.columns.length,
                  headers.length,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: headers.length,
            itemBuilder: (context, index) {
              final header = headers[index];
              final existingMapping = _mapping.columns.where(
                (c) => c.sourceColumn.toLowerCase() == header.toLowerCase(),
              );
              final currentTarget = existingMapping.isNotEmpty
                  ? existingMapping.first.targetField
                  : null;

              return _ColumnMappingRow(
                sourceColumn: header,
                currentTarget: currentTarget,
                targetFields: _targetFields,
                onChanged: (target) => _updateMapping(header, target),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showSelectPresetSheet(List<String> headers) async {
    final preset = await showModalBottomSheet<CsvPreset>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SelectPresetSheet(csvHeaders: headers),
    );
    if (preset == null || !mounted) return;

    final mapping = preset.primaryMapping;
    if (mapping == null) return;

    setState(() => _mapping = mapping);
    ref
        .read(universalImportNotifierProvider.notifier)
        .updateFieldMapping(mapping);
  }

  Future<void> _showSavePresetDialog(List<String> headers) async {
    final state = ref.read(universalImportNotifierProvider);
    final preset = await showDialog<CsvPreset>(
      context: context,
      builder: (_) => SavePresetDialog(
        mapping: _mapping,
        csvHeaders: headers,
        detectedSourceApp: state.options?.sourceApp,
        currentEntityTypes:
            state.detectedCsvPreset?.supportedEntities ??
            const {ImportEntityType.dives, ImportEntityType.sites},
      ),
    );
    if (preset == null || !mounted) return;

    final repo = ref.read(csvPresetRepositoryProvider);
    await repo.savePreset(preset);
    ref.invalidate(userCsvPresetsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.universalImport_preset_savedSnackbar(preset.name),
          ),
        ),
      );
    }
  }

  void _updateMapping(String sourceColumn, String? targetField) {
    final updated = _mapping.columns
        .where(
          (c) => c.sourceColumn.toLowerCase() != sourceColumn.toLowerCase(),
        )
        .toList();

    if (targetField != null) {
      updated.add(
        ColumnMapping(sourceColumn: sourceColumn, targetField: targetField),
      );
    }

    final newMapping = FieldMapping(
      name: _mapping.name,
      sourceApp: _mapping.sourceApp,
      columns: updated,
    );

    setState(() {
      _mapping = newMapping;
    });

    // Persist to the notifier so the wizard's onBeforeAdvance callback
    // can call confirmFieldMapping() with the current mapping already saved.
    ref
        .read(universalImportNotifierProvider.notifier)
        .updateFieldMapping(newMapping);
  }
}

/// Shown in place of the mapping editor when the file yielded no columns.
///
/// Reached when a parse failed upstream (so the wizard has no payload to skip
/// this step with) or when a CSV was detected without a usable header row.
/// [error] carries whatever the notifier recorded about the failure.
class _NoColumnsNotice extends StatelessWidget {
  const _NoColumnsNotice({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.universalImport_error_noColumnsToMap,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnMappingRow extends StatelessWidget {
  const _ColumnMappingRow({
    required this.sourceColumn,
    required this.currentTarget,
    required this.targetFields,
    required this.onChanged,
  });

  final String sourceColumn;
  final String? currentTarget;
  final List<String> targetFields;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              sourceColumn,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: Icon(
              Icons.arrow_forward,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey('$sourceColumn-$currentTarget'),
              initialValue: currentTarget,
              isDense: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                hintText: context.l10n.universalImport_label_skip,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(context.l10n.universalImport_label_skip),
                ),
                for (final field in targetFields)
                  DropdownMenuItem(
                    value: field,
                    child: Text(_displayFieldName(field)),
                  ),
                // Include the current target if it's not in the standard list
                // (e.g. from a user-saved preset with custom field names).
                if (currentTarget != null &&
                    !targetFields.contains(currentTarget))
                  DropdownMenuItem(
                    value: currentTarget,
                    child: Text(_displayFieldName(currentTarget!)),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _displayFieldName(String field) {
    // Convert camelCase to readable form
    return field.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
  }
}
