import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/device_model.dart';
import '../../domain/services/download_manager.dart';
import '../providers/download_providers.dart';

/// Widget for the download step of the discovery wizard.
class DownloadStepWidget extends ConsumerStatefulWidget {
  final DiscoveredDevice? device;
  final VoidCallback onComplete;
  final void Function(String error) onError;

  const DownloadStepWidget({
    super.key,
    required this.device,
    required this.onComplete,
    required this.onError,
  });

  @override
  ConsumerState<DownloadStepWidget> createState() => _DownloadStepWidgetState();
}

class _DownloadStepWidgetState extends ConsumerState<DownloadStepWidget> {
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    // Start download when widget is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  Future<void> _startDownload() async {
    if (_hasStarted || widget.device == null) return;
    _hasStarted = true;

    final notifier = ref.read(downloadNotifierProvider.notifier);

    // Set dialog context for PIN entry (Aqualung devices)
    notifier.setDialogContext(context);

    final result = await notifier.startDownload(widget.device!);

    if (result.success) {
      widget.onComplete();
    } else {
      widget.onError(result.errorMessage ?? 'Download failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator
          _buildProgressIndicator(downloadState, colorScheme),
          const SizedBox(height: 32),

          // Status text
          Text(
            downloadState.progress?.status ?? 'Preparing...',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Progress percentage
          if (downloadState.progress != null &&
              downloadState.progress!.totalDives > 0)
            Text(
              '${(downloadState.progress!.percentage * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),

          const SizedBox(height: 32),

          // Downloaded dives count
          if (downloadState.downloadedDives.isNotEmpty)
            _buildDivesList(context, downloadState),

          const Spacer(),

          // Cancel button
          if (downloadState.isDownloading)
            OutlinedButton.icon(
              onPressed: () {
                ref.read(downloadNotifierProvider.notifier).cancelDownload();
              },
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
            ),

          // Error state
          if (downloadState.hasError)
            Column(
              children: [
                Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            downloadState.errorMessage ?? 'An error occurred',
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    _hasStarted = false;
                    _startDownload();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(DownloadState state, ColorScheme colorScheme) {
    final progress = state.progress;

    if (state.hasError) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.errorContainer,
        ),
        child: Icon(
          Icons.error_outline,
          size: 64,
          color: colorScheme.error,
        ),
      );
    }

    if (state.isComplete) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.primaryContainer,
        ),
        child: Icon(
          Icons.check,
          size: 64,
          color: colorScheme.primary,
        ),
      );
    }

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: progress?.percentage,
              strokeWidth: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          Icon(
            _getPhaseIcon(state.phase),
            size: 48,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  IconData _getPhaseIcon(DownloadPhase phase) {
    switch (phase) {
      case DownloadPhase.connecting:
        return Icons.bluetooth_connected;
      case DownloadPhase.enumerating:
        return Icons.search;
      case DownloadPhase.downloading:
        return Icons.download;
      case DownloadPhase.processing:
        return Icons.sync;
      case DownloadPhase.complete:
        return Icons.check_circle;
      case DownloadPhase.error:
        return Icons.error;
      case DownloadPhase.cancelled:
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  Widget _buildDivesList(BuildContext context, DownloadState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scuba_diving, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Downloaded Dives',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${state.downloadedDives.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show last few dives
            ...state.downloadedDives.take(3).map((dive) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _formatDate(dive.startTime),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${dive.maxDepth.toStringAsFixed(1)}m',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${dive.durationSeconds ~/ 60} min',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
            if (state.downloadedDives.length > 3)
              Text(
                '... and ${state.downloadedDives.length - 3} more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
