import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Group 4: trip (with date-range caption and the date-match suggestion)
/// and dive center.
class TripSection extends StatelessWidget {
  const TripSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.tripName,
    required this.onPickTrip,
    required this.onClearTrip,
    required this.diveCenterName,
    required this.onPickDiveCenter,
    required this.onClearDiveCenter,
    this.tripCaption,
    this.tripSuggestion,
    this.centerCaption,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String? tripName;
  final VoidCallback onPickTrip;
  final VoidCallback onClearTrip;
  final String? diveCenterName;
  final VoidCallback onPickDiveCenter;
  final VoidCallback onClearDiveCenter;

  /// Trip date range, shown under the trip row when a trip is selected.
  final String? tripCaption;

  /// Existing suggestion banner from the date-match provider, when active.
  final Widget? tripSuggestion;

  /// Dive center location, shown under the dive center row.
  final String? centerCaption;

  Widget _caption(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_trip,
      icon: Icons.flight_takeoff,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_trip,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormRow.picker(
              label: l10n.diveLog_edit_row_trip,
              value: tripName,
              placeholder: l10n.diveLog_edit_row_notSet,
              onTap: onPickTrip,
              onClear: tripName == null ? null : onClearTrip,
            ),
            if (tripCaption != null) _caption(context, tripCaption!),
            if (tripSuggestion != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FormStyle.groupRadius,
                ),
                child: tripSuggestion,
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormRow.picker(
              label: l10n.diveLog_edit_row_diveCenter,
              value: diveCenterName,
              placeholder: l10n.diveLog_edit_row_notSet,
              onTap: onPickDiveCenter,
              onClear: diveCenterName == null ? null : onClearDiveCenter,
            ),
            if (centerCaption != null) _caption(context, centerCaption!),
          ],
        ),
      ],
    );
  }
}
