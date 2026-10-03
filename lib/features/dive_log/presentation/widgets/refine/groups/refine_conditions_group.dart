import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_group_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The Refine panel's Conditions group (#2773): depth, bottom time, deco,
/// water temperature, visibility and water type. Bounds are typed in the
/// diver's units and stored metric; a bound is written only when its field
/// changes, so an untouched one never drifts through a rounded display.
class RefineConditionsGroup extends ConsumerStatefulWidget {
  const RefineConditionsGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {
    'minDepth',
    'maxDepth',
    'minBottomTimeMinutes',
    'maxBottomTimeMinutes',
    'decoOnly',
    'minWaterTemp',
    'maxWaterTemp',
    'minVisibility',
    'maxVisibility',
    'waterTypes',
  };

  static int activeCount(DiveFilterState f) => [
    f.minDepth != null || f.maxDepth != null,
    f.minBottomTimeMinutes != null || f.maxBottomTimeMinutes != null,
    f.decoOnly != null,
    f.minWaterTemp != null || f.maxWaterTemp != null,
    f.minVisibility != null || f.maxVisibility != null,
    f.waterTypes.isNotEmpty,
  ].where((active) => active).length;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_search_section_conditions;

  @override
  ConsumerState<RefineConditionsGroup> createState() =>
      _RefineConditionsGroupState();
}

class _RefineConditionsGroupState extends ConsumerState<RefineConditionsGroup> {
  final _minDepth = TextEditingController();
  final _maxDepth = TextEditingController();
  final _minDuration = TextEditingController();
  final _maxDuration = TextEditingController();
  final _minTemp = TextEditingController();
  final _maxTemp = TextEditingController();
  final _minVis = TextEditingController();
  final _maxVis = TextEditingController();

  @override
  void initState() {
    super.initState();
    _seed();
  }

