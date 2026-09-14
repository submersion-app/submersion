import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

/// The status swatch a service clock's [severity] calls for: alert when
/// overdue, warn when due soon, and null for an OK clock (or no clock), which
/// carries no status color at all.
StatusSwatch? serviceSeveritySwatch(
  StatusColors colors,
  ServiceClockSeverity? severity,
) => switch (severity) {
  ServiceClockSeverity.overdue => colors.alert,
  ServiceClockSeverity.dueSoon => colors.warn,
  ServiceClockSeverity.ok || null => null,
};

/// Color of the status dot beside a service clock or a part. Due and
/// overdue dots take the status accent; an OK dot stays the quiet surface
/// tone so healthy gear does not read as flagged.
Color serviceSeverityDotColor(
  BuildContext context,
  ServiceClockSeverity? severity,
) =>
    serviceSeveritySwatch(StatusColors.of(context), severity)?.accent ??
    Theme.of(context).colorScheme.surfaceContainerHighest;
