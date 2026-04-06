import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class ColumnConfigPage extends ConsumerStatefulWidget {
  /// When true, hides the Scaffold/AppBar for embedding in a detail pane.
  final bool embedded;

  const ColumnConfigPage({super.key, this.embedded = false});

  @override
  ConsumerState<ColumnConfigPage> createState() => _ColumnConfigPageState();
}

class _ColumnConfigPageState extends ConsumerState<ColumnConfigPage> {
  ListViewMode _selectedMode = ListViewMode.table;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Text(context.l10n.columnConfig_viewMode),
              const SizedBox(width: 16),
              DropdownButton<ListViewMode>(
                value: _selectedMode,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMode = value);
                  }
                },
                items:
                    const [
                      ListViewMode.table,
                      ListViewMode.detailed,
                      ListViewMode.compact,
                    ].map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_modeDisplayName(mode)),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(child: _buildModeSection()),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.columnConfig_title)),
      body: body,
    );
  }

  Widget _buildModeSection() {
    switch (_selectedMode) {
      case ListViewMode.table:
        return const _TableColumnConfigSection();
      case ListViewMode.detailed:
        return const _DetailedCardConfigSection();
      case ListViewMode.compact:
        return const _SlotCardConfigSection(
          mode: ListViewMode.compact,
          key: ValueKey(ListViewMode.compact),
        );
      case ListViewMode.dense:
        return const _SlotCardConfigSection(
          mode: ListViewMode.dense,
          key: ValueKey(ListViewMode.dense),
        );
    }
  }

  String _modeDisplayName(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.table => 'Table',
      ListViewMode.detailed => 'Detailed',
      ListViewMode.compact => 'Compact',
      ListViewMode.dense => 'Dense',
    };
  }
}

// ---------------------------------------------------------------------------
// Table mode section
// ---------------------------------------------------------------------------

class _TableColumnConfigSection extends ConsumerWidget {
  const _TableColumnConfigSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final notifier = ref.read(tableViewConfigProvider.notifier);
    final theme = Theme.of(context);
    final visibleFields = config.columns.map((c) => c.field).toSet();
    const allFields = DiveField.values;
    final availableFields = allFields
        .where((f) => !visibleFields.contains(f))
        .toList();

    // Group available fields by category
    final Map<DiveFieldCategory, List<DiveField>> grouped = {};
    for (final field in availableFields) {
      grouped.putIfAbsent(field.category, () => []).add(field);
    }

