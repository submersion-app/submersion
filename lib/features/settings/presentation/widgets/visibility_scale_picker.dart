import 'package:flutter/material.dart';

import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The visibility calibration picker, split out of `settings_page.dart` so it
/// can be pumped directly in tests and so that file stops growing.
///
/// The calibration decides which measured distances read as
/// excellent/good/moderate/poor. It is purely presentational: dives store the
/// measured distance, so changing it re-labels a logbook without altering a
/// single dive.

/// Opens the calibration picker.
///
/// Choosing a named preset saves immediately; choosing Custom hands off to
/// [showCustomVisibilityScaleDialog].
void showVisibilityScalePicker(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      // The explained list is taller than a landscape phone.
      scrollable: true,
      title: Text(AppLocalizations.of(context).settings_visibilityScale_title),
      content: VisibilityScalePresetList(
        selected: settings.visibilityScalePreset,
        units: UnitFormatter(settings),
        custom: retainedCustomVisibilityScale(settings),
        onSelected: (preset) {
          Navigator.of(dialogContext).pop();
          if (preset == VisibilityScalePreset.custom) {
            showCustomVisibilityScaleDialog(context, ref, settings);
            return;
          }
          ref
              .read(settingsProvider.notifier)
              .setVisibilityScale(preset: preset);
        },
      ),
    ),
  );
}

