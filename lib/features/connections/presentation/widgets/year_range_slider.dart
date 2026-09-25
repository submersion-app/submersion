import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// First-to-last dive year of the log; dragging writes a whole-year date
/// range into the connections filter, so it shows and clears like any axis.
class YearRangeSlider extends ConsumerStatefulWidget {
  const YearRangeSlider({super.key});

  @override
  ConsumerState<YearRangeSlider> createState() => _YearRangeSliderState();
}

class _YearRangeSliderState extends ConsumerState<YearRangeSlider> {
  /// In-progress thumbs while dragging; null when the filter drives them.
  RangeValues? _dragging;

  @override
  Widget build(BuildContext context) {
    final span = ref.watch(connectionsYearSpanProvider).value;
    if (span == null || span.first >= span.last) {
      return const SizedBox.shrink();
    }
    final filter = ref.watch(connectionsFilterProvider);
    final lo = (filter.startDate?.year ?? span.first).clamp(
      span.first,
      span.last,
    );
    final hi = (filter.endDate?.year ?? span.last).clamp(span.first, span.last);
    final values = _dragging ?? RangeValues(lo.toDouble(), hi.toDouble());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.connections_yearRange_label(
              values.start.round(),
              values.end.round(),
            ),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          RangeSlider(
            min: span.first.toDouble(),
            max: span.last.toDouble(),
            divisions: span.last - span.first,
            values: values,
            labels: RangeLabels(
              '${values.start.round()}',
              '${values.end.round()}',
            ),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              final start = DateTime(v.start.round(), 1, 1);
              final end = DateTime(v.end.round(), 12, 31);
              ref.read(connectionsFilterProvider.notifier).state = filter
                  .copyWith(startDate: start, endDate: end);
            },
          ),
        ],
      ),
    );
  }
}
