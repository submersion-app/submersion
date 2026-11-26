import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/trim_calculator/presentation/providers/trim_calculator_providers.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_dive_picker.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_tryout_controller.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_tryout_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The Trim Calculator, a Planning tool (issue #5028): a logged dive's rig on
/// the posable figure, to move lead and gear, try test items, pose and time.
///
/// It opens on [diveId], as the dive's Weights and buoyancy card links it,
/// or on the diver's latest dive from the Planning hub; Change dive picks
/// another. Nothing here is saved.
class TrimCalculatorPage extends ConsumerStatefulWidget {
  const TrimCalculatorPage({super.key, this.diveId, this.embedded = false});

  final String? diveId;

  /// Renders without its own Scaffold and AppBar, for the Planning detail
  /// pane. See [PlanningToolPane].
  final bool embedded;

  static const changeDiveKey = ValueKey('trim-calculator-change-dive');

  /// Wide windows keep the figure at a readable size rather than stretching
  /// it across the whole page.
  static const double maxContentWidth = 720;

  @override
  ConsumerState<TrimCalculatorPage> createState() => _TrimCalculatorPageState();
}

class _TrimCalculatorPageState extends ConsumerState<TrimCalculatorPage> {
  /// The dive picked with Change dive, which outranks the one opened on.
  String? _picked;

  Future<void> _changeDive() async {
    final id = await showTrimDivePicker(context);
    if (id != null && mounted) setState(() => _picked = id);
  }

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.planning_card_trimCalculator_title;
    final content = _content(context);
    if (widget.embedded) {
      return PlanningToolPane(title: title, child: content);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: content,
    );
  }

  Widget _content(BuildContext context) {
    final id = _picked ?? widget.diveId;
    if (id != null) {
      return _DiveTrim(
        key: ValueKey(id),
        diveId: id,
        onChangeDive: _changeDive,
      );
    }
    return ref
        .watch(trimCalculatorLatestDiveIdProvider)
        .when(
          data: (latest) => latest == null
              ? _Message(text: context.l10n.trim_calculator_noDives)
              : _DiveTrim(
                  key: ValueKey(latest),
                  diveId: latest,
                  onChangeDive: _changeDive,
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(text: error.toString()),
        );
  }
}

/// One dive in the calculator: its name and Change dive, then the figure
/// and its controls once the buoyancy model has an outcome.
class _DiveTrim extends ConsumerStatefulWidget {
  const _DiveTrim({
    super.key,
    required this.diveId,
    required this.onChangeDive,
  });

  final String diveId;
  final VoidCallback onChangeDive;

  @override
  ConsumerState<_DiveTrim> createState() => _DiveTrimState();
}

class _DiveTrimState extends ConsumerState<_DiveTrim> {
  TrimSceneBase? _base;
  TrimTryoutController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// The controller for this dive, outcome and body. Rebuilt only when one
  /// of them changes (a saved edit, a new body weight), which starts the
  /// try-out over on the new rig.
  TrimTryoutController _controllerFor(
    Dive dive,
    BuoyancyTwinOutcome outcome,
    ({double? height, double? mass, DiverSex? sex}) body,
  ) {
    final b = _base;
    final c = _controller;
    if (b != null &&
        c != null &&
        identical(b.dive, dive) &&
        identical(b.outcome, outcome) &&
        b.heightCm == body.height &&
        b.bodyMassKg == body.mass &&
        b.sex == body.sex) {
      return c;
    }
    final base = _base = TrimSceneBase(
      dive: dive,
      outcome: outcome,
      heightCm: body.height,
      bodyMassKg: body.mass,
      sex: body.sex,
    );
    // The old controller may still be listened to by the frame being built
    // over; let it go once that frame is done.
    final old = _controller;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return _controller = TrimTryoutController(
      sceneAt: base.at,
      openingTimestamp: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    final diveAsync = ref.watch(diveProvider(widget.diveId));
    final outcomeAsync = ref.watch(buoyancyTwinProvider(widget.diveId));
    final height = ref.watch(latestDiverHeightProvider).value;
    final mass = ref.watch(latestDiverWeightProvider).value?.weightKg;
    final sex = ref.watch(diverBodyProfileProvider).value?.sex;
    final l10n = context.l10n;

    final dive = diveAsync.value;
    if (dive == null) {
      if (diveAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _Message(
        text: l10n.trim_calculator_diveMissing,
        onChangeDive: widget.onChangeDive,
      );
    }

    final header = _DiveHeader(
      dive: dive,
      units: units,
      onChangeDive: widget.onChangeDive,
    );
    // AsyncValue.value keeps the last outcome while the model reloads, so
    // the figure stays on screen behind a refresh.
    final outcome = outcomeAsync.value;
    final Widget body;
    if (outcome != null) {
      final controller = _controllerFor(dive, outcome, (
        height: height,
        mass: mass,
        sex: sex,
      ));
      body = TrimTryoutView(
        controller: controller,
        moments: [
          for (final s in outcome.result.samples)
            TrimMoment(timestamp: s.timestamp, depthM: s.depthM),
        ],
        units: units,
      );
    } else if (outcomeAsync.isLoading) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.trim_calculator_cannotModel),
      );
    }

    // Clears the keyboard while a test item is typed.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TrimCalculatorPage.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (outcome != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.trim_card_caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// The dive shown: its number and site (or its date), and Change dive.
class _DiveHeader extends StatelessWidget {
  const _DiveHeader({
    required this.dive,
    required this.units,
    required this.onChangeDive,
  });

  final Dive dive;
  final UnitFormatter units;
  final VoidCallback onChangeDive;

  @override
  Widget build(BuildContext context) {
    final label = trimDiveLabel(
      number: dive.diveNumber,
      site: dive.site?.name,
      when: dive.entryTime ?? dive.dateTime,
      units: units,
    );
    return ListTile(
      leading: const Icon(Icons.scuba_diving),
      title: Text(label.title),
      // Change dive goes on its own line: a text button in trailing would
      // squeeze the title once translated.
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.subtitle != null) Text(label.subtitle!),
          TileSubtitleAction(
            actionKey: TrimCalculatorPage.changeDiveKey,
            label: context.l10n.trim_calculator_changeDive,
            onPressed: onChangeDive,
          ),
        ],
      ),
    );
  }
}

/// A centred line for a state with no figure, with Change dive when another
/// dive would help.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.onChangeDive});

  final String text;
  final VoidCallback? onChangeDive;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onChangeDive != null) ...[
            const SizedBox(height: 12),
            TextButton(
              key: TrimCalculatorPage.changeDiveKey,
              onPressed: onChangeDive,
              child: Text(context.l10n.trim_calculator_changeDive),
            ),
          ],
        ],
      ),
    ),
  );
}
