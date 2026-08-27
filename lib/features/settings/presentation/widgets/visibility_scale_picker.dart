import 'package:flutter/material.dart';

import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
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
      title: Text(AppLocalizations.of(context).settings_visibilityScale_title),
      content: VisibilityScalePresetList(
        selected: settings.visibilityScalePreset,
        units: UnitFormatter(settings),
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
      title: Text(
        AppLocalizations.of(context).settings_visibilityScale_preset_custom,
      ),
      content: CustomVisibilityScaleForm(
        initial: seed,
        units: UnitFormatter(settings),
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

/// Renders a scale's three thresholds in the diver's depth unit, e.g.
/// `40 / 20 / 7ft`.
String visibilityScaleBoundsLabel(VisibilityScale scale, UnitFormatter units) {
  String v(double meters) => units.convertDepth(meters).toStringAsFixed(0);
  return '${v(scale.excellentAtOrAboveM)} / ${v(scale.goodAtOrAboveM)}'
      ' / ${v(scale.moderateAtOrAboveM)}${units.depthSymbol}';
}

/// The preset list shown inside the picker dialog.
///
/// Each named preset shows its own thresholds so the diver can see what they
/// are choosing without opening Custom.
class VisibilityScalePresetList extends StatelessWidget {
  final VisibilityScalePreset selected;
  final UnitFormatter units;
  final ValueChanged<VisibilityScalePreset> onSelected;

  const VisibilityScalePresetList({
    super.key,
    required this.selected,
    required this.units,
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
            l10n.settings_visibilityScale_subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ...VisibilityScalePreset.values.map((preset) {
          // Custom has no fixed bounds to advertise until the diver sets them.
          final subtitle = preset == VisibilityScalePreset.custom
              ? null
              : visibilityScaleBoundsLabel(
                  VisibilityScale.forPreset(preset),
                  units,
                );
          return ListTile(
            title: Text(visibilityPresetLabel(l10n, preset)),
            subtitle: subtitle == null ? null : Text(subtitle),
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

/// The custom-threshold form: three numeric fields plus inline validation.
///
/// Values are entered in the diver's depth unit and handed back in meters,
/// because storage is always metric.
class CustomVisibilityScaleForm extends StatefulWidget {
  /// Seed values, already resolved by the caller from the diver's retained
  /// custom thresholds rather than from the active preset.
  final VisibilityScale initial;
  final UnitFormatter units;

  /// Called with metric thresholds once they validate.
  final ValueChanged<VisibilityScale> onSubmit;
  final VoidCallback onCancel;

  const CustomVisibilityScaleForm({
    super.key,
    required this.initial,
    required this.units,
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
  String? _error;

  @override
  void initState() {
    super.initState();
    // Whole units only, but rendered through the locale formatter so the text
    // shares one convention with [_metersFrom].
    String initial(double meters) => formatDecimalForInput(
      widget.units.convertDepth(meters).roundToDouble(),
    );
    _excellent = TextEditingController(
      text: initial(widget.initial.excellentAtOrAboveM),
    );
    _good = TextEditingController(text: initial(widget.initial.goodAtOrAboveM));
    _moderate = TextEditingController(
      text: initial(widget.initial.moderateAtOrAboveM),
    );
  }

  @override
  void dispose() {
    _excellent.dispose();
    _good.dispose();
    _moderate.dispose();
    super.dispose();
  }

  double? _metersFrom(TextEditingController c) {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
