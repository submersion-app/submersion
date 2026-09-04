import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Show the dive assignment dialog. Returns a list of selected dive IDs,
/// or null if the user cancelled.
Future<List<String>?> showDiveAssignmentDialog({
  required BuildContext context,
  required List<DiveCandidate> candidates,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DiveAssignmentDialog(candidates: candidates),
  );
}

/// Modal bottom sheet dialog that shows candidate dives grouped by
/// assignment status (unassigned vs on-other-trips).
///
/// Returns the selected dive IDs on confirm, or null on cancel.
class DiveAssignmentDialog extends ConsumerStatefulWidget {
  final List<DiveCandidate> candidates;

  const DiveAssignmentDialog({super.key, required this.candidates});

  @override
  ConsumerState<DiveAssignmentDialog> createState() =>
      _DiveAssignmentDialogState();
}

class _DiveAssignmentDialogState extends ConsumerState<DiveAssignmentDialog> {
  late final Set<String> _selectedIds;
  late final List<DiveCandidate> _unassigned;
  late final List<DiveCandidate> _otherTrip;

  @override
  void initState() {
    super.initState();
    _unassigned = widget.candidates
        .where((c) => c.isUnassigned)
        .toList(growable: false);
    _otherTrip = widget.candidates
        .where((c) => !c.isUnassigned)
        .toList(growable: false);
    // Pre-select all unassigned dives
    _selectedIds = {for (final c in _unassigned) c.dive.id};
  }

  bool _isGroupFullySelected(List<DiveCandidate> group) {
    if (group.isEmpty) return false;
    return group.every((c) => _selectedIds.contains(c.dive.id));
  }

  void _toggleGroup(List<DiveCandidate> group, bool select) {
    setState(() {
      if (select) {
        for (final c in group) {
          _selectedIds.add(c.dive.id);
        }
      } else {
        for (final c in group) {
          _selectedIds.remove(c.dive.id);
        }
      }
    });
  }

  void _toggleDive(String diveId) {
    setState(() {
      if (_selectedIds.contains(diveId)) {
        _selectedIds.remove(diveId);
      } else {
        _selectedIds.add(diveId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            _buildHandleBar(colorScheme),
            const SizedBox(height: 8),

            // Title row with close button
            _buildTitleRow(colorScheme, textTheme),
            const SizedBox(height: 4),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.trips_diveScan_subtitle(
                    widget.candidates.length,
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_unassigned.isNotEmpty) ...[
                    _buildGroupHeader(
                      context.l10n.trips_diveScan_groupUnassigned(
                        _unassigned.length,
                      ),
                      _unassigned,
                      colorScheme,
                      textTheme,
                    ),
                    ..._buildDiveRows(
                      _unassigned,
                      colorScheme,
                      textTheme,
                      showTripName: false,
                    ),
                  ],
                  if (_otherTrip.isNotEmpty) ...[
                    if (_unassigned.isNotEmpty) const SizedBox(height: 8),
                    _buildGroupHeader(
                      context.l10n.trips_diveScan_groupOtherTrips(
                        _otherTrip.length,
                      ),
                      _otherTrip,
                      colorScheme,
                      textTheme,
                    ),
                    ..._buildDiveRows(
                      _otherTrip,
                      colorScheme,
                      textTheme,
                      showTripName: true,
                    ),
                  ],
                ],
              ),
            ),

            // Bottom action bar
            const Divider(height: 1),
            _buildActionBar(colorScheme, textTheme),
          ],
        );
      },
    );
  }

  Widget _buildHandleBar(ColorScheme colorScheme) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.trips_diveScan_title,
              style: textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(
    String label,
    List<DiveCandidate> group,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final allSelected = _isGroupFullySelected(group);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (value) => _toggleGroup(group, value ?? false),
          ),
          Text(
            label,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDiveRows(
    List<DiveCandidate> candidates,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool showTripName,
  }) {
    final units = UnitFormatter(ref.watch(settingsProvider));

    return candidates.map((candidate) {
      final dive = candidate.dive;
      final isSelected = _selectedIds.contains(dive.id);
      final siteName =
          dive.site?.name ?? context.l10n.trips_diveScan_unknownSite;
      final dateStr = units.formatDate(dive.dateTime);
      // Metres were hardcoded here, so an imperial diver read the wrong
      // unit; the formatter is already in scope for the date.
      final depthStr = dive.maxDepth != null
          ? units.formatDepth(dive.maxDepth)
          : '';

      return InkWell(
        onTap: () => _toggleDive(dive.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleDive(dive.id),
              ),
              // Dive number badge
              if (dive.diveNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#${dive.diveNumber}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // Dive details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(siteName, style: textTheme.bodyMedium),
                        ),
                        if (depthStr.isNotEmpty)
                          Text(
                            depthStr,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      dateStr,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (showTripName && candidate.currentTripName != null)
                      Text(
                        context.l10n.trips_diveScan_currentTrip(
                          candidate.currentTripName!,
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActionBar(ColorScheme colorScheme, TextTheme textTheme) {
    final count = _selectedIds.length;
    final hasSelection = count > 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.trips_diveScan_cancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: hasSelection
                  ? () => Navigator.pop(context, _selectedIds.toList())
                  : null,
              child: Text(context.l10n.trips_diveScan_addButton(count)),
            ),
          ),
        ],
      ),
    );
  }
}
