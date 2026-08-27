import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

// ---------------------------------------------------------------------------
// Section metadata
// ---------------------------------------------------------------------------

/// All configurable entity sections, in dropdown order.
///
/// Labels resolve through [_sectionDisplayName] so the picker follows the app
/// language instead of hard-coded English.
const _sectionKeys = [
  'dives',
  'sites',
  'buddies',
  'trips',
  'equipment',
  'diveCenters',
  'certifications',
  'courses',
];

String _sectionDisplayName(BuildContext context, String key) {
  final l10n = context.l10n;
  return switch (key) {
    'dives' => l10n.nav_dives,
    'sites' => l10n.nav_sites,
    'buddies' => l10n.nav_buddies,
    'trips' => l10n.nav_trips,
    'equipment' => l10n.nav_equipment,
    'diveCenters' => l10n.nav_diveCenters,
    'certifications' => l10n.nav_certifications,
    'courses' => l10n.nav_courses,
    _ => key,
  };
}

class ColumnConfigPage extends ConsumerStatefulWidget {
  /// When true, hides the Scaffold/AppBar for embedding in a detail pane.
  final bool embedded;

  /// When set, pre-selects this section and hides the section dropdown.
  final String? initialSection;

  const ColumnConfigPage({
    super.key,
    this.embedded = false,
    this.initialSection,
  });

  @override
  ConsumerState<ColumnConfigPage> createState() => _ColumnConfigPageState();
}

class _ColumnConfigPageState extends ConsumerState<ColumnConfigPage> {
  late String _selectedSection = widget.initialSection ?? 'dives';
  ListViewMode _selectedMode = ListViewMode.table;

