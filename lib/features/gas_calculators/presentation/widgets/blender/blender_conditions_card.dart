import 'package:flutter/material.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_section_title.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fill temperature, settled temperature and equation of state.
///
/// Two temperatures rather than one, because a single temperature would change
/// nothing: mole ratios are temperature-free, so a uniform temperature cancels
/// out of the whole procedure. What a blender actually does is fill a chilled
/// cylinder and quote the pressure it settles to.
class BlenderConditionsCard extends ConsumerWidget {
  const BlenderConditionsCard({super.key});

  /// The values offered, in the display unit, so neither audience is asked to
  /// pick from a list of converted oddities.
  static const List<double> _celsiusLadder = [0, 5, 10, 15, 20, 25, 30, 35];
  static const List<double> _fahrenheitLadder = [
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final fahrenheit = settings.temperatureUnit == TemperatureUnit.fahrenheit;
    final ladder = fahrenheit ? _fahrenheitLadder : _celsiusLadder;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlenderSectionTitle(context.l10n.gasCalculators_blender_conditions),
            _temperatureField(
              context,
              key: const Key('blender-fill-temp'),
              label: context.l10n.gasCalculators_blender_fillTemp,
              help: context.l10n.gasCalculators_blender_fillTempHelp,
              units: units,
              ladder: ladder,
              current: ref.watch(blenderFillTempProvider),
              onChanged: (c) {
                ref.read(blenderFillTempProvider.notifier).state = c;
                saveBlenderPreferences(ref);
              },
            ),
            const SizedBox(height: 16),
            _temperatureField(
              context,
              key: const Key('blender-settled-temp'),
              label: context.l10n.gasCalculators_blender_settledTemp,
              help: context.l10n.gasCalculators_blender_settledTempHelp,
              units: units,
              ladder: ladder,
              current: ref.watch(blenderSettledTempProvider),
              onChanged: (c) {
                ref.read(blenderSettledTempProvider.notifier).state = c;
                saveBlenderPreferences(ref);
              },
            ),
            const SizedBox(height: 20),
            _modelField(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _temperatureField(
    BuildContext context, {
    required Key key,
    required String label,
    required String help,
    required UnitFormatter units,
    required List<double> ladder,
    required double current,
    required ValueChanged<double> onChanged,
  }) {
    // A value arriving from another device, or surviving a unit change, may
    // not sit on the ladder. Show it rather than snapping it to a neighbour,
    // which would silently rewrite a temperature the diver chose elsewhere.
    final shown = units.convertTemperature(current);
    final values = [...ladder];
    if (!values.any((v) => (v - shown).abs() < 0.05)) {
      values
        ..add(shown)
        ..sort();
    }

    // Controlled, not seeded: a stored preference arriving from the async
    // load, or a temperature-unit change that rebuilds the ladder, has to move
    // the dropdown with it (PR #1215 review).
    return DropdownButtonFormField<double>(
      key: key,
      initialValue: values.firstWhere((v) => (v - shown).abs() < 0.05),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        helperMaxLines: 3,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text('${_trim(v)} ${units.temperatureSymbol}'),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(units.temperatureToCelsius(v));
      },
    );
  }

  Widget _modelField(BuildContext context, WidgetRef ref) {
    String label(BlendGasModel m) => switch (m) {
      BlendGasModel.ideal => context.l10n.gasCalculators_blender_modelIdeal,
      BlendGasModel.vanDerWaals =>
        context.l10n.gasCalculators_blender_modelVanDerWaals,
      BlendGasModel.zFactor =>
        '${context.l10n.gasCalculators_blender_modelZFactor} '
            '(${context.l10n.gasCalculators_blender_modelRecommended})',
    };

    return DropdownButtonFormField<BlendGasModel>(
      key: const Key('blender-gas-model'),
      initialValue: ref.watch(blenderGasModelProvider),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.gasCalculators_blender_gasModel,
        helperText: context.l10n.gasCalculators_blender_modelHelp,
        helperMaxLines: 5,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final m in BlendGasModel.values)
          DropdownMenuItem(value: m, child: Text(label(m))),
      ],
      onChanged: (m) {
        if (m == null) return;
        ref.read(blenderGasModelProvider.notifier).state = m;
        saveBlenderPreferences(ref);
      },
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
