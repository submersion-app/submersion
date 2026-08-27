import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_about_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billing_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_conditions_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_cylinder_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_fill_gases_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_invoice_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_procedure_card.dart';
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
    // Changing a unit re-seeds the same way. Provider state is canonical (bar,
    // litres, currency per 100 L), so recreating the controllers reprints
    // every field in the new unit; leaving them alone would show "200" as psi
    // after a bar fill, or a per-100-litre price under a per-100-cu-ft label.
    final units = ref.watch(
      settingsProvider.select((s) => (s.pressureUnit, s.volumeUnit)),
    );
    // Loads the saved templates, prices and blending conditions once. A first
    // run has no stored blob, which is what leaves the seeded templates in
    // place. No AsyncValue branching: the state providers already hold usable
    // defaults while this resolves, so there is nothing to wait for.
    ref.watch(blenderPreferencesLoaderProvider);
    return _GasBlenderBody(
      key: ValueKey('$epoch/${units.$1.name}/${units.$2.name}'),
    );
  }
}

class _GasBlenderBody extends ConsumerStatefulWidget {
  const _GasBlenderBody({super.key});

  @override
  ConsumerState<_GasBlenderBody> createState() => _GasBlenderBodyState();
}

class _GasBlenderBodyState extends ConsumerState<_GasBlenderBody> {
  /// Rebuilt per use so a unit change mid-session is picked up; [build]
  /// watches the settings so the widget actually rebuilds when it happens.
  UnitFormatter get _units => UnitFormatter(ref.read(settingsProvider));

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

    // Seeding must be lossless: a re-seed happens on every pressure-unit
    // change, and rounding would silently rewrite 207.6 bar as 208, or a
    // 32.5% mix as 32%. formatDecimalForInput is also locale-correct, so it
    // pairs with the parseUserDecimal used to read these fields back.
    final decimals = pressureDecimalsFor(
      ref.read(settingsProvider).pressureUnit,
    );
    String p(double bar) =>
        formatRoundedForInput(_units.convertPressure(bar), decimals);
    String n(double v) => formatDecimalForInput(v);

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

  @override
  Widget build(BuildContext context) {
    // Subscribes to unit changes; the value is read through [_units].
    ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlenderCylinderCard(
                startPressure: _startP,
                startO2: _startO2,
                startHe: _startHe,
                targetPressure: _targetP,
                targetO2: _targetO2,
                targetHe: _targetHe,
              ),
              const SizedBox(height: 16),
              BlenderFillGasesCard(
                o2Controllers: _gasO2,
                heControllers: _gasHe,
              ),
              const SizedBox(height: 16),
              const BlenderConditionsCard(),
              const SizedBox(height: 16),
              const BlenderProcedureCard(),
              const SizedBox(height: 16),
              const BlenderAboutCard(),
              const SizedBox(height: 16),
              // Costing goes last, after the safety note, as issue #1100 asks.
              const BlenderBillingCard(),
              const SizedBox(height: 16),
              const BlenderInvoiceCard(),
            ],
          ),
        ),
      ),
    );
  }
}
