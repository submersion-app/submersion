import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One row of a section, or one option of its picker.
typedef _Entry = ({String id, String title, String? subtitle});

/// The comma-separated headline of a bundle: gear count, lead and cylinder
/// count, leaving out what the bundle does not have.
String setBundleSummaryText(
  AppLocalizations l10n,
  UnitFormatter units, {
  required int gearCount,
  required double leadKg,
  required int cylinderCount,
}) => [
  if (gearCount > 0)
    gearCount == 1
        ? l10n.equipment_sets_itemCountSingular(gearCount)
        : l10n.equipment_sets_itemCountPlural(gearCount),
  if (leadKg > 0) l10n.equipment_sets_leadTotal(units.formatWeight(leadKg)),
  if (cylinderCount > 0) l10n.equipment_sets_cylinderCount(cylinderCount),
].join(', ');

/// The set editor's sections for what a set carries besides its own gear
/// (issue #4525): the sets it includes, its weight presets and its cylinder
/// configurations. Each list can be added to, removed from and reordered.
///
/// Stateless about the lists: [values] comes in and every change goes out
/// through [onChanged], so the page's unsaved-changes check sees it.
class SetBundleSections extends ConsumerWidget {
  const SetBundleSections({
    super.key,
    required this.setId,
    required this.diverId,
    required this.ownGearIds,
    required this.values,
    required this.onChanged,
  });

  /// The set being edited, '' for a new one.
  final String setId;
  final String? diverId;

  /// The gear ticked in the form, for the total line.
  final Set<String> ownGearIds;
  final SetBundleListValues values;
  final ValueChanged<SetBundleListValues> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final sets = ref.watch(equipmentSetsProvider).valueOrNull ?? const [];
    final presets = ref.watch(weightPresetsProvider).valueOrNull ?? const [];
    final configs = ref.watch(cylinderConfigsProvider).valueOrNull ?? const [];

    final setsById = {for (final s in sets) s.id: s};
    final presetsById = {for (final p in presets) p.id: p};
    final configsById = {for (final c in configs) c.id: c};

    // The set as the form would save it, to resolve what it applies.
    final now = DateTime.now();
    final draft = EquipmentSet(
      id: setId,
      diverId: diverId,
      name: '',
      equipmentIds: ownGearIds.toList(),
      includedSetIds: values.includedSetIds,
      weightPresetIds: values.weightPresetIds,
      cylinderConfigIds: values.cylinderConfigIds,
      createdAt: now,
      updatedAt: now,
    );
    final bundle = SetBundleResolver.resolve(
      draft,
      setsById: {...setsById, setId: draft},
      presetsById: presetsById,
      configsById: configsById,
    );

    _Entry setEntry(EquipmentSet s) => (
      id: s.id,
      title: s.name,
      subtitle: _itemCount(l10n, s.equipmentIds.length),
    );
    _Entry presetEntry(WeightPreset p) => (
      id: p.id,
      title: p.displayName,
      subtitle: units.formatWeight(p.totalKg),
    );
    _Entry configEntry(CylinderConfig c) => (
      id: c.id,
      title: c.name,
      subtitle: l10n.equipment_sets_cylinderCount(c.cylinderCount),
    );

    final includable = [
      for (final s in sets)
        if (!values.includedSetIds.contains(s.id) &&
            SetBundleResolver.canInclude(draft, s, sets))
          setEntry(s),
    ];