/// Opens the custom-threshold dialog.
///
/// Seeds from the diver's retained custom columns rather than
/// [AppSettings.visibilityScale]: that getter resolves to the *named* preset's
/// bounds whenever one is active, so reopening Custom after switching away and
/// back would show the preset's numbers and hide the values the diver entered.
void showCustomVisibilityScaleDialog(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  final active = settings.visibilityScale;
  final seed = VisibilityScale(
    excellentAtOrAboveM:
        settings.visibilityScaleExcellentM ?? active.excellentAtOrAboveM,
    goodAtOrAboveM: settings.visibilityScaleGoodM ?? active.goodAtOrAboveM,
    moderateAtOrAboveM:
        settings.visibilityScaleModerateM ?? active.moderateAtOrAboveM,
  );

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      // Three fields and their help text outgrow a landscape phone once the
      // keyboard is up.
      scrollable: true,
      title: Text(
        AppLocalizations.of(context).settings_visibilityScale_preset_custom,
      ),
      content: CustomVisibilityScaleForm(
        initial: seed,
        units: UnitFormatter(settings),
        // Only a seed made entirely of preset bounds is nominal; any retained
        // value is the diver's own and keeps its decimal.
        wholeUnits:
            settings.visibilityScaleExcellentM == null &&
            settings.visibilityScaleGoodM == null &&
            settings.visibilityScaleModerateM == null,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSubmit: (scale) {
          ref
              .read(settingsProvider.notifier)
              .setVisibilityScale(
                preset: VisibilityScalePreset.custom,
                excellentM: scale.excellentAtOrAboveM,
                goodM: scale.goodAtOrAboveM,
                moderateM: scale.moderateAtOrAboveM,
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    ),
  );
}

/// Localized label for a calibration preset.
String visibilityPresetLabel(
  AppLocalizations l10n,
  VisibilityScalePreset preset,
) => switch (preset) {
  VisibilityScalePreset.tropical =>
    l10n.settings_visibilityScale_preset_tropical,
  VisibilityScalePreset.temperate =>
    l10n.settings_visibilityScale_preset_temperate,
  VisibilityScalePreset.coldWater =>
    l10n.settings_visibilityScale_preset_coldWater,
  VisibilityScalePreset.custom => l10n.settings_visibilityScale_preset_custom,
};

/// Every band of [scale] with the range it covers, in the diver's depth unit,
/// ordered Excellent, Good, Moderate, Poor, e.g. `Good 15-30 m`.
///
/// Poor is spelled out even though it has no threshold of its own, so the
/// diver never has to infer it from the Moderate bound.
///
/// Set [wholeUnits] for a named preset: its bounds are round metric numbers,
/// so an imperial conversion's decimal (98.4 ft) is noise. A diver's own
/// thresholds keep one decimal, because rounding 2.5 m to "3" would misstate
/// where a band begins.
List<String> visibilityScaleBandLabels(
  VisibilityScale scale,
  AppLocalizations l10n,
  UnitFormatter units, {
  bool wholeUnits = false,
}) {
  final unit = units.depthSymbol;
  String v(double meters) =>
      _thresholdText(meters, units, wholeUnits: wholeUnits);
  String band(VisibilityBand b, String range) => l10n
      .settings_visibilityScale_bandRange(visibilityBandName(b, l10n), range);

  final excellent = band(
    VisibilityBand.excellent,
    l10n.visibility_range_atLeast(v(scale.excellentAtOrAboveM), unit),
  );
  final good = band(
    VisibilityBand.good,
    l10n.visibility_range_between(
      v(scale.goodAtOrAboveM),
      v(scale.excellentAtOrAboveM),
      unit,
    ),
  );
  final moderate = band(
    VisibilityBand.moderate,
    l10n.visibility_range_between(
      v(scale.moderateAtOrAboveM),
      v(scale.goodAtOrAboveM),
      unit,
    ),
  );
  final poor = visibilityPoorLabel(
    scale.moderateAtOrAboveM,
    l10n,
    units,
    wholeUnits: wholeUnits,
  );
  return [excellent, good, moderate, poor];
}

/// The Poor band as text, e.g. `Poor under 5 m`, given where Moderate begins.
/// [wholeUnits] as for [visibilityScaleBandLabels].
String visibilityPoorLabel(
  double moderateAtOrAboveM,
  AppLocalizations l10n,
  UnitFormatter units, {
  bool wholeUnits = false,
}) => l10n.settings_visibilityScale_bandRange(
  visibilityBandName(VisibilityBand.poor, l10n),
  l10n.visibility_range_under(
    _thresholdText(moderateAtOrAboveM, units, wholeUnits: wholeUnits),
    units.depthSymbol,
  ),
);

/// A threshold in the diver's depth unit, in the active locale: whole units,
/// or at most one decimal with a whole value shown without one ("2.5", "40").
String _thresholdText(
  double meters,
  UnitFormatter units, {
  required bool wholeUnits,
}) {
  final value = units.convertDepth(meters);
  if (wholeUnits) return formatFixedForDisplay(value, 0);
  // Rounded first so a stored 12.192 m entered as 40 ft reads "40", not
  // "40.0".
  final tenths = double.parse(value.toStringAsFixed(1));
  return formatFixedForDisplay(
    tenths,
    tenths == tenths.roundToDouble() ? 0 : 1,
  );
}

/// The diver's saved custom thresholds, or null when none are saved or the
/// saved set is invalid.
///
/// Read from the retained columns rather than [AppSettings.visibilityScale],
/// which resolves to the named preset's bounds whenever one is active.
VisibilityScale? retainedCustomVisibilityScale(AppSettings settings) {
  final e = settings.visibilityScaleExcellentM;
  final g = settings.visibilityScaleGoodM;
  final m = settings.visibilityScaleModerateM;
  if (e == null || g == null || m == null) return null;
  final scale = VisibilityScale(
    excellentAtOrAboveM: e,
    goodAtOrAboveM: g,
    moderateAtOrAboveM: m,
  );
  return scale.isValid ? scale : null;
}

/// The preset list shown inside the picker dialog.
///
/// Each preset spells out the range every band covers so the diver can see
/// what they are choosing without opening Custom.
class VisibilityScalePresetList extends StatelessWidget {
  final VisibilityScalePreset selected;
  final UnitFormatter units;

  /// The diver's saved custom thresholds, shown under Custom; null when none
  /// are saved yet.
  final VisibilityScale? custom;
  final ValueChanged<VisibilityScalePreset> onSelected;

  const VisibilityScalePresetList({
    super.key,
    required this.selected,
    required this.units,
    this.custom,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Text(
            l10n.settings_visibilityScale_intro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ...VisibilityScalePreset.values.map((preset) {
          // Custom has no bounds to advertise until the diver saves some.
          final scale = preset == VisibilityScalePreset.custom
              ? custom
              : VisibilityScale.forPreset(preset);
          return ListTile(
            // Flush with the intro text, which also leaves the ranges room
            // to fit two bands per line on a phone.
            contentPadding: EdgeInsets.zero,
            title: Text(visibilityPresetLabel(l10n, preset)),
            subtitle: scale == null
                ? Text(l10n.settings_visibilityScale_customUnset)
                : _BandRanges(
                    labels: visibilityScaleBandLabels(
                      scale,
                      l10n,
                      units,
                      wholeUnits: preset != VisibilityScalePreset.custom,
                    ),
                  ),
            trailing: preset == selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => onSelected(preset),
          );
        }),
      ],
    );
  }
}

/// A preset's four bands as two lines, Excellent and Good over Moderate and
/// Poor.
///
/// Each band is its own [Text] inside a [Wrap], so a narrow dialog can only
/// break a line between bands. A single string would wrap at any space and
/// strand a range from its label ("Good" / "15-30 m").
class _BandRanges extends StatelessWidget {
  /// Excellent, Good, Moderate, Poor, as [visibilityScaleBandLabels] orders
  /// them.
  final List<String> labels;

  const _BandRanges({required this.labels});

  @override
  Widget build(BuildContext context) {
    Widget line(String first, String second) =>
        Wrap(spacing: 4, children: [Text('$first ·'), Text(second)]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [line(labels[0], labels[1]), line(labels[2], labels[3])],
    );
  }
}

/// The custom-threshold form: three numeric fields plus inline validation.
///
/// Values are entered in the diver's depth unit and handed back in meters,
/// because storage is always metric.
class CustomVisibilityScaleForm extends StatefulWidget {
  /// Seed values, already resolved by the caller from the diver's retained
  /// custom thresholds rather than from the active preset.
  final VisibilityScale initial;
  final UnitFormatter units;

  /// Seed whole units rather than one decimal. Set when [initial] is a named
  /// preset's bounds: they are round metric numbers, so an imperial
  /// conversion's decimal (12 m is 39.4 ft) is noise, and the fields should
  /// match what the preset list shows.
  final bool wholeUnits;

  /// Called with metric thresholds once they validate.
  final ValueChanged<VisibilityScale> onSubmit;
  final VoidCallback onCancel;

  const CustomVisibilityScaleForm({
    super.key,
    required this.initial,
    required this.units,
    this.wholeUnits = false,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<CustomVisibilityScaleForm> createState() =>
      _CustomVisibilityScaleFormState();
}

class _CustomVisibilityScaleFormState extends State<CustomVisibilityScaleForm> {
  late final TextEditingController _excellent;
  late final TextEditingController _good;
  late final TextEditingController _moderate;

  /// The text each field was seeded with and the meters it stands for, so a
  /// field the diver never edited saves the stored value itself.
  late final Map<TextEditingController, ({String text, double meters})> _seeds;
  String? _error;

  @override
  void initState() {
    super.initState();
    // One decimal, so a custom 2.5 m reads "2.5" rather than a misleading
    // "3". Rendered through the locale formatter so the text shares one
    // convention with [_metersFrom].
    ({String text, double meters}) seed(double meters) => (
      text: formatRoundedForInput(
        widget.units.convertDepth(meters),
        widget.wholeUnits ? 0 : 1,
      ),
      meters: meters,
    );
    final excellent = seed(widget.initial.excellentAtOrAboveM);
    final good = seed(widget.initial.goodAtOrAboveM);
    final moderate = seed(widget.initial.moderateAtOrAboveM);
    _excellent = TextEditingController(text: excellent.text);
    _good = TextEditingController(text: good.text);
    _moderate = TextEditingController(text: moderate.text);
    _seeds = {_excellent: excellent, _good: good, _moderate: moderate};
  }

  @override
  void dispose() {
    _excellent.dispose();
    _good.dispose();
    _moderate.dispose();
    super.dispose();
  }

  /// The meters a field saves as.
  double? _metersFrom(TextEditingController c) {
    // Re-parsing untouched text would store its rounding (2.56 m saved as 2.6)
    // or a unit round trip's drift (2.5 m through "8.2" ft is 2.499 m).
    final seeded = _seeds[c];
    if (seeded != null && c.text == seeded.text) return seeded.meters;
    return _typedMetersFrom(c);
  }

  /// The meters a field's text reads as, for anything that describes what
  /// the diver can see: a whole-unit seed of "7" ft must not be described as
  /// the 6.6 ft it was rounded from.
  double? _typedMetersFrom(TextEditingController c) {
    final parsed = parseUserDecimal(c.text);
    return parsed == null ? null : widget.units.depthToMeters(parsed);
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final e = _metersFrom(_excellent);
    final g = _metersFrom(_good);
    final m = _metersFrom(_moderate);
    final candidate = e == null || g == null || m == null
        ? null
        : VisibilityScale(
            excellentAtOrAboveM: e,
            goodAtOrAboveM: g,
            moderateAtOrAboveM: m,
          );
    // Blocked rather than silently reordered: a non-descending set would make
    // one band unreachable, and the diver should see why.
    if (candidate == null || !candidate.isValid) {
      setState(() => _error = l10n.settings_visibilityScale_invalidOrder);
      return;
    }
    widget.onSubmit(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fields = <(String, TextEditingController)>[
      (l10n.settings_visibilityScale_customExcellent, _excellent),
      (l10n.settings_visibilityScale_customGood, _good),
      (l10n.settings_visibilityScale_customModerate, _moderate),
    ];
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.settings_visibilityScale_customHelp,
            style: textTheme.bodySmall,
          ),
        ),
        for (final (label, controller) in fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: label,
                suffixText: widget.units.depthSymbol,
              ),
            ),
          ),
        // Poor has no field of its own: it is everything below Moderate, so
        // it follows that field as the diver types.
        ListenableBuilder(
          listenable: _moderate,
          builder: (context, _) {
            final moderateM = _typedMetersFrom(_moderate);
            if (moderateM == null || moderateM <= 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                visibilityPoorLabel(moderateM, l10n, widget.units),
                style: textTheme.bodySmall,
              ),
            );
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: Text(l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: _submit,
              child: Text(l10n.common_action_save),
            ),
          ],
        ),
      ],
    );
  }
}
