import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/utils/hours_minutes.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_logged_dive_view.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/planned_dive_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The bar across the top of the dive profile that moves between the dives
/// of a repetitive series (issue #3565):
///
///                 1:00                       1:30
///   [(diver) #213]  ~~  [(diver) Morning dive]  ~~  [(diver) B]   (+)
///
/// Each logged dive the series follows is a solid diver and its name, else
/// its dive number; each planned dive is an outlined diver and its name, or its
/// letter while it has none; each surface interval is its time above two
/// waves. Tapping a planned dive selects it, and tapping a logged one shows
/// it read-only; + adds a dive after the last one. The selected dive can be
/// removed from its chip. A dot marks a dive with a warning: red when any is
/// critical, orange otherwise. Wider than the screen, the dives scroll by
/// touch or mouse drag behind faded edges, keeping the selected dive in
/// view.
class PlanSeriesNavigator extends ConsumerStatefulWidget {
  const PlanSeriesNavigator({super.key});

  @override
  ConsumerState<PlanSeriesNavigator> createState() =>
      _PlanSeriesNavigatorState();
}

class _PlanSeriesNavigatorState extends ConsumerState<PlanSeriesNavigator> {
  final _scrollController = ScrollController();
  final _chipKeys = <String, GlobalKey>{};

  static const _fadeWidth = 16.0;

