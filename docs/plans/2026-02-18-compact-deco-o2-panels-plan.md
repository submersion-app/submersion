# Compact Deco & O2 Toxicity Panels Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the dive profile chart, decompression status, and oxygen toxicity sections all visible on screen simultaneously by creating compact panel variants and a responsive layout.

**Architecture:** Two new compact widgets (`CompactDecoPanel`, `CompactO2ToxicityPanel`) added alongside existing full-size widgets. A new `_buildDecoO2Panel` method in the dive detail page uses `ResponsiveBreakpoints.isDesktop` to arrange them side-by-side (desktop) or stacked (phone). Tapping a compact panel expands it to the full-size view using existing Riverpod providers.

**Tech Stack:** Flutter, Riverpod, Material 3

---

### Task 1: Change Default Expanded State to False

The current provider defaults both deco and O2 sections to `expanded: true`. Since compact is now the default view, flip these to `false`.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart:27-28`

**Step 1: Change the defaults**

In `CollapsibleSectionState`, change the default values for `decoExpanded` and `o2ToxicityExpanded` from `true` to `false`:

```dart
const CollapsibleSectionState({
  this.decoExpanded = false,
  this.o2ToxicityExpanded = false,
  this.sacSegmentsExpanded = true,
  this.equipmentExpanded = true,
  this.tideExpanded = true,
});
```

Also change the fallback values in `_loadState()` on lines 64 and 66:

```dart
decoExpanded:
    _prefs.getBool(DiveDetailUiKeys.decoSectionExpanded) ?? false,
o2ToxicityExpanded:
    _prefs.getBool(DiveDetailUiKeys.o2ToxicitySectionExpanded) ?? false,
```

**Step 2: Verify the app still builds**

Run: `flutter analyze lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart
git commit -m "refactor: default deco and O2 sections to collapsed state"
```

---

### Task 2: Create CompactDecoPanel Widget

Add a compact decompression status widget below the existing `DecoInfoPanel` class in the same file.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/deco_info_panel.dart`

**Step 1: Add CompactDecoPanel class**

Add the following widget after the `DecoInfoPanel` class (before `NdlBadge`, around line 403). This widget shows all the deco data in a condensed format:

```dart
/// Compact decompression status panel for space-constrained layouts.
///
/// Shows all deco data (metrics, tissue chart, GF, deco stops) in a
/// condensed card format. Tapping the card triggers [onTap] to expand
/// to the full [DecoInfoPanel].
class CompactDecoPanel extends StatelessWidget {
  /// Current decompression status
  final DecoStatus status;

  /// Optional subtitle (e.g., "At 12:30")
  final String? subtitle;

  /// Callback when the panel is tapped to expand
  final VoidCallback? onTap;

  const CompactDecoPanel({
    super.key,
    required this.status,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      status.inDeco ? Icons.warning : Icons.check_circle,
                      size: 16,
                      color: status.inDeco ? Colors.orange : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.diveLog_detail_section_decoStatus,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: status.inDeco
                        ? context.l10n.diveLog_deco_semantics_required
                        : context.l10n.diveLog_deco_semantics_notRequired,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status.inDeco
                            ? Colors.orange.withValues(alpha: 0.2)
                            : Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.inDeco
                            ? context.l10n.diveLog_deco_badge_deco
                            : context.l10n.diveLog_deco_badge_noDeco,
                        style: textTheme.labelSmall?.copyWith(
                          color: status.inDeco ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Compact metrics row
              Row(
                children: [
                  Expanded(
                    child: _buildCompactMetric(
                      context,
                      label: status.inDeco
                          ? context.l10n.diveLog_deco_label_ceiling
                          : context.l10n.diveLog_deco_label_ndl,
                      value: status.inDeco
                          ? '${status.ceilingMeters.toStringAsFixed(1)}m'
                          : status.ndlFormatted,
                      color: status.inDeco ? Colors.orange : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactMetric(
                      context,
                      label: context.l10n.diveLog_deco_label_tts,
                      value: status.ttsFormatted,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactMetric(
                      context,
                      label: context.l10n.diveLog_deco_label_leading,
                      value:
                          '#${status.leadingCompartmentNumber} ${status.leadingCompartmentLoading.toStringAsFixed(0)}%',
                      color: _getLoadingColor(
                        status.leadingCompartmentLoading,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Compact tissue chart
              Semantics(
                label: chartSummaryLabel(
                  chartType: 'Tissue loading bar',
                  description:
                      '${status.compartments.length} compartments, leading compartment ${status.leadingCompartmentNumber} at ${status.leadingCompartmentLoading.toStringAsFixed(0)} percent',
                ),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: status.compartments.map((comp) {
                      final loading = comp.percentLoading.clamp(0.0, 120.0);
                      final normalizedHeight =
                          (loading / 120.0).clamp(0.0, 1.0);
                      final color = _getLoadingColor(loading);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.5),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(1),
                              ),
                            ),
                            child: FractionallySizedBox(
                              heightFactor: normalizedHeight,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // GF + deco stops row
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'GF: ${(status.gfLow * 100).toInt()}/${(status.gfHigh * 100).toInt()}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (status.decoStops.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.diveLog_deco_sectionDecoStops,
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...status.decoStops.take(3).map(
                      (stop) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${stop.depthFormatted()} ${stop.durationFormatted}',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetric(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLoadingColor(double loading) {
    if (loading >= 100) return Colors.red;
    if (loading >= 80) return Colors.orange;
    if (loading >= 60) return Colors.amber;
    return Colors.green;
  }
}
```

