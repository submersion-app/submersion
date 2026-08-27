import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// AppBar control for [trackDateFilterProvider]: the active range (or "All
/// dates") and, once a range is set, a clear button.
///
/// Shared by the overview map page and the GPS log page's desktop split, so
/// the filter reads the same wherever the overview map appears.
class GpsTrackDateFilterAction extends ConsumerWidget {
  const GpsTrackDateFilterAction({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final existing = ref.read(trackDateFilterProvider);
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: existing,
    );
    if (picked != null) {
      ref.read(trackDateFilterProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final range = ref.watch(trackDateFilterProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const ValueKey('gps-track-date-filter'),
          icon: const Icon(Icons.date_range),
          label: Text(
            range == null
                ? l10n.gpsTrack_filter_all
                : '${DateFormat.yMd().format(range.start)} - '
                      '${DateFormat.yMd().format(range.end)}',
          ),
          onPressed: () => _pickRange(context, ref),
        ),
        if (range != null)
          IconButton(
            key: const ValueKey('gps-track-date-filter-clear'),
            icon: const Icon(Icons.filter_alt_off_outlined),
            tooltip: l10n.gpsTrack_filter_clear,
            onPressed: () =>
                ref.read(trackDateFilterProvider.notifier).state = null,
          ),
      ],
    );
  }
}