  List<ListViewMode> _availableModes() {
    return switch (_selectedSection) {
      'certifications' ||
      'courses' => [ListViewMode.table, ListViewMode.detailed],
      _ => [ListViewMode.table, ListViewMode.detailed, ListViewMode.compact],
    };
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section selector — hidden when a specific section is pre-selected
        if (widget.initialSection == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(context.l10n.columnConfig_section),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedSection,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSection = value;
                        // Reset mode if current isn't available for new section
                        final available = _availableModes();
                        if (!available.contains(_selectedMode)) {
                          _selectedMode = ListViewMode.table;
                        }
                      });
                    }
                  },
                  items: _sectionKeys.map((key) {
                    return DropdownMenuItem(
                      value: key,
                      child: Text(_sectionDisplayName(context, key)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        // View mode selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                items: _availableModes().map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(_modeDisplayName(context, mode)),
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
    if (_selectedSection == 'dives') {
      return _buildDivesModeSection();
    }
    return _buildEntityModeSection();
  }

  /// Dives use the original Dives-specific config widgets unchanged.
  Widget _buildDivesModeSection() {
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

  /// Other sections use the generic EntityTableViewConfig / EntityCardViewConfig
  /// infrastructure.
  Widget _buildEntityModeSection() {
    switch (_selectedMode) {
      case ListViewMode.table:
        return _buildEntityTableSection();
      case ListViewMode.detailed:
        return _buildEntityCardSection(detailed: true);
      case ListViewMode.compact:
        return _buildEntityCardSection(detailed: false);
      case ListViewMode.dense:
        // Should not be reachable, but fall back to compact
        return _buildEntityCardSection(detailed: false);
    }
  }

  Widget _buildEntityTableSection() {
    return switch (_selectedSection) {
      'sites' => _EntityTableConfigSection<SiteField>(
        configProvider: siteTableConfigProvider,
        allFields: SiteField.values,
        fieldsByCategory: SiteFieldAdapter.instance.fieldsByCategory,
      ),
      'buddies' => _EntityTableConfigSection<BuddyField>(
        configProvider: buddyTableConfigProvider,
        allFields: BuddyField.values,
        fieldsByCategory: BuddyFieldAdapter.instance.fieldsByCategory,
      ),
      'trips' => _EntityTableConfigSection<TripField>(
        configProvider: tripTableConfigProvider,
        allFields: TripField.values,
        fieldsByCategory: TripFieldAdapter.instance.fieldsByCategory,
      ),
      'equipment' => _EntityTableConfigSection<EquipmentField>(
        configProvider: equipmentTableConfigProvider,
        allFields: EquipmentField.values,
        fieldsByCategory: EquipmentFieldAdapter.instance.fieldsByCategory,
      ),
      'diveCenters' => _EntityTableConfigSection<DiveCenterField>(
        configProvider: diveCenterTableConfigProvider,
        allFields: DiveCenterField.values,
        fieldsByCategory: DiveCenterFieldAdapter.instance.fieldsByCategory,
      ),
      'certifications' => _EntityTableConfigSection<CertificationField>(
        configProvider: certificationTableConfigProvider,
        allFields: CertificationField.values,
        fieldsByCategory: CertificationFieldAdapter.instance.fieldsByCategory,
      ),
      'courses' => _EntityTableConfigSection<CourseField>(
        configProvider: courseTableConfigProvider,
        allFields: CourseField.values,
        fieldsByCategory: CourseFieldAdapter.instance.fieldsByCategory,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildEntityCardSection({required bool detailed}) {
    return switch (_selectedSection) {
      'sites' => _EntityCardConfigSection<SiteField>(
        configProvider: detailed
            ? siteDetailedCardConfigProvider
            : siteCompactCardConfigProvider,
        onChanged: (ref, config) => ref
            .read(
              (detailed
                      ? siteDetailedCardConfigProvider
                      : siteCompactCardConfigProvider)
                  .notifier,
            )
            .replace(config),
        allFields: SiteField.values,
        fieldsByCategory: SiteFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'buddies' => _EntityCardConfigSection<BuddyField>(
        configProvider: detailed
            ? buddyDetailedCardConfigProvider
            : buddyCompactCardConfigProvider,
        onChanged: (ref, config) => ref
            .read(
              (detailed
                      ? buddyDetailedCardConfigProvider
                      : buddyCompactCardConfigProvider)
                  .notifier,
            )
            .replace(config),
        allFields: BuddyField.values,
        fieldsByCategory: BuddyFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'trips' => _EntityCardConfigSection<TripField>(
        configProvider: detailed
            ? tripDetailedCardConfigProvider
            : tripCompactCardConfigProvider,
        onChanged: (ref, config) =>
            ref
                    .read(
                      (detailed
                              ? tripDetailedCardConfigProvider
                              : tripCompactCardConfigProvider)
                          .notifier,
                    )
                    .state =
                config,
        allFields: TripField.values,
        fieldsByCategory: TripFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'equipment' => _EntityCardConfigSection<EquipmentField>(
        configProvider: detailed
            ? equipmentDetailedCardConfigProvider
            : equipmentCompactCardConfigProvider,
        onChanged: (ref, config) =>
            ref
                    .read(
                      (detailed
                              ? equipmentDetailedCardConfigProvider
                              : equipmentCompactCardConfigProvider)
                          .notifier,
                    )
                    .state =
                config,
        allFields: EquipmentField.values,
        fieldsByCategory: EquipmentFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'diveCenters' => _EntityCardConfigSection<DiveCenterField>(
        configProvider: detailed
            ? diveCenterDetailedCardConfigProvider
            : diveCenterCompactCardConfigProvider,
        onChanged: (ref, config) =>
            ref
                    .read(
                      (detailed
                              ? diveCenterDetailedCardConfigProvider
                              : diveCenterCompactCardConfigProvider)
                          .notifier,
                    )
                    .state =
                config,
        allFields: DiveCenterField.values,
        fieldsByCategory: DiveCenterFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'certifications' => _EntityCardConfigSection<CertificationField>(
        configProvider: certificationDetailedCardConfigProvider,
        onChanged: (ref, config) =>
            ref.read(certificationDetailedCardConfigProvider.notifier).state =
                config,
        allFields: CertificationField.values,
        fieldsByCategory: CertificationFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'courses' => _EntityCardConfigSection<CourseField>(
        configProvider: courseDetailedCardConfigProvider,
        onChanged: (ref, config) =>
            ref.read(courseDetailedCardConfigProvider.notifier).state = config,
        allFields: CourseField.values,
        fieldsByCategory: CourseFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  String _modeDisplayName(BuildContext context, ListViewMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      ListViewMode.table => l10n.enum_listViewMode_table,
      ListViewMode.detailed => l10n.enum_listViewMode_detailed,
      ListViewMode.compact => l10n.enum_listViewMode_compact,
      ListViewMode.dense => l10n.enum_listViewMode_dense,
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
                  hint: Text(context.l10n.columnConfig_preset),
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
                child: Text(context.l10n.columnConfig_presetSaveAs),
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
                  onReorderItem: notifier.reorderColumn,
                  itemBuilder: (context, index) {
                    final col = config.columns[index];
                    return ListTile(
                      key: ValueKey(col.field),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(col.field.localizedDisplayName(context.l10n)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              col.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                            ),
                            tooltip: col.isPinned
                                ? context.l10n.common_action_unpin
                                : context.l10n.common_action_pin,
                            onPressed: () => notifier.togglePin(col.field),
                          ),
                          if (!col.isPinned)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: context.l10n.common_action_remove,
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
                          label: localizedFieldCategory(
                            context.l10n,
                            category.name,
                          ).toUpperCase(),
                          theme: theme,
                        ),
                        for (final field in grouped[category]!)
                          ListTile(
                            title: Text(
                              field.localizedDisplayName(context.l10n),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: context.l10n.common_action_add,
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
      title: Text(context.l10n.columnConfig_savePresetTitle),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: context.l10n.columnConfig_presetName,
          hintText: context.l10n.columnConfig_presetNameHint,
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.columnConfig_presetCancel),
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
          child: Text(context.l10n.columnConfig_presetSave),
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
        // -- Display options (card-wide toggles) --
        _SectionHeader(
          title: context.l10n.columnConfig_displayOptions.toUpperCase(),
          theme: theme,
        ),
        SwitchListTile(
          title: Text(context.l10n.columnConfig_showTags),
          subtitle: Text(context.l10n.columnConfig_showTags_subtitle),
          value: config.showTags,
          onChanged: notifier.setShowTags,
        ),

        const Divider(),

        // -- Slot assignments (fixed card area) --
        _SectionHeader(
          title: context.l10n.columnConfig_slotAssignments.toUpperCase(),
          theme: theme,
        ),
        ...config.slots.map((slot) {
          return ListTile(
            title: Text(_slotDisplayName(context, slot.slotId)),
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
                  child: Text(field.localizedDisplayName(context.l10n)),
                );
              }).toList(),
            ),
          );
        }),

        const Divider(),

        // -- Extra fields (flexible area below card) --
        _SectionHeader(
          title: context.l10n.columnConfig_extraFields.toUpperCase(),
          theme: theme,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            context.l10n.columnConfig_extraFields_description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...config.extraFields.asMap().entries.map((entry) {
          final field = entry.value;
          return ListTile(
            key: ValueKey(field),
            title: Text(field.localizedDisplayName(context.l10n)),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: context.l10n.common_action_remove,
              onPressed: () => notifier.removeExtraField(field),
            ),
          );
        }),
        if (config.extraFields.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.columnConfig_noExtraFields,
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
            _CategoryHeader(
              label: localizedFieldCategory(
                context.l10n,
                category.name,
              ).toUpperCase(),
              theme: theme,
            ),
            for (final field in grouped[category]!)
              ListTile(
                title: Text(field.localizedDisplayName(context.l10n)),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: context.l10n.common_action_add,
                  onPressed: () => notifier.addExtraField(field),
                ),
              ),
          ],

        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(
            onPressed: notifier.resetToDefault,
            child: Text(context.l10n.columnConfig_resetToDefault),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _slotDisplayName(BuildContext context, String slotId) {
    final l10n = context.l10n;
    return switch (slotId) {
      'title' => l10n.columnConfig_slot_title,
      'date' => l10n.columnConfig_slot_date,
      'stat1' => l10n.columnConfig_slot_stat1,
      'stat2' => l10n.columnConfig_slot_stat2,
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
        _SectionHeader(
          title: context.l10n.columnConfig_slotAssignments.toUpperCase(),
          theme: theme,
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: config.slots.map((slot) {
                    return ListTile(
                      title: Text(_slotDisplayName(context, slot.slotId)),
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
                            child: Text(
                              field.localizedDisplayName(context.l10n),
                            ),
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

  String _slotDisplayName(BuildContext context, String slotId) {
    final l10n = context.l10n;
    return switch (slotId) {
      'title' => l10n.columnConfig_slot_title,
      'date' => l10n.columnConfig_slot_date,
      'stat1' => l10n.columnConfig_slot_stat1,
      'stat2' => l10n.columnConfig_slot_stat2,
      'slot1' => l10n.columnConfig_slot_slot1,
      'slot2' => l10n.columnConfig_slot_slot2,
      'slot3' => l10n.columnConfig_slot_slot3,
      'slot4' => l10n.columnConfig_slot_slot4,
      _ => slotId,
    };
  }
}

// ---------------------------------------------------------------------------
// Generic entity table config section
// ---------------------------------------------------------------------------

class _EntityTableConfigSection<F extends EntityField> extends ConsumerWidget {
  final StateNotifierProvider<
    EntityTableConfigNotifier<F>,
    EntityTableViewConfig<F>
  >
  configProvider;
  final List<F> allFields;
  final Map<String, List<F>> fieldsByCategory;

  const _EntityTableConfigSection({
    required this.configProvider,
    required this.allFields,
    required this.fieldsByCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final notifier = ref.read(configProvider.notifier);
    final theme = Theme.of(context);
    final visibleFields = config.columns.map((c) => c.field).toSet();
    final availableFields = allFields
        .where((f) => !visibleFields.contains(f))
        .toList();

    // Group available fields by category
    final Map<String, List<F>> grouped = {};
    for (final field in availableFields) {
      grouped.putIfAbsent(field.categoryName, () => []).add(field);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  onReorderItem: notifier.reorderColumn,
                  itemBuilder: (context, index) {
                    final col = config.columns[index];
                    return ListTile(
                      key: ValueKey(col.field.name),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(col.field.localizedDisplayName(context.l10n)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              col.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                            ),
                            tooltip: col.isPinned
                                ? context.l10n.common_action_unpin
                                : context.l10n.common_action_pin,
                            onPressed: () => notifier.togglePin(col.field),
                          ),
                          if (!col.isPinned)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: context.l10n.common_action_remove,
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
                    for (final category in fieldsByCategory.keys)
                      if (grouped.containsKey(category)) ...[
                        _CategoryHeader(
                          label: localizedFieldCategory(
                            context.l10n,
                            category,
                          ).toUpperCase(),
                          theme: theme,
                        ),
                        for (final field in grouped[category]!)
                          ListTile(
                            title: Text(
                              field.localizedDisplayName(context.l10n),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: context.l10n.common_action_add,
                              onPressed: () => notifier.toggleColumn(field),
                            ),
                          ),
                      ],
                  ],
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
// Generic entity card config section
// ---------------------------------------------------------------------------

class _EntityCardConfigSection<F extends EntityField> extends ConsumerWidget {
  /// Read source. A `StateProvider` for the entities whose card config is
  /// still in-memory, a `StateNotifierProvider` for the persisted ones.
  final ProviderListenable<EntityCardViewConfig<F>> configProvider;

  /// Write sink; the section edits a copy and hands it back here.
  final void Function(WidgetRef ref, EntityCardViewConfig<F> config) onChanged;
  final List<F> allFields;
  final Map<String, List<F>> fieldsByCategory;
  final bool showExtraFields;

  const _EntityCardConfigSection({
    required this.configProvider,
    required this.onChanged,
    required this.allFields,
    required this.fieldsByCategory,
    required this.showExtraFields,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final theme = Theme.of(context);

    return ListView(
      children: [
        _SectionHeader(
          title: context.l10n.columnConfig_slotAssignments.toUpperCase(),
          theme: theme,
        ),
        ...config.slots.map((slot) {
          return ListTile(
            title: Text(_slotDisplayName(context, slot.slotId)),
            trailing: DropdownButton<F>(
              value: slot.field,
              underline: const SizedBox(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(
                    ref,
                    config.copyWith(
                      slots: config.slots
                          .map(
                            (s) => s.slotId == slot.slotId
                                ? s.copyWith(field: value)
                                : s,
                          )
                          .toList(),
                    ),
                  );
                }
              },
              items: allFields.map((field) {
                return DropdownMenuItem(
                  value: field,
                  child: Text(field.localizedDisplayName(context.l10n)),
                );
              }).toList(),
            ),
          );
        }),

        if (showExtraFields) ...[
          const Divider(),
          _SectionHeader(
            title: context.l10n.columnConfig_extraFields.toUpperCase(),
            theme: theme,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              context.l10n.columnConfig_extraFields_description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...config.extraFields.map((field) {
            return ListTile(
              key: ValueKey(field.name),
              title: Text(field.localizedDisplayName(context.l10n)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: context.l10n.common_action_remove,
                onPressed: () {
                  onChanged(
                    ref,
                    config.copyWith(
                      extraFields: config.extraFields
                          .where((f) => f != field)
                          .toList(),
                    ),
                  );
                },
              ),
            );
          }),
          if (config.extraFields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.l10n.columnConfig_noExtraFields,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Divider(),
          _SectionHeader(
            title: context.l10n.columnConfig_availableFields.toUpperCase(),
            theme: theme,
          ),
          for (final category in fieldsByCategory.keys)
            if (_availableInCategory(config, category).isNotEmpty) ...[
              _CategoryHeader(
                label: localizedFieldCategory(
                  context.l10n,
                  category,
                ).toUpperCase(),
                theme: theme,
              ),
              for (final field in _availableInCategory(config, category))
                ListTile(
                  title: Text(field.localizedDisplayName(context.l10n)),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: context.l10n.common_action_add,
                    onPressed: () {
                      onChanged(
                        ref,
                        config.copyWith(
                          extraFields: [...config.extraFields, field],
                        ),
                      );
                    },
                  ),
                ),
            ],
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  List<F> _availableInCategory(
    EntityCardViewConfig<F> config,
    String category,
  ) {
    final extraSet = config.extraFields.toSet();
    return (fieldsByCategory[category] ?? [])
        .where((f) => !extraSet.contains(f))
        .toList();
  }

  String _slotDisplayName(BuildContext context, String slotId) {
    final l10n = context.l10n;
    return switch (slotId) {
      'title' => l10n.columnConfig_slot_title,
      'subtitle' => l10n.columnConfig_slot_subtitle,
      'date' => l10n.columnConfig_slot_date,
      'stat1' => l10n.columnConfig_slot_stat1,
      'stat2' => l10n.columnConfig_slot_stat2,
      'slot1' => l10n.columnConfig_slot_slot1,
      'slot2' => l10n.columnConfig_slot_slot2,
      'slot3' => l10n.columnConfig_slot_slot3,
      'slot4' => l10n.columnConfig_slot_slot4,
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
