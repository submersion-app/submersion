import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_group_tile.dart';
import 'package:submersion/features/dive_log/presentation/utils/filter_option_search.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The Refine panel's Gas and equipment group (#2773): dive type, gas mix,
/// equipment used, gear attributes, suit thickness and dive computer.
class RefineGasEquipmentGroup extends ConsumerStatefulWidget {
  const RefineGasEquipmentGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {
    'diveTypeId',
    'minO2Percent',
    'maxO2Percent',
    'equipmentIds',
    'equipmentAttrConditions',
    'computerId',
  };

  static int activeCount(DiveFilterState f) => [
    f.diveTypeId != null,
    f.minO2Percent != null || f.maxO2Percent != null,
    f.equipmentIds.isNotEmpty,
    f.equipmentAttrConditions.isNotEmpty,
    f.computerId != null,
  ].where((active) => active).length;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_search_section_gasEquipment;

  /// Drops a computer deleted since the filter was set, so it applies as
  /// All computers. A list still loading says nothing about whether the
  /// computer exists, so the id is kept (#1064).
  static DiveFilterState resolveOnApply(
    DiveFilterState d,
    AsyncValue<List<DiveComputer>> computers,
  ) {
    final id = d.computerId;
    final list = computers.valueOrNull;
    if (id == null || list == null || list.any((c) => c.id == id)) return d;
    return d.copyWith(clearComputerId: true);
  }

  @override
  ConsumerState<RefineGasEquipmentGroup> createState() =>
      _RefineGasEquipmentGroupState();
}

class _RefineGasEquipmentGroupState
    extends ConsumerState<RefineGasEquipmentGroup> {
  double? _suitMin;
  double? _suitMax;
  EquipmentType? _gearCategory;
  List<EquipmentAttrCondition> _gearConditions = const [];

  @override
  void initState() {
    super.initState();
    for (final condition in widget.draft.equipmentAttrConditions) {
      if (condition.isSuitThickness) {
        _suitMin = condition.min;
        _suitMax = condition.max;
      } else {
        _gearConditions = [..._gearConditions, condition];
        if (condition.types.length == 1) {
          _gearCategory ??= condition.types.first;
        }
      }
    }
  }

  void _writeConditions() => widget.onChanged(
    widget.draft.copyWith(
      equipmentAttrConditions: [
        if (_suitMin != null || _suitMax != null)
          EquipmentAttrCondition.suitThickness(min: _suitMin, max: _suitMax),
        ..._gearConditions,
      ],
    ),
  );

  /// Suit thickness in the diver's locale: blank clears, unreadable keeps
  /// [previous] while the field shows its error (#1900, #1091).
  static double? _thickness(String text, double? previous) =>
      switch (readNumber(text)) {
        NumberValue(:final value) => value,
        NumberBlank() => null,
        NumberInvalid() => previous,
      };

  Widget _thicknessField(
    BuildContext context, {
    required Key key,
    required String label,
    required double? value,
    required ValueChanged<String> onChanged,
  }) => TextFormField(
    key: key,
    initialValue: value == null ? '' : formatDecimalForInput(value),
    decoration: InputDecoration(labelText: label),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: numberInputFormatters(),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: numberValidator(context),
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.draft;
    void setGas(double? min, double? max) => widget.onChanged(
      d.copyWith(
        minO2Percent: min,
        clearMinO2Percent: min == null,
        maxO2Percent: max,
        clearMaxO2Percent: max == null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefineSubLabel(l10n.diveLog_filter_sectionDiveType),
        ref
            .watch(diveTypesProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(l10n.diveLog_listPage_errorLoading(e)),
              data: (types) => SearchableFilterDropdown<String>(
                value: d.diveTypeId,
                allOptionLabel: l10n.diveLog_filter_allTypes,
                searchHintText: l10n.diveLog_filter_searchTypesHint,
                icon: Icons.category,
                options: [
                  for (final type in types)
                    FilterDropdownOption(
                      value: type.id,
                      label: type.localizedName(l10n),
                    ),
                ],
                onChanged: (v) => widget.onChanged(
                  d.copyWith(diveTypeId: v, clearDiveType: v == null),
                ),
              ),
            ),
        RefineSubLabel(l10n.diveLog_filter_sectionGasMix),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, min, max) in <(String, double?, double?)>[
              (l10n.diveLog_filter_gasAll, null, null),
              (l10n.diveLog_filter_gasAir, 20, 22),
              (l10n.diveLog_filter_gasNitrox, 22, null),
              (l10n.diveLog_search_gasTrimix, null, 21),
            ])
              ChoiceChip(
                label: Text(label),
                selected: d.minO2Percent == min && d.maxO2Percent == max,
                onSelected: (selected) {
                  if (selected) setGas(min, max);
                },
              ),
          ],
        ),
        RefineSubLabel(l10n.diveLog_search_label_equipment),
        ref
            .watch(allEquipmentProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.diveLog_search_errorLoadingEquipment),
              data: (all) {
                // Wishlist gear (#2025) is never on a dive, so it gets no
                // chip, unless the filter already holds it: then it stays
                // visible so the diver can clear it.
                final items = [
                  for (final item in all)
                    if (!item.isWanted || d.equipmentIds.contains(item.id))
                      item,
                ];
                return items.isEmpty
                    ? Text(
                        l10n.diveLog_equipmentPicker_noEquipment,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in items)
                            FilterChip(
                              avatar: Icon(
                                equipmentTypeIcon(item.type),
                                size: 18,
                              ),
                              label: Text(item.name),
                              selected: d.equipmentIds.contains(item.id),
                              onSelected: (selected) => widget.onChanged(
                                d.copyWith(
                                  equipmentIds: selected
                                      ? [...d.equipmentIds, item.id]
                                      // Every copy goes: an imported filter
                                      // can carry an id twice.
                                      : [
                                          for (final id in d.equipmentIds)
                                            if (id != item.id) id,
                                        ],
                                ),
                              ),
                            ),
                        ],
                      );
              },
            ),
        RefineSubLabel(l10n.diveLog_filter_sectionSuitThickness),
        Row(
          children: [
            Expanded(
              child: _thicknessField(
                context,
                key: const ValueKey('refine-suit-min'),
                label: l10n.diveLog_filter_thicknessMin,
                value: _suitMin,
                onChanged: (text) {
                  _suitMin = _thickness(text, _suitMin);
                  _writeConditions();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _thicknessField(
                context,
                key: const ValueKey('refine-suit-max'),
                label: l10n.diveLog_filter_thicknessMax,
                value: _suitMax,
                onChanged: (text) {
                  _suitMax = _thickness(text, _suitMax);
                  _writeConditions();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DiveFilterGearAttributesSection(
          category: _gearCategory,
          conditions: _gearConditions,
          onChanged: (category, conditions) {
            setState(() {
              _gearCategory = category;
              _gearConditions = conditions;
            });
            _writeConditions();
          },
        ),
        RefineSubLabel(l10n.diveLog_filter_sectionDiveComputer),
        ref
            .watch(allDiveComputersProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.transfer_computers_errorLoading),
              data: (computers) {
                // Every registered computer is offered, serial or not (#1064).
                if (computers.isEmpty) {
                  return Text(
                    l10n.diveLog_filter_noComputersRegistered,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                // A computer deleted since the filter was set shows as All;
                // the draft itself is corrected on apply (resolveOnApply).
                final valid = computers.any((c) => c.id == d.computerId)
                    ? d.computerId
                    : null;
                return SearchableFilterDropdown<String>(
                  value: valid,
                  allOptionLabel: l10n.diveLog_filter_allComputers,
                  searchHintText: l10n.diveLog_filter_searchComputersHint,
                  icon: Icons.watch,
                  options: [
                    for (final c in computers)
                      FilterDropdownOption(
                        value: c.id,
                        label: c.displayName,
                        // Findable by the make and model printed on it.
                        searchText: buildFilterSearchText([
                          c.displayName,
                          c.manufacturer,
                          c.model,
                        ]),
                      ),
                  ],
                  onChanged: (v) => widget.onChanged(
                    d.copyWith(computerId: v, clearComputerId: v == null),
                  ),
                );
              },
            ),
      ],
    );
  }
}
