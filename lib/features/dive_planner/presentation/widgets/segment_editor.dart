import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _uuid = Uuid();

/// Dialog for creating and editing dive plan segments.
///
/// A segment is a waypoint: a depth to reach and a time to spend. It has no
/// declared type, so there is no type picker and no field that a type choice
/// could rewrite. Whether the leg reads as a descent, a level or an ascent
/// follows from [startDepth] and the depth entered, and is shown back to the
/// diver as they type.
class SegmentEditor extends ConsumerStatefulWidget {
  /// Segment to edit (null for a new segment).
  final PlanSegment? segment;

  /// Where this leg begins, in meters: the previous segment's target depth, or
  /// 0 for the first segment in the plan.
  ///
  /// Not editable. It is a property of the segment's position in the profile,
  /// so the only way to change it is to change the segment before this one.
  final double startDepth;

  /// Available tanks for gas selection.
  final List<DiveTank> availableTanks;

  /// Callback when segment is saved.
  final ValueChanged<PlanSegment> onSave;

  const SegmentEditor({
    super.key,
    this.segment,
    this.startDepth = 0,
    required this.availableTanks,
    required this.onSave,
  });

  @override
  ConsumerState<SegmentEditor> createState() => _SegmentEditorState();
}

class _SegmentEditorState extends ConsumerState<SegmentEditor> {
  late TextEditingController _depthController;
  late TextEditingController _durationController;
  late String _selectedTankId;
  bool _unitsInitialized = false;

  @override
  void initState() {
    super.initState();
    final segment = widget.segment;

    // Initialize with raw meter values - will convert in first build.
    // Every seed goes through formatDecimalForInput so the diver's locale
    // decides the separator and the parse half can read it back (#1091).
    // A new segment seeds at the depth it starts from, which makes it a level
    // leg until the diver changes it.
    _depthController = TextEditingController(
      text: formatDecimalForInput(
        (segment?.targetDepth ?? widget.startDepth).roundToDouble(),
      ),
    );
    _durationController = TextEditingController(
      text: formatDecimalForInput(
        segment != null ? (segment.durationSeconds ~/ 60).toDouble() : 20,
      ),
    );
    _selectedTankId = segment?.tankId ?? widget.availableTanks.first.id;
  }

  @override
  void dispose() {
    _depthController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.segment == null;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // Convert meter values to user's preferred units on first build
    if (!_unitsInitialized) {
      _unitsInitialized = true;
      _convertControllersToUserUnits(units);
    }

    return AlertDialog(
      title: Text(
        isNew
            ? context.l10n.divePlanner_segmentEditor_addTitle
            : context.l10n.divePlanner_segmentEditor_editTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // What the numbers below add up to. Shown rather than asked, so
            // the inference is visible instead of magic.
            _DerivedPhaseLine(summary: _phaseSummary(units)),
            const SizedBox(height: 16),

            // Target depth
            TextField(
              controller: _depthController,
              decoration: InputDecoration(
                labelText: context.l10n.divePlanner_segmentEditor_depth(
                  units.depthSymbol,
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Duration input
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: context.l10n.divePlanner_segmentEditor_duration,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Tank selection
            InputDecorator(
              decoration: InputDecoration(
                labelText: context.l10n.divePlanner_segmentEditor_tankGas,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTankId,
                  isExpanded: true,
                  isDense: true,
                  items: widget.availableTanks.map((tank) {
                    return DropdownMenuItem(
                      value: tank.id,
                      child: Text(tank.name ?? tank.gasMix.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTankId = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }

  /// The phase and rate implied by the fields as they currently stand.
  ///
  /// Only descent, ascent and level are distinguishable here: telling a deco
  /// stop from the bottom needs the rest of the profile, so the segment list
  /// makes that call, not this dialog.
  String _phaseSummary(UnitFormatter units) {
    final l10n = context.l10n;
    final targetUserUnits = parseUserDecimal(_depthController.text) ?? 0;
    final targetMeters = units.depthToMeters(targetUserUnits);
    final durationMinutes = parseUserInt(_durationController.text) ?? 0;
    final startDisplay = units.formatDepth(widget.startDepth, decimals: 0);
    final targetDisplay = units.formatDepth(targetMeters, decimals: 0);

    if (targetMeters == widget.startDepth) {
      return l10n.divePlanner_segmentEditor_derivedLevel(targetDisplay);
    }

    // A rate needs a duration to divide by; without one the leg is an
    // instantaneous depth change and only its direction is known.
    final rateDisplay = durationMinutes > 0
        ? units.formatDepth(
            (targetMeters - widget.startDepth).abs() / durationMinutes,
            decimals: 1,
          )
        : null;

    if (targetMeters > widget.startDepth) {
      return rateDisplay == null
          ? l10n.divePlanner_segmentEditor_derivedDescentNoRate(
              startDisplay,
              targetDisplay,
            )
          : l10n.divePlanner_segmentEditor_derivedDescent(
              startDisplay,
              targetDisplay,
              rateDisplay,
            );
    }
    return rateDisplay == null
        ? l10n.divePlanner_segmentEditor_derivedAscentNoRate(
            startDisplay,
            targetDisplay,
          )
        : l10n.divePlanner_segmentEditor_derivedAscent(
            startDisplay,
            targetDisplay,
            rateDisplay,
          );
  }

  /// Convert controller values from meters to user's preferred units.
  void _convertControllersToUserUnits(UnitFormatter units) {
    final depthMeters = parseUserDecimal(_depthController.text) ?? 0;
    _depthController.text = formatDecimalForInput(
      units.convertDepth(depthMeters).roundToDouble(),
    );
  }

  void _save() {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);

    final selectedTank = widget.availableTanks.firstWhere(
      (t) => t.id == _selectedTankId,
    );

    // Parse values in user's units and convert to meters for storage
    final depthUserUnits = parseUserDecimal(_depthController.text) ?? 0;
    final durationMinutes = parseUserInt(_durationController.text) ?? 0;

    final existing = widget.segment;
    final segment = PlanSegment(
      id: existing?.id ?? _uuid.v4(),
      targetDepth: units.depthToMeters(depthUserUnits),
      durationSeconds: durationMinutes * 60,
      tankId: _selectedTankId,
      gasMix: selectedTank.gasMix,
      // Carried through rather than dropped: the old editor rebuilt the
      // segment from the fields alone and lost the CCR setpoint and the
      // dive-mode override on every edit round-trip.
      setpointBar: existing?.setpointBar,
      diveModeOverride: existing?.diveModeOverride,
      order: existing?.order ?? 0,
    );

    widget.onSave(segment);
    Navigator.pop(context);
  }
}

class _DerivedPhaseLine extends StatelessWidget {
  const _DerivedPhaseLine({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        summary,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