**Step 2: Verify the file compiles**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/deco_info_panel.dart`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/deco_info_panel.dart
git commit -m "feat: add CompactDecoPanel widget for condensed deco display"
```

---

### Task 3: Create CompactO2ToxicityPanel Widget

Add a compact oxygen toxicity widget below the existing `O2ToxicityCard` class in the same file.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart`

**Step 1: Add CompactO2ToxicityPanel class**

Add the following widget after the `O2ToxicityCard` class (before `O2ToxicityBadge`, around line 355). This shows all O2 tox data in condensed format:

```dart
/// Compact oxygen toxicity panel for space-constrained layouts.
///
/// Shows CNS progress, OTU, and key details in a condensed card format.
/// Tapping the card triggers [onTap] to expand to the full [O2ToxicityCard].
class CompactO2ToxicityPanel extends StatelessWidget {
  /// Oxygen exposure data
  final O2Exposure exposure;

  /// Optional ppO2 at selected profile point
  final double? selectedPpO2;

  /// Callback when the panel is tapped to expand
  final VoidCallback? onTap;

  const CompactO2ToxicityPanel({
    super.key,
    required this.exposure,
    this.selectedPpO2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color getProgressColor() {
      if (exposure.cnsEnd >= 100) return colorScheme.error;
      if (exposure.cnsEnd >= 80) return Colors.orange;
      if (exposure.cnsEnd >= 50) return Colors.amber;
      return Colors.green;
    }

    Color getOtuColor() {
      if (exposure.otuPercentOfDaily >= 100) return colorScheme.error;
      if (exposure.otuPercentOfDaily >= 80) return Colors.orange;
      if (exposure.otuPercentOfDaily >= 50) return Colors.amber;
      return Colors.green;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.air,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.diveLog_detail_section_oxygenToxicity,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (exposure.cnsWarning || exposure.ppO2Warning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: exposure.cnsCritical || exposure.ppO2Critical
                            ? colorScheme.error
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        exposure.cnsCritical || exposure.ppO2Critical
                            ? context.l10n.diveLog_detail_badge_critical
                            : context.l10n.diveLog_detail_badge_warning,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // CNS progress (compact)
              Semantics(
                label: statLabel(
                  name: context.l10n.diveLog_o2tox_cnsOxygenClock,
                  value: exposure.cnsFormatted,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.diveLog_o2tox_cnsOxygenClock,
                          style: textTheme.bodySmall,
                        ),
                        Text(
                          exposure.cnsFormatted,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: getProgressColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (exposure.cnsEnd / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          getProgressColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.diveLog_o2tox_startPercent(
                            exposure.cnsStart.toStringAsFixed(0),
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          context.l10n.diveLog_o2tox_deltaDive(
                            exposure.cnsDelta.toStringAsFixed(1),
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // OTU + details row
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: context.l10n.diveLog_o2tox_semantics_otu(
                        exposure.otuFormatted,
                        exposure.otuPercentOfDaily.toStringAsFixed(0),
                      ),
                      child: Row(
                        children: [
                          Text(
                            exposure.otuFormatted,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: getOtuColor(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${exposure.otuPercentOfDaily.toStringAsFixed(0)}%)',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Max ppO2 inline
                  Text(
                    '${context.l10n.diveLog_o2tox_label_maxPpO2}: ${exposure.maxPpO2Formatted}',
                    style: textTheme.labelSmall?.copyWith(
                      color: exposure.ppO2Critical
                          ? colorScheme.error
                          : exposure.ppO2Warning
                              ? Colors.orange
                              : colorScheme.onSurfaceVariant,
                      fontWeight: exposure.ppO2Warning
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              // Time above thresholds (only if >0)
              if (exposure.timeAboveWarning > 0 ||
                  exposure.timeAboveCritical > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (exposure.timeAboveWarning > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${context.l10n.diveLog_o2tox_label_timeAbove14}: ${_formatDuration(exposure.timeAboveWarning)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    if (exposure.timeAboveCritical > 0)
                      Text(
                        '${context.l10n.diveLog_o2tox_label_timeAbove16}: ${_formatDuration(exposure.timeAboveCritical)}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ],

              // Selected point ppO2
              if (selectedPpO2 != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.air,
                        size: 12,
                        color: _getPpO2Color(selectedPpO2!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${context.l10n.diveLog_detail_label_ppO2AtPoint}: ${selectedPpO2!.toStringAsFixed(2)} bar',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _getPpO2Color(selectedPpO2!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${minutes}m';
    return '${minutes}m ${secs}s';
  }

  Color _getPpO2Color(double ppO2) {
    if (ppO2 >= 1.6) return Colors.red;
    if (ppO2 >= 1.4) return Colors.orange;
    return Colors.green;
  }
}
```

**Step 2: Verify the file compiles**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/o2_toxicity_card.dart
git commit -m "feat: add CompactO2ToxicityPanel widget for condensed O2 display"
```

---

### Task 4: Replace Deco/O2 Sections in Dive Detail Page

Replace the separate `_buildDecoSection` and `_buildO2ToxicitySection` methods with a single `_buildDecoO2Panel` that uses responsive layout.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Step 1: Replace the two section calls in `_buildContent`**

In `_buildContent` (around lines 203-206), replace the two separate section calls and the gap between them with a single call:

Find this block:
```dart
              _buildDecoSection(context, ref, dive),
              const SizedBox(height: 24),
              _buildO2ToxicitySection(context, ref, dive),
```

Replace with:
```dart
              _buildDecoO2Panel(context, ref, dive),
```

**Step 2: Add the `_buildDecoO2Panel` method**

Add this new method in the `_DiveDetailPageState` class (right before or after where `_buildDecoSection` used to be, around line 1035). This method handles the responsive layout logic:

```dart
  Widget _buildDecoO2Panel(BuildContext context, WidgetRef ref, Dive dive) {
    final analysis = ref.watch(diveProfileAnalysisProvider(dive));

    // Don't show if no analysis available
    if (analysis == null || analysis.decoStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    // Deco status at selected point or end of dive
    final decoIndex =
        _selectedPointIndex != null &&
            _selectedPointIndex! < analysis.decoStatuses.length
        ? _selectedPointIndex!
        : analysis.decoStatuses.length - 1;
    final decoStatus = analysis.decoStatuses[decoIndex];

    // O2 exposure
    final exposure = analysis.o2Exposure;

    // Selected ppO2 at point
    final selectedPpO2 =
        _selectedPointIndex != null &&
            _selectedPointIndex! < analysis.ppO2Curve.length
        ? analysis.ppO2Curve[_selectedPointIndex!]
        : null;

    // Expanded states
    final decoExpanded = ref.watch(decoSectionExpandedProvider);
    final o2Expanded = ref.watch(o2ToxicitySectionExpandedProvider);

    // "At time" subtitle for selected point
    final String? timeSubtitle = _selectedPointIndex != null
        ? context.l10n.diveLog_detail_collapsed_atTime(
            _formatTimestamp(dive.profile[_selectedPointIndex!].timestamp),
          )
        : null;

    // Build deco widget (compact or expanded)
    final decoWidget = decoExpanded
        ? _buildExpandedDecoCard(context, ref, dive, decoStatus, timeSubtitle)
        : CompactDecoPanel(
            status: decoStatus,
            subtitle: timeSubtitle,
            onTap: () {
              ref.read(collapsibleSectionProvider.notifier).setDecoExpanded(true);
            },
          );

    // Build O2 widget (compact or expanded)
    final o2Widget = o2Expanded
        ? _buildExpandedO2Card(context, ref, dive, exposure, selectedPpO2)
        : CompactO2ToxicityPanel(
            exposure: exposure,
            selectedPpO2: selectedPpO2,
            onTap: () {
              ref.read(collapsibleSectionProvider.notifier).setO2ToxicityExpanded(true);
            },
          );

    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    // If either is expanded, always use Column layout
    if (decoExpanded || o2Expanded) {
      return Column(
        children: [
          decoWidget,
          const SizedBox(height: 8),
          o2Widget,
        ],
      );
    }

    // Both compact: side-by-side on desktop, stacked on phone
    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: decoWidget),
            const SizedBox(width: 8),
            Expanded(child: o2Widget),
          ],
        ),
      );
    }

    // Phone: stacked compact
    return Column(
      children: [
        decoWidget,
        const SizedBox(height: 8),
        o2Widget,
      ],
    );
  }

  /// Builds the expanded deco card with collapse ability.
  Widget _buildExpandedDecoCard(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    DecoStatus status,
    String? timeSubtitle,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse header
          InkWell(
            onTap: () {
              ref.read(collapsibleSectionProvider.notifier).setDecoExpanded(false);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    status.inDeco ? Icons.warning : Icons.check_circle,
                    size: 20,
                    color: status.inDeco ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.diveLog_detail_section_decoStatus,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Show "at time" indicator when a point is selected
          if (_selectedPointIndex != null && timeSubtitle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.timeline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeSubtitle,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedPointIndex = null),
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(context.l10n.diveLog_detail_button_showEnd),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          DecoInfoPanel(
            status: status,
            showTissueChart: true,
            showDecoStops: true,
            showHeader: false,
            useCard: false,
          ),
        ],
      ),
    );
  }

  /// Builds the expanded O2 toxicity card with collapse ability.
  Widget _buildExpandedO2Card(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    O2Exposure exposure,
    double? selectedPpO2,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse header
          InkWell(
            onTap: () {
              ref.read(collapsibleSectionProvider.notifier).setO2ToxicityExpanded(false);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.air,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.diveLog_detail_section_oxygenToxicity,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (exposure.cnsWarning || exposure.ppO2Warning)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: exposure.cnsCritical || exposure.ppO2Critical
                              ? Theme.of(context).colorScheme.error
                              : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          exposure.cnsCritical || exposure.ppO2Critical
                              ? context.l10n.diveLog_detail_badge_critical
                              : context.l10n.diveLog_detail_badge_warning,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Selected point ppO2 highlight
          if (selectedPpO2 != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.air,
                      size: 20,
                      color: _getPpO2Color(selectedPpO2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.diveLog_detail_label_ppO2AtPoint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${selectedPpO2.toStringAsFixed(2)} bar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getPpO2Color(selectedPpO2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          O2ToxicityCard(
            exposure: exposure,
            showDetails: true,
            showHeader: false,
            useCard: false,
          ),
        ],
      ),
    );
  }
```

**Step 3: Delete the old `_buildDecoSection` and `_buildO2ToxicitySection` methods**

Remove `_buildDecoSection` (lines ~1035-1160) and `_buildO2ToxicitySection` (lines ~1168-1294) entirely. The new `_buildDecoO2Panel` and its two helper methods replace them.

**Step 4: Verify the app builds**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No issues found.

**Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat: replace deco/O2 sections with responsive compact panels"
```

---

### Task 5: Format, Analyze, and Test

**Step 1: Format all modified files**

Run: `dart format lib/features/dive_log/presentation/`

**Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No issues found.

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass.

**Step 4: Fix any issues**

If analysis or tests reveal problems, fix them before proceeding.

**Step 5: Final commit if formatting changed anything**

```bash
git add -A
git commit -m "chore: format compact deco/O2 panel code"
```

---

### Task 6: Visual Verification

**Step 1: Run the app on macOS (desktop)**

Run: `flutter run -d macos`

Verify:
- Navigate to a dive with profile data
- Profile chart, compact deco, and compact O2 are all visible without scrolling
- Deco and O2 panels are side-by-side below the chart
- Tapping a compact panel expands it to full width below the other
- Tapping the expanded panel header collapses it back to compact
- Selected point on chart updates both panels

**Step 2: Narrow the window to phone width (<800px)**

Verify:
- Compact panels stack vertically (not side-by-side)
- All three sections still fit on screen
- Expand/collapse still works in stacked mode

**Step 3: Test edge cases**

- Dive with no profile data: sections should not appear
- Dive in decompression: DECO badge, ceiling, deco stops visible in compact
- Dive with high CNS/ppO2: warning/critical badges visible in compact
- Select a point on the chart: both panels update with point-specific data

---
