import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The forecast as lines of text, for the trip's cylinders card: each
/// shortfall in the error colour, else the all-clear.
class TripFillForecastText extends StatelessWidget {
  const TripFillForecastText({
    super.key,
    required this.forecast,
    required this.units,
  });

  final FillForecast forecast;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:lines, :short) = tripFillForecastLines(
      context.l10n,
      units,
      forecast,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            line,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: short ? theme.colorScheme.error : null,
              fontWeight: short ? FontWeight.w600 : null,
            ),
          ),
      ],
    );
  }
}

/// The same forecast as the board's banner: the alert swatch on a
/// shortfall, a quiet surface otherwise.
class TripFillForecastBanner extends StatelessWidget {
  const TripFillForecastBanner({
    super.key,
    required this.forecast,
    required this.units,
  });

  final FillForecast forecast;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (:lines, :short) = tripFillForecastLines(
      context.l10n,
      units,
      forecast,
    );
    final swatch = StatusColors.of(context).alert;
    final foreground = short
        ? swatch.onContainer
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('fill-forecast-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: short
              ? swatch.container
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              short ? Icons.warning_amber : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Text(
                      line,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