  /// Shows the stored metric bounds in the diver's units. Never writes the
  /// draft, so an untouched bound cannot drift through a rounded display.
  void _seed() {
    final units = UnitFormatter(ref.read(settingsProvider));
    final d = widget.draft;
    String shown(double? v, double Function(double) convert) =>
        v == null ? '' : formatRoundedForInput(convert(v), 0);
    _minDepth.text = shown(d.minDepth, units.convertDepth);
    _maxDepth.text = shown(d.maxDepth, units.convertDepth);
    _minTemp.text = shown(d.minWaterTemp, units.convertTemperature);
    _maxTemp.text = shown(d.maxWaterTemp, units.convertTemperature);
    _minVis.text = shown(d.minVisibility, units.convertDepth);
    _maxVis.text = shown(d.maxVisibility, units.convertDepth);
    _minDuration.text = d.minBottomTimeMinutes?.toString() ?? '';
    _maxDuration.text = d.maxBottomTimeMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _minDepth,
      _maxDepth,
      _minDuration,
      _maxDuration,
      _minTemp,
      _maxTemp,
      _minVis,
      _maxVis,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// A typed bound: the value converted to storage, null when blank, or
  /// [previous] when unreadable (the field shows the error).
  static double? _bound(
    NumberRead read,
    double? previous,
    double Function(double) toStorage,
  ) => switch (read) {
    NumberValue(:final value) => toStorage(value),
    NumberBlank() => null,
    NumberInvalid() => previous,
  };

  Widget _pair({
    required String keyPrefix,
    required IconData icon,
    required String suffix,
    required TextEditingController min,
    required TextEditingController max,
    required ValueChanged<NumberRead> onMin,
    required ValueChanged<NumberRead> onMax,
    bool allowNegative = false,
    bool integer = false,
  }) {
    final l10n = context.l10n;
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixText: suffix,
    );
    return Row(
      children: [
        Expanded(
          child: NumberField(
            key: ValueKey('$keyPrefix-min'),
            controller: min,
            allowNegative: allowNegative,
            integer: integer,
            decoration: deco(l10n.diveLog_filter_min),
            onChanged: onMin,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: NumberField(
            key: ValueKey('$keyPrefix-max'),
            controller: max,
            allowNegative: allowNegative,
            integer: integer,
            decoration: deco(l10n.diveLog_filter_max),
            onChanged: onMax,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // A unit change while open re-reads the bounds in the new unit.
    ref.listen(
      settingsProvider.select((s) => (s.depthUnit, s.temperatureUnit)),
      (_, _) => _seed(),
    );
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final d = widget.draft;
    void write(DiveFilterState next) => widget.onChanged(next);
    int? minutes(NumberRead read, int? previous) => switch (read) {
      NumberValue(:final value) => value.toInt(),
      NumberBlank() => null,
      NumberInvalid() => previous,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefineSubLabel(
          l10n.diveLog_filter_sectionDepthRangeUnit(units.depthSymbol),
        ),
        _pair(
          keyPrefix: 'refine-depth',
          icon: Icons.arrow_downward,
          suffix: units.depthSymbol,
          min: _minDepth,
          max: _maxDepth,
          onMin: (r) {
            final v = _bound(r, d.minDepth, units.depthToMeters);
            write(d.copyWith(minDepth: v, clearMinDepth: v == null));
          },
          onMax: (r) {
            final v = _bound(r, d.maxDepth, units.depthToMeters);
            write(d.copyWith(maxDepth: v, clearMaxDepth: v == null));
          },
        ),
        RefineSubLabel(l10n.diveLog_filter_sectionDuration),
        _pair(
          keyPrefix: 'refine-duration',
          icon: Icons.timer,
          suffix: l10n.units_profileMetric_min,
          min: _minDuration,
          max: _maxDuration,
          integer: true,
          onMin: (r) {
            final v = minutes(r, d.minBottomTimeMinutes);
            write(
              d.copyWith(
                minBottomTimeMinutes: v,
                clearMinBottomTimeMinutes: v == null,
              ),
            );
          },
          onMax: (r) {
            final v = minutes(r, d.maxBottomTimeMinutes);
            write(
              d.copyWith(
                maxBottomTimeMinutes: v,
                clearMaxBottomTimeMinutes: v == null,
              ),
            );
          },
        ),
        RefineSubLabel(l10n.diveLog_search_label_deco),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in [
              (l10n.diveLog_search_filter_any, null),
              (l10n.attr_flagYes, true),
              (l10n.attr_flagNo, false),
            ])
              ChoiceChip(
                label: Text(label),
                selected: d.decoOnly == value,
                onSelected: (selected) {
                  if (!selected) return;
                  write(
                    d.copyWith(decoOnly: value, clearDecoOnly: value == null),
                  );
                },
              ),
          ],
        ),
        RefineSubLabel(
          l10n.diveLog_filter_sectionWaterTempUnit(units.temperatureSymbol),
        ),
        _pair(
          keyPrefix: 'filter-water-temp',
          icon: Icons.thermostat,
          suffix: units.temperatureSymbol,
          min: _minTemp,
          max: _maxTemp,
          // Ice diving: below zero is a real bound.
          allowNegative: true,
          onMin: (r) {
            final v = _bound(r, d.minWaterTemp, units.temperatureToCelsius);
            write(d.copyWith(minWaterTemp: v, clearMinWaterTemp: v == null));
          },
          onMax: (r) {
            final v = _bound(r, d.maxWaterTemp, units.temperatureToCelsius);
            write(d.copyWith(maxWaterTemp: v, clearMaxWaterTemp: v == null));
          },
        ),
        RefineSubLabel(
          l10n.diveLog_filter_sectionVisibilityUnit(units.depthSymbol),
        ),
        _pair(
          keyPrefix: 'filter-visibility',
          icon: Icons.visibility,
          suffix: units.depthSymbol,
          min: _minVis,
          max: _maxVis,
          onMin: (r) {
            final v = _bound(r, d.minVisibility, units.depthToMeters);
            write(d.copyWith(minVisibility: v, clearMinVisibility: v == null));
          },
          onMax: (r) {
            final v = _bound(r, d.maxVisibility, units.depthToMeters);
            write(d.copyWith(maxVisibility: v, clearMaxVisibility: v == null));
          },
        ),
        RefineSubLabel(l10n.diveLog_filter_sectionWaterType),
        Wrap(
          spacing: 8,
          children: [
            for (final type in WaterType.values)
              FilterChip(
                label: Text(type.localizedName(l10n)),
                selected: d.waterTypes.contains(type),
                onSelected: (selected) => write(
                  d.copyWith(
                    waterTypes: selected
                        ? [...d.waterTypes, type]
                        : [
                            for (final t in d.waterTypes)
                              if (t != type) t,
                          ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
