import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_conditions_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_fill_gases_card.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_volume_conversion.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_manager.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Trimix Mixer's own settings, reached both from the calculator's
/// settings gear and from the global Settings page (issue #1335 follow-up):
/// fill gases, mixing conditions, and saved target-fill mixes, kept off the
/// always-visible calculator so the fields a diver sets once per session
/// don't compete with the ones they retype every fill. Billing has no
/// defaults of its own left to configure here: the currency always follows
/// Settings -> Units -> Default currency (issue #44 follow-up removed the
/// mixer's own, now-redundant read-only mirror of that setting).
class BlenderSettingsPage extends ConsumerWidget {
  const BlenderSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Settings > Manage > Data reaches this page on its own route, so the
    // calculator -- until now the only thing that started the load -- never
    // mounts. Without this watch every card below shows a hard-coded default,
    // and because saving writes the whole preferences blob at once, the first
    // edit here would take the diver's saved mixes, billed fills and
    // last-entered pressures down with it.
    ref.watch(blenderPreferencesLoaderProvider);
    // The load resolves after the first build and bumps the epoch. Re-keying
    // on it rebuilds the body, and with it the controllers each card seeds in
    // its own initState, onto the freshly loaded values -- the same contract
    // the calculator uses for its own fields.
    final epoch = ref.watch(blenderResetEpochProvider);
    return _BlenderSettingsBody(key: ValueKey(epoch));
  }
}

class _BlenderSettingsBody extends ConsumerStatefulWidget {
  const _BlenderSettingsBody({super.key});

  @override
  ConsumerState<_BlenderSettingsBody> createState() =>
      _BlenderSettingsBodyState();
}

class _BlenderSettingsBodyState extends ConsumerState<_BlenderSettingsBody> {
  late final TextEditingController _topupO2;
  late final List<TextEditingController> _gasPrices;
  late final List<TextEditingController> _flushVolumes;

  @override
  void initState() {
    super.initState();
    String n(double v) => formatDecimalForInput(v);

    _topupO2 = TextEditingController(
      text: n(ref.read(blenderTopupO2PercentProvider)),
    );

    final settings = ref.read(settingsProvider);
    _gasPrices = [
      for (final p in ref.read(blenderGasPricesProvider))
        TextEditingController(
          text: p == null
              ? ''
              : formatRoundedForInput(
                  pricePer100LitersToDisplay(p, settings),
                  2,
                ),
        ),
    ];
    _flushVolumes = [
      for (final g in ref.read(blenderFlushFeeGasesProvider))
        TextEditingController(
          text: formatRoundedForInput(
            litersToDisplayVolume(g.volumeLiters, settings),
            2,
          ),
        ),
    ];
  }

  @override
  void dispose() {
    _topupO2.dispose();
    for (final c in _gasPrices) {
      c.dispose();
    }
    for (final c in _flushVolumes) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_trimixMixer_title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlenderFillGasesCard(
                  topupO2Controller: _topupO2,
                  priceControllers: _gasPrices,
                  flushVolumeControllers: _flushVolumes,
                ),
                const SizedBox(height: 16),
                const BlenderConditionsCard(),
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: MixTemplateManager(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
