import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How loudly a section asks for attention; the loudest sets the header.
enum _Severity { info, warn, alert }

/// One source of gear alerts on the trip.
typedef _Section = ({
  /// The one line the header shows when this section is alone.
  String summary,

  /// The heading above the details; dropped when it would only repeat
  /// the header line.
  String heading,
  IconData icon,
  _Severity severity,
  Widget details,
});

/// The gear alerts pinned above a trip that has not ended: service falling
/// due before the trip ends, and the scrubber margin on each rebreather.
///
/// It opens collapsed to a single line and expands on tap. Each alert used
/// to sit above the page in full, and on a phone together they took half
/// the window with no way to reclaim it (#2221). The line is the section's
/// own summary when there is one, and a count when there are several,
/// under a warning triangle tinted by the most urgent. Renders nothing when
/// there is nothing to say.
class TripGearAlertsPanel extends ConsumerStatefulWidget {
  final Trip trip;

  const TripGearAlertsPanel({super.key, required this.trip});

  /// The tappable one-line header that opens and closes the panel.
  static const headerKey = ValueKey('trip-gear-alerts-header');

  @override
  ConsumerState<TripGearAlertsPanel> createState() =>
      _TripGearAlertsPanelState();
}

class _TripGearAlertsPanelState extends ConsumerState<TripGearAlertsPanel> {
  bool _expanded = false;

  @override
  void didUpdateWidget(TripGearAlertsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The master-detail layouts reuse this state for the next trip; an
    // open panel must not carry over to alerts the diver never opened.
    if (oldWidget.trip.id != widget.trip.id) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    // Both sections plan for a trip still ahead: service falling due before
    // it ends, absorbent to last it. A trip already dived has nothing left
    // to plan, and today's gear and service state say nothing about it
    // (#2485). Checked before any provider is watched, so a past trip
    // computes nothing either.
    if (widget.trip.endsBefore(clock.now())) return const SizedBox.shrink();
    final sections = [?_serviceSection(), ?_scrubberSection()];
    if (sections.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = StatusColors.of(context);

    final severity = sections
        .map((s) => s.severity)
        .reduce((a, b) => a.index >= b.index ? a : b);
    final swatch = switch (severity) {
      _Severity.alert => status.alert,
      _Severity.warn => status.warn,
      _Severity.info => null,
    };
    // The tint and triangle carry the severity by sight alone; name it for
    // screen readers ahead of the summary.
    final severityLabel = switch (severity) {
      _Severity.alert => l10n.enum_eventSeverity_alert,
      _Severity.warn => l10n.enum_eventSeverity_warning,
      _Severity.info => null,
    };
    final summary = sections.length == 1
        ? sections.single.summary
        : l10n.trips_gearAlerts_count(sections.length);

    final header = Semantics(
      key: TripGearAlertsPanel.headerKey,
      button: true,
      expanded: _expanded,
      child: Ink(
        color: swatch?.container,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  swatch == null
                      ? sections.first.icon
                      : Icons.warning_amber_rounded,
                  color: swatch?.onContainer ?? theme.colorScheme.primary,
                  semanticLabel: severityLabel,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: swatch?.onContainer,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: swatch?.onContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // The panel sits above the page's own scrolling content. Once open it
    // lays out in full and scrolls with the other header cards inside their
    // shared budget (TripHeaderCards), so several units on a compact screen
    // cannot push the page off the bottom, and a drag on the details
    // carries on to the cards below (#2653).
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, section) in sections.indexed) ...[
                    if (i > 0) const Divider(height: 24),
                    if (section.heading != summary) ...[
                      _SectionHeading(section: section),
                      const Divider(),
                    ],
                    section.details,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Gear whose service falls due before the trip ends.
  _Section? _serviceSection() {
    final alerts =
        ref.watch(tripServiceAlertsProvider(widget.trip.id)).value ??
        const <DueClock>[];
    if (alerts.isEmpty) return null;
    final count = context.l10n.trips_serviceAlert_count(
      tripServiceAlertItemCount(alerts),
    );
    return (
      summary: count,
      heading: count,
      icon: Icons.build,
      // Red only when a clock is already overdue; gear merely coming due
      // before the trip reads amber.
      severity: tripServiceAlertsAnyOverdue(alerts)
          ? _Severity.alert
          : _Severity.warn,
      details: TripServiceAlertList(alerts: alerts),
    );
  }

  /// The scrubber margin on each active rebreather. A comfortable margin
  /// is information, not a warning; one under 20 percent is an alert.
  _Section? _scrubberSection() {
    final margins =
        ref.watch(tripScrubberMarginsProvider(widget.trip.id)).value ??
        const [];
    if (margins.isEmpty) return null;
    final l10n = context.l10n;
    final title = l10n.trips_scrubber_title;
    return (
      // With no unit rated there is no margin to summarise, so the line
      // names the section and the details carry the no-rating hint.
      summary: tripScrubberMarginSummary(l10n, margins) ?? title,
      heading: title,
      icon: Icons.air,
      severity: margins.any((m) => m.caution)
          ? _Severity.alert
          : _Severity.info,
      details: TripScrubberMarginDetails(margins: margins),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final _Section section;

  const _SectionHeading({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(section.icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(section.heading, style: theme.textTheme.titleMedium),
        ),
      ],
    );
  }
}
