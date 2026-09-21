import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_reset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirmation dialog for the "3D Maps" reload action: how many dive sites
/// will be reloaded, an approximate download size (when there is still
/// cached data to estimate one from), a duration warning, and a
/// recommendation to be on fast Wi-Fi -- shown BEFORE anything is deleted, so
/// the diver can back out with nothing changed.
///
/// Returns `true` if the diver confirmed, `false`/`null` otherwise.
///
/// Takes no [WidgetRef]: the estimate is watched by the inner [Consumer],
/// whose own ref is scoped to the dialog's route and so survives the
/// caller being disposed while the dialog is still open.
Future<bool?> showMapReloadConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.maps3d_reload_confirmTitle),
      content: Consumer(
        builder: (context, ref, _) {
          final estimate = ref.watch(mapReloadEstimateProvider);
          return SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                estimate.when(
                  data: (value) => _EstimateSummary(estimate: value),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Text(context.l10n.maps3d_reload_confirm_duration),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.maps3d_reload_confirm_wifiHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.maps3d_reload_start),
        ),
      ],
    ),
  );
}

class _EstimateSummary extends StatelessWidget {
  const _EstimateSummary({required this.estimate});

  final MapReloadEstimate? estimate;

  @override
  Widget build(BuildContext context) {
    final value = estimate;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final size = value.formattedEstimatedSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.maps3d_reload_confirm_siteCount(value.siteCount)),
        if (size != null) ...[
          const SizedBox(height: 4),
          Text(context.l10n.maps3d_reload_confirm_estimatedSize(size)),
        ],
      ],
    );
  }
}