    final diverId = ref.watch(currentDiverIdProvider);
    final presetsAsync = diverId != null
        ? ref.watch(tablePresetsProvider(diverId))
        : const AsyncValue<List<FieldPreset>>.data([]);
    final presets = presetsAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<FieldPreset>(
                  hint: const Text('Load Preset'),
                  isExpanded: true,
                  value: null,
                  onChanged: (preset) {
                    if (preset != null) {
                      notifier.applyPreset(preset);
                    }
                  },
                  items: presets.map((preset) {
                    return DropdownMenuItem<FieldPreset>(
                      value: preset,
                      child: Row(
                        children: [
                          Expanded(child: Text(preset.name)),
                          if (!preset.isBuiltIn)
                            GestureDetector(
                              onTap: () {
                                if (diverId != null) {
                                  ref
                                      .read(viewConfigRepositoryProvider)
                                      .deletePreset(preset.id);
                                  ref.invalidate(tablePresetsProvider(diverId));
                                }
                              },
                              child: const Icon(Icons.delete_outline, size: 18),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showSavePresetDialog(context, ref, diverId),
                child: const Text('Save As'),
              ),
            ],
          ),
        ),
        _SectionHeader(
          title: context.l10n.columnConfig_visibleColumns.toUpperCase(),
          theme: theme,
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: config.columns.length,
                  onReorder: notifier.reorderColumn,
                  itemBuilder: (context, index) {
                    final col = config.columns[index];
                    return ListTile(
                      key: ValueKey(col.field),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(col.field.displayName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              col.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                            ),
                            tooltip: col.isPinned ? 'Unpin' : 'Pin',
                            onPressed: () => notifier.togglePin(col.field),
                          ),
                          if (!col.isPinned)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Remove',
                              onPressed: () => notifier.toggleColumn(col.field),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              _SectionHeader(
                title: context.l10n.columnConfig_availableFields.toUpperCase(),
                theme: theme,
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final category in DiveFieldCategory.values)
                      if (grouped.containsKey(category)) ...[
                        _CategoryHeader(
                          label: category.name.toUpperCase(),
                          theme: theme,
                        ),
                        for (final field in grouped[category]!)
                          ListTile(
                            title: Text(field.displayName),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add',
                              onPressed: () => notifier.toggleColumn(field),
                            ),
                          ),
                      ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () {
                    notifier.replaceConfig(TableViewConfig.defaultConfig());
                  },
                  child: Text(context.l10n.columnConfig_resetToDefault),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Save preset dialog helper
// ---------------------------------------------------------------------------

void _showSavePresetDialog(
  BuildContext context,
  WidgetRef ref,
  String? diverId,
) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save Preset'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Preset Name',
          hintText: 'e.g., Tech Diving',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty && diverId != null) {
              final config = ref.read(tableViewConfigProvider);
              final preset = FieldPreset(
                id: const Uuid().v4(),
                name: name,
                viewMode: ListViewMode.table,
                configJson: config.toJson(),
              );
              ref
                  .read(viewConfigRepositoryProvider)
                  .savePreset(diverId, preset);
              ref.invalidate(tablePresetsProvider(diverId));
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Detailed card mode section
// ---------------------------------------------------------------------------

class _DetailedCardConfigSection extends ConsumerWidget {
  const _DetailedCardConfigSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(detailedCardConfigProvider);
    final notifier = ref.read(detailedCardConfigProvider.notifier);
    final theme = Theme.of(context);

    final extraFieldSet = config.extraFields.toSet();
    final available = DiveField.values
        .where((f) => !extraFieldSet.contains(f))
        .toList();

    // Group available fields by category
    final Map<DiveFieldCategory, List<DiveField>> grouped = {};
    for (final field in available) {
      grouped.putIfAbsent(field.category, () => []).add(field);
    }

    return ListView(
      children: [
        // -- Slot assignments (fixed card area) --
        _SectionHeader(title: 'SLOT ASSIGNMENTS', theme: theme),
        ...config.slots.map((slot) {
          return ListTile(
            title: Text(_slotDisplayName(slot.slotId)),
            trailing: DropdownButton<DiveField>(
              value: slot.field,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  notifier.updateSlot(slot.slotId, value);
                }
              },
              items: DiveField.values.map((field) {
                return DropdownMenuItem(
                  value: field,
                  child: Text(field.displayName),
                );
              }).toList(),
            ),
          );
        }),

        const Divider(),

        // -- Extra fields (flexible area below card) --
        _SectionHeader(title: 'EXTRA FIELDS', theme: theme),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Additional fields shown below the standard card content.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...config.extraFields.asMap().entries.map((entry) {
          final field = entry.value;
          return ListTile(
            key: ValueKey(field),
            title: Text(field.displayName),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove',
              onPressed: () => notifier.removeExtraField(field),
            ),
          );
        }),
        if (config.extraFields.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No extra fields configured. Add fields below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        const Divider(),

        // -- Available fields to add --
        _SectionHeader(
          title: context.l10n.columnConfig_availableFields.toUpperCase(),
          theme: theme,
        ),
        for (final category in DiveFieldCategory.values)
          if (grouped.containsKey(category)) ...[
            _CategoryHeader(label: category.name.toUpperCase(), theme: theme),
            for (final field in grouped[category]!)
              ListTile(
                title: Text(field.displayName),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add',
                  onPressed: () => notifier.addExtraField(field),
                ),
              ),
          ],

        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(
            onPressed: notifier.resetToDefault,
            child: const Text('Reset to Default'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _slotDisplayName(String slotId) {
    return switch (slotId) {
      'title' => 'Title',
      'date' => 'Date / Subtitle',
      'stat1' => 'Stat 1',
      'stat2' => 'Stat 2',
      _ => slotId,
    };
  }
}

// ---------------------------------------------------------------------------
// Slot card mode section (Compact and Dense)
// ---------------------------------------------------------------------------

class _SlotCardConfigSection extends ConsumerWidget {
  final ListViewMode mode;

  const _SlotCardConfigSection({required this.mode, super.key});

  StateNotifierProvider<CardViewConfigNotifier, CardViewConfig> get _provider {
    return switch (mode) {
      ListViewMode.compact => compactCardConfigProvider,
      ListViewMode.dense => denseCardConfigProvider,
      _ => compactCardConfigProvider,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);
    final theme = Theme.of(context);
    const allFields = DiveField.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'SLOT ASSIGNMENTS', theme: theme),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: config.slots.map((slot) {
                    return ListTile(
                      title: Text(_slotDisplayName(slot.slotId)),
                      trailing: DropdownButton<DiveField>(
                        value: slot.field,
                        underline: const SizedBox(),
                        onChanged: (value) {
                          if (value != null) {
                            notifier.updateSlot(slot.slotId, value);
                          }
                        },
                        items: allFields.map((field) {
                          return DropdownMenuItem(
                            value: field,
                            child: Text(field.displayName),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: notifier.resetToDefault,
                  child: Text(context.l10n.columnConfig_resetToDefault),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _slotDisplayName(String slotId) {
    return switch (slotId) {
      'title' => 'Title',
      'date' => 'Date / Subtitle',
      'stat1' => 'Stat 1',
      'stat2' => 'Stat 2',
      'slot1' => 'Slot 1',
      'slot2' => 'Slot 2',
      'slot3' => 'Slot 3',
      'slot4' => 'Slot 4',
      _ => slotId,
    };
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _CategoryHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