    final ownLeadKg = values.weightPresetIds.fold<double>(
      0,
      (sum, id) => sum + (presetsById[id]?.totalKg ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          kind: 'includes',
          title: l10n.equipment_setEdit_includedSets_title,
          addLabel: l10n.equipment_setEdit_includedSets_add,
          emptyText: l10n.equipment_setEdit_includedSets_empty,
          noOptionsText: l10n.equipment_setEdit_includedSets_noneAvailable,
          icon: Icons.layers_outlined,
          entries: [
            for (final id in values.includedSetIds)
              if (setsById[id] case final s?) setEntry(s),
          ],
          options: includable,
          ids: values.includedSetIds,
          onChanged: (ids) => onChanged(values.copyWith(includedSetIds: ids)),
        ),
        const SizedBox(height: 16),
        _Section(
          kind: 'presets',
          title: l10n.equipment_setEdit_weights_title,
          trailing: ownLeadKg > 0
              ? l10n.equipment_setEdit_weights_total(
                  units.formatWeight(ownLeadKg),
                )
              : null,
          addLabel: l10n.equipment_setEdit_weights_add,
          emptyText: l10n.equipment_setEdit_weights_empty,
          noOptionsText: l10n.equipment_setEdit_weights_empty,
          icon: Icons.fitness_center,
          entries: [
            for (final id in values.weightPresetIds)
              if (presetsById[id] case final p?) presetEntry(p),
          ],
          options: [
            for (final p in presets)
              if (!values.weightPresetIds.contains(p.id)) presetEntry(p),
          ],
          ids: values.weightPresetIds,
          onChanged: (ids) => onChanged(values.copyWith(weightPresetIds: ids)),
        ),
        const SizedBox(height: 16),
        _Section(
          kind: 'configs',
          title: l10n.equipment_setEdit_tanks_title,
          addLabel: l10n.equipment_setEdit_tanks_add,
          emptyText: l10n.equipment_setEdit_tanks_empty,
          noOptionsText: l10n.equipment_setEdit_tanks_noneAvailable,
          icon: Icons.propane_tank_outlined,
          entries: [
            for (final id in values.cylinderConfigIds)
              if (configsById[id] case final c?) configEntry(c),
          ],
          options: [
            for (final c in configs)
              if (!values.cylinderConfigIds.contains(c.id)) configEntry(c),
          ],
          ids: values.cylinderConfigIds,
          onChanged: (ids) =>
              onChanged(values.copyWith(cylinderConfigIds: ids)),
        ),
        ..._totals(context, l10n, units, bundle),
      ],
    );
  }

  static String _itemCount(AppLocalizations l10n, int count) => count == 1
      ? l10n.equipment_sets_itemCountSingular(count)
      : l10n.equipment_sets_itemCountPlural(count);

  /// The "applies in total" line, shown once the set carries anything
  /// besides its own gear, and the note for a set that has no gear at all.
  List<Widget> _totals(
    BuildContext context,
    AppLocalizations l10n,
    UnitFormatter units,
    SetBundle bundle,
  ) {
    final carriesMore =
        values.includedSetIds.isNotEmpty ||
        bundle.weights.isNotEmpty ||
        bundle.cylinders.isNotEmpty;
    if (!carriesMore) return const [];
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 12),
      Text(
        l10n.equipment_setEdit_bundle_total(
          setBundleSummaryText(
            l10n,
            units,
            gearCount: bundle.gearIds.length,
            leadKg: bundle.totalWeightKg,
            cylinderCount: bundle.cylinders.length,
          ),
        ),
        style: theme.textTheme.bodyMedium,
      ),
      if (!bundle.hasGear) ...[
        const SizedBox(height: 4),
        Text(
          l10n.equipment_setEdit_bundle_noGearHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ];
  }
}

/// One of the three lists: a header with an add action, then its rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.kind,
    required this.title,
    required this.addLabel,
    required this.emptyText,
    required this.noOptionsText,
    required this.icon,
    required this.entries,
    required this.options,
    required this.ids,
    required this.onChanged,
    this.trailing,
  });

  /// 'includes', 'presets' or 'configs': names this section's keys.
  final String kind;
  final String title;
  final String? trailing;
  final String addLabel;
  final String emptyText;
  final String noOptionsText;
  final IconData icon;

  /// The rows shown: [ids] whose target still exists, in order.
  final List<_Entry> entries;

  /// What the picker offers.
  final List<_Entry> options;
  final List<String> ids;
  final ValueChanged<List<String>> onChanged;

  Future<void> _add(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: options.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(noOptionsText),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text(
                      addLabel,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  for (final option in options)
                    ListTile(
                      key: Key('set-bundle-option-${option.id}'),
                      leading: Icon(icon),
                      title: Text(option.title),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(option.subtitle!),
                      onTap: () => Navigator.of(sheetContext).pop(option.id),
                    ),
                ],
              ),
      ),
    );
    if (picked != null) onChanged([...ids, picked]);
  }

  /// [newIndex] is where the row lands once it has left [oldIndex].
  void _reorder(int oldIndex, int newIndex) {
    final shown = [for (final e in entries) e.id];
    final moved = shown.removeAt(oldIndex);
    shown.insert(newIndex, moved);
    onChanged(shown);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            if (trailing != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(trailing!, style: theme.textTheme.bodyMedium),
              ),
            TextButton.icon(
              key: Key('set-bundle-add-$kind'),
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ],
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView(
            key: Key('set-bundle-list-$kind'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: entries.length > 1,
            onReorderItem: _reorder,
            children: [
              for (final entry in entries)
                ListTile(
                  key: ValueKey('set-bundle-$kind-${entry.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon),
                  title: Text(entry.title),
                  subtitle: entry.subtitle == null
                      ? null
                      : Text(entry.subtitle!),
                  trailing: Padding(
                    // Leaves room for the drag handle the list adds.
                    padding: EdgeInsetsDirectional.only(
                      end: entries.length > 1 ? 32 : 0,
                    ),
                    child: IconButton(
                      key: Key('set-bundle-remove-$kind-${entry.id}'),
                      icon: const Icon(Icons.close),
                      tooltip: context.l10n.equipment_setEdit_bundle_remove,
                      onPressed: () => onChanged([
                        for (final id in ids)
                          if (id != entry.id) id,
                      ]),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
