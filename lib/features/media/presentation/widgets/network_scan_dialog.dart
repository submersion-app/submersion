// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 9. The dialog subscribes to `NetworkScanService.scanAll()` once in
// `initState`, holds the latest progress event in widget state, and flips
// to a "Done" summary when the stream emits `NetworkScanPhase.finished`.
// Cancel always closes the dialog; the in-flight scan continues to run in
// the background and persists results normally.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// The "Scan all network media" progress dialog.
///
/// Subscribes to `NetworkScanService.scanAll()` and rebuilds on each
/// progress event. When the scan reaches [NetworkScanPhase.finished], the
/// dialog flips to a summary view with a Done button. Cancel is always
/// available; it closes the dialog while the in-flight scan keeps running
/// in the background (results are still persisted by the service).
class NetworkScanDialog extends ConsumerStatefulWidget {
  const NetworkScanDialog({super.key}) : _injectedStream = null;

  /// Test-only constructor that takes a pre-built stream so tests don't
  /// need to wire the full Riverpod scope.
  @visibleForTesting
  const NetworkScanDialog.test({
    super.key,
    required Stream<NetworkScanProgress> stream,
  }) : _injectedStream = stream;

  final Stream<NetworkScanProgress>? _injectedStream;

  @override
  ConsumerState<NetworkScanDialog> createState() => _NetworkScanDialogState();
}

class _NetworkScanDialogState extends ConsumerState<NetworkScanDialog> {
  StreamSubscription<NetworkScanProgress>? _sub;
  NetworkScanProgress? _progress;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final stream =
        widget._injectedStream ??
        ref.read(networkScanServiceProvider).scanAll();
    _sub = stream.listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = e);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final finished = p?.phase == NetworkScanPhase.finished;
    return AlertDialog(
      // TODO(media): l10n
      title: const Text('Scan all network media'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Text(
                // TODO(media): l10n
                'Scan failed: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (finished)
              // Final summary view: one-line summary; the running counters
              // are subsumed by the report.
              Text(_summary(ref))
            else ...[
              // Render a determinate bar at 0 before the first event
              // arrives so `pumpAndSettle` can still drain the frame queue.
              LinearProgressIndicator(value: p?.fractionDone ?? 0.0),
              const SizedBox(height: 8),
              // TODO(media): l10n
              Text('${p?.done ?? 0} / ${p?.total ?? 0} items'),
              const SizedBox(height: 4),
              Text(
                // TODO(media): l10n
                '${p?.available ?? 0} reachable  ·  '
                '${p?.unreachable ?? 0} unreachable',
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!finished)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            // TODO(media): l10n
            child: const Text('Cancel'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            // TODO(media): l10n
            child: const Text('Done'),
          ),
      ],
    );
  }

  String _summary(WidgetRef ref) {
    final report = ref.read(networkScanServiceProvider).lastReport;
    if (report == null) return '';
    final seconds = (report.durationMs / 1000).toStringAsFixed(1);
    // TODO(media): l10n
    final base =
        'Scanned ${report.total} items in ${seconds}s: '
        '${report.available} reachable, '
        '${report.unreachable} unreachable';
    if (report.skippedNoUrl == 0) return base;
    // TODO(media): l10n
    return '$base, ${report.skippedNoUrl} skipped (no URL)';
  }
}
