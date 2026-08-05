import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Real-gas partial-pressure blender: given what's in the cylinder and the
/// target fill, it lists the gases to add and the pressures to top up to.
class GasBlenderCalculator extends ConsumerWidget {
  const GasBlenderCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A reset bumps the epoch, forcing the body (and its controllers) to rebuild
    // from the reset provider values.
    final epoch = ref.watch(blenderResetEpochProvider);
    return _GasBlenderBody(key: ValueKey(epoch));
  }
}

class _GasBlenderBody extends ConsumerStatefulWidget {
  const _GasBlenderBody({super.key});

  @override
  ConsumerState<_GasBlenderBody> createState() => _GasBlenderBodyState();
}

class _GasBlenderBodyState extends ConsumerState<_GasBlenderBody> {
  late final UnitFormatter _units;
  late final TextEditingController _startP;
  late final TextEditingController _startO2;
  late final TextEditingController _startHe;
  late final TextEditingController _targetP;
  late final TextEditingController _targetO2;
  late final TextEditingController _targetHe;
  late final List<TextEditingController> _gasO2;
  late final List<TextEditingController> _gasHe;

  @override
  void initState() {
    super.initState();
    _units = UnitFormatter(ref.read(settingsProvider));

    String p(double bar) => _units.convertPressure(bar).toStringAsFixed(0);
    String n(double v) => v.toStringAsFixed(0);

    final startMix = ref.read(blenderStartMixProvider);
    final targetMix = ref.read(blenderTargetMixProvider);
    final g1 = ref.read(blenderFillGas1Provider);
    final g2 = ref.read(blenderFillGas2Provider);
    final g3 = ref.read(blenderFillGas3Provider);

    _startP = TextEditingController(
      text: p(ref.read(blenderStartPressureProvider)),
    );
    _startO2 = TextEditingController(text: n(startMix.o2));
    _startHe = TextEditingController(text: n(startMix.he));
    _targetP = TextEditingController(
      text: p(ref.read(blenderTargetPressureProvider)),
    );
    _targetO2 = TextEditingController(text: n(targetMix.o2));
    _targetHe = TextEditingController(text: n(targetMix.he));
    _gasO2 = [
      TextEditingController(text: n(g1.o2)),
      TextEditingController(text: n(g2.o2)),
      TextEditingController(text: n(g3.o2)),
    ];
    _gasHe = [
      TextEditingController(text: n(g1.he)),
      TextEditingController(text: n(g2.he)),
      TextEditingController(text: n(g3.he)),
    ];
  }