  @override
  void initState() {
    super.initState();
    // Opened on a plan that follows logged dives, the bar starts on the
    // planned dive rather than the oldest logged one.
    _revealSelected();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String diveId) =>
      _chipKeys.putIfAbsent(diveId, GlobalKey.new);

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final series = ref.read(planSeriesNotifierProvider);
      final id =
          ref.read(viewedLoggedDiveProvider)?.id ?? series.selected.state.id;
      final chip = _chipKeys[id]?.currentContext;
      if (chip == null) return;
      Scrollable.ensureVisible(
        chip,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmRemove(int index) async {
    final l10n = context.l10n;
    final letter = seriesDiveLetter(index);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.plannerSeries_removeDive(letter)),
        content: Text(l10n.plannerSeries_removeDive_message(letter)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(planSeriesNotifierProvider.notifier).removeDive(index);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      planSeriesNotifierProvider.select((s) => s.selected.state.id),
      (_, _) => _revealSelected(),
    );
    ref.listen(viewedLoggedDiveProvider, (_, _) => _revealSelected());
    // Following puts logged dives ahead of the selected one.
    ref.listen(
      planSeriesNotifierProvider.select((s) => s.follow),
      (_, _) => _revealSelected(),
    );
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final series = ref.watch(planSeriesNotifierProvider);
    final results = ref.watch(planSeriesResultsProvider);
    final canAdd = ref.watch(canAddSeriesDiveProvider);
    final viewed = ref.watch(viewedLoggedDiveProvider);
    final notifier = ref.read(planSeriesNotifierProvider.notifier);
    final viewedNotifier = ref.read(viewedLoggedDiveIdProvider.notifier);
    final selected = viewed == null ? series.selectedIndex : -1;
    final diveIds = {
      ...?series.follow?.loggedDives.map((dive) => dive.id),
      for (final dive in series.dives) dive.state.id,
    };
    _chipKeys.removeWhere((id, _) => !diveIds.contains(id));

    final items = <Widget>[];
    final logged = series.follow?.loggedDives ?? const [];
    for (var i = 0; i < logged.length; i++) {
      final dive = logged[i];
      if (i > 0) {
        final gap = dive.start.difference(logged[i - 1].end);
        items.add(
          _SurfaceIntervalMark(interval: gap.isNegative ? Duration.zero : gap),
        );
      }
      items.add(
        _LoggedDiveChip(
          key: _keyFor(dive.id),
          label: seriesLoggedDiveLabel(dive, units),
          selected: viewed?.id == dive.id,
          onSelected: () => viewedNotifier.state = dive.id,
        ),
      );
    }

    for (var i = 0; i < series.dives.length; i++) {
      final dive = series.dives[i];
      if (i > 0 || logged.isNotEmpty) {
        items.add(
          _SurfaceIntervalMark(
            interval:
                dive.state.surfaceInterval ?? defaultSeriesSurfaceInterval,
          ),
        );
      }
      // A dive that has been dived goes by what the log calls it.
      if (dive.actual?.followed case final logged?) {
        items.add(
          _LoggedDiveChip(
            key: _keyFor(dive.state.id),
            label: seriesLoggedDiveLabel(logged, units),
            selected: i == selected,
            onSelected: () {
              viewedNotifier.state = null;
              notifier.select(i);
            },
          ),
        );
        continue;
      }
      final worst = _worstWarning(results[i].outcome.issues);
      items.add(
        _DiveChip(
          key: _keyFor(dive.state.id),
          letter: seriesDiveLetter(i),
          name: dive.name,
          selected: i == selected,
          issueColor: worst == null
              ? null
              : planIssueSeverityColor(theme.colorScheme, worst),
          onSelected: () {
            viewedNotifier.state = null;
            notifier.select(i);
          },
          onRemove: i == selected && series.isSeries
              ? () => _confirmRemove(i)
              : null,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final edge = bounds.width <= 0
                  ? 0.0
                  : (_fadeWidth / bounds.width).clamp(0.0, 0.5);
              return LinearGradient(
                colors: const [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, edge, 1 - edge, 1],
              ).createShader(bounds);
            },
            child: ScrollConfiguration(
              // Desktop mice drag the bar too, not only touch.
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: _fadeWidth),
                child: Row(children: items),
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.add),
          tooltip: l10n.plannerSeries_addDive,
          onPressed: canAdd
              ? () {
                  viewedNotifier.state = null;
                  notifier.addDive();
                }
              : null,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _DiveChip extends StatelessWidget {
  const _DiveChip({
    super.key,
    required this.letter,
    this.name,
    required this.selected,
    this.issueColor,
    required this.onSelected,
    this.onRemove,
  });

  final String letter;
  final String? name;
  final bool selected;

  /// The dot's colour, from the dive's worst warning; null = no dot.
  final Color? issueColor;
  final VoidCallback onSelected;
  final VoidCallback? onRemove;

  /// Widest a dive's name runs on its chip before it is cut short.
  static const _maxNameWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = this.name;
    final issueColor = this.issueColor;
    return Semantics(
      label: issueColor != null ? l10n.plannerSeries_hasIssues(letter) : null,
      child: Badge(
        isLabelVisible: issueColor != null,
        smallSize: 8,
        backgroundColor: issueColor,
        child: InputChip(
          avatar: const PlannedDiveIcon(),
          // A named dive goes by its name alone; the letter stays in the
          // tooltip, which the warnings and the remove dialog also use.
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxNameWidth),
            child: Text(
              name ?? letter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          tooltip: name == null
              ? l10n.plannerSeries_dive(letter)
              : l10n.plannerSeries_diveNamed(letter, name),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onSelected(),
          onDeleted: onRemove,
          deleteButtonTooltipMessage: l10n.plannerSeries_removeDive(letter),
        ),
      ),
    );
  }
}

/// A logged dive the series follows: the main menu's diver, solid, and its
/// name, else its dive number. Read-only; tapping it shows the dive.
class _LoggedDiveChip extends StatelessWidget {
  const _LoggedDiveChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(
        Icons.scuba_diving,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _DiveChip._maxNameWidth),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      tooltip: context.l10n.plannerSeries_loggedDive(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

/// The most serious of [issues] worth a dot: red for a critical one, orange
/// for a warning or alert. Info-level notes raise none.
PlanIssueSeverity? _worstWarning(List<PlanIssue> issues) {
  PlanIssueSeverity? worst;
  for (final issue in issues) {
    if (issue.severity == PlanIssueSeverity.info) continue;
    if (worst == null || issue.severity.index > worst.index) {
      worst = issue.severity;
    }
  }
  return worst;
}

/// The surface interval between two dives, as dive computers show it: the
/// time above the sea. A passive separator.
class _SurfaceIntervalMark extends StatelessWidget {
  const _SurfaceIntervalMark({required this.interval});

  final Duration interval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = formatHoursMinutes(interval);
    return Tooltip(
      message: context.l10n.plannerSeries_surfaceIntervalValue(time),
      excludeFromSemantics: true,
      child: Semantics(
        label: context.l10n.plannerSeries_surfaceIntervalValue(time),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              _TwoWaves(color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top two of [Icons.waves]' four lines: the surface, not the deep.
class _TwoWaves extends StatelessWidget {
  const _TwoWaves({required this.color});

  final Color color;

  static const _size = 28.0;

  @override
  Widget build(BuildContext context) {
    // The glyph's lines sit at 16-28% and 34-47% of its height; the window
    // shows 12-51%, stopping short of the third line at 52%.
    return ClipRect(
      child: Align(
        alignment: const Alignment(0, -0.6),
        heightFactor: 0.39,
        child: Icon(Icons.waves, size: _size, color: color),
      ),
    );
  }
}
