import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/services/field_mapping_engine.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

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
    'buddy',
    'diveMaster',
    'rating',
    'notes',
    'visibility',
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
      // Auto-generate mapping from detected headers
      final detection = state.detectionResult;
      const engine = FieldMappingEngine();
      _mapping =
          state.fieldMapping ??
          engine.autoMap(
            detection?.csvHeaders ?? [],
            sourceApp: state.options!.sourceApp,
          );
      _initialized = true;
    }

    if (!_initialized) return const SizedBox.shrink();

    final headers = state.detectionResult?.csvHeaders ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.universalImport_label_columnMapping,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _mapping.columns.isNotEmpty
                  ? () {
                      ref
                          .read(universalImportNotifierProvider.notifier)
                          .updateFieldMapping(_mapping);
                      ref
                          .read(universalImportNotifierProvider.notifier)
                          .confirmFieldMapping();
                    }
                  : null,
              child: Text(context.l10n.universalImport_action_continue),
            ),
          ),
        ),
      ],
    );
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

    setState(() {
      _mapping = FieldMapping(
        name: _mapping.name,
        sourceApp: _mapping.sourceApp,
        columns: updated,
      );
    });
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