  @override
  void dispose() {
    for (final c in [
      _startP,
      _startO2,
      _startHe,
      _targetP,
      _targetO2,
      _targetHe,
      ..._gasO2,
      ..._gasHe,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  void _updateMix(
    StateProvider<GasMix> provider,
    TextEditingController o2,
    TextEditingController he,
  ) {
    ref.read(provider.notifier).state = GasMix(
      o2: _num(o2.text),
      he: _num(he.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outcome = ref.watch(blenderResultProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cylinderCard(context),
              const SizedBox(height: 16),
              _fillGasesCard(context),
              const SizedBox(height: 16),
              _resultCard(context, outcome),
              const SizedBox(height: 16),
              _aboutCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _cylinderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context.l10n.gasCalculators_blender_startCylinder),
            _mixRow(
              pressureController: _startP,
              o2Controller: _startO2,
              heController: _startHe,
              onPressure: (v) =>
                  ref.read(blenderStartPressureProvider.notifier).state = _units
                      .pressureToBar(_num(v)),
              onMix: () =>
                  _updateMix(blenderStartMixProvider, _startO2, _startHe),
            ),
            const SizedBox(height: 20),
            _sectionTitle(context.l10n.gasCalculators_blender_targetFill),
            _mixRow(
              pressureController: _targetP,
              o2Controller: _targetO2,
              heController: _targetHe,
              onPressure: (v) =>
                  ref.read(blenderTargetPressureProvider.notifier).state =
                      _units.pressureToBar(_num(v)),
              onMix: () =>
                  _updateMix(blenderTargetMixProvider, _targetO2, _targetHe),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fillGasesCard(BuildContext context) {
    final providers = [
      blenderFillGas1Provider,
      blenderFillGas2Provider,
      blenderFillGas3Provider,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context.l10n.gasCalculators_blender_fillGases),
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _mixRow(
                leading: '${i + 1}.',
                o2Controller: _gasO2[i],
                heController: _gasHe[i],
                onMix: () => _updateMix(providers[i], _gasO2[i], _gasHe[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A row of pressure (optional) + O₂ + He fields.
  Widget _mixRow({
    String? leading,
    TextEditingController? pressureController,
    ValueChanged<String>? onPressure,
    required TextEditingController o2Controller,
    required TextEditingController heController,
    required VoidCallback onMix,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (leading != null)
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 14),
            child: Text(leading, style: Theme.of(context).textTheme.titleSmall),
          ),
        if (pressureController != null) ...[
          Expanded(
            flex: 3,
            child: _field(
              controller: pressureController,
              label: context.l10n.gasCalculators_blender_pressure,
              suffix: _units.pressureSymbol,
              onChanged: onPressure!,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 2,
          child: _field(
            controller: o2Controller,
            label: context.l10n.gasCalculators_blender_o2,
            suffix: '%',
            onChanged: (_) => onMix(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _field(
            controller: heController,
            label: context.l10n.gasCalculators_blender_he,
            suffix: '%',
            onChanged: (_) => onMix(),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  String _gasName(GasMix m) {
    if (m.he > 0.5) {
      return 'TMX ${m.o2.round()}/${m.he.round()}';
    }
    if ((m.o2 - 21).abs() < 0.5) return context.l10n.gasCalculators_blender_air;
    if (m.o2 >= 99.5) return 'O₂';
    return 'EAN${m.o2.round()}';
  }

  Widget _resultCard(BuildContext context, BlenderOutcome outcome) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (outcome.error != null) {
      return Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorText(context, outcome.error!),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final steps = outcome.result!.steps;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.gasCalculators_blender_procedure,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _stepText(context, steps[i], i, steps.length),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            const Divider(height: 24),
            Text(
              context.l10n.gasCalculators_blender_amounts,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                for (final s in steps.where((s) => s.fillGas != null))
                  '${_gasName(s.fillGas!)}: ${s.addedVolumePerLiter!.toStringAsFixed(1)} L',
              ].join('   ·   '),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepText(BuildContext context, BlendStep step, int index, int total) {
    final pressure = _units.formatPressure(step.pressureBar);
    if (step.fillGas == null) {
      return '${index + 1}. ${context.l10n.gasCalculators_blender_stepStart(pressure, _gasName(step.resultingMix))}';
    }
    return '${index + 1}. ${context.l10n.gasCalculators_blender_stepFill(_gasName(step.fillGas!), pressure, _gasName(step.resultingMix))}';
  }

  String _errorText(BuildContext context, BlendError error) {
    switch (error) {
      case BlendError.targetPressureNotHigher:
        return context.l10n.gasCalculators_blender_error_targetPressure;
      case BlendError.invalidMix:
        return context.l10n.gasCalculators_blender_error_invalidMix;
      case BlendError.identicalNitroxGases:
        return context.l10n.gasCalculators_blender_error_identicalGases;
      case BlendError.linearlyDependentGases:
        return context.l10n.gasCalculators_blender_error_linearlyDependent;
      case BlendError.negativeAmountRequired:
        return context.l10n.gasCalculators_blender_error_negativeAmount;
    }
  }

  Widget _aboutCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.gasCalculators_blender_about,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.gasCalculators_blender_aboutBody,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
