import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Widget for the download step of the discovery wizard.
class DownloadStepWidget extends ConsumerStatefulWidget {
  final DiscoveredDevice? device;

  /// The saved dive computer — passed to the notifier for auto-import.
  final DiveComputer? computer;
  final VoidCallback onComplete;
  final void Function(String error) onError;

  const DownloadStepWidget({
    super.key,
    required this.device,
    this.computer,
    required this.onComplete,
    required this.onError,
  });

  @override
  ConsumerState<DownloadStepWidget> createState() => _DownloadStepWidgetState();
}

class _DownloadStepWidgetState extends ConsumerState<DownloadStepWidget> {
  bool _hasStarted = false;
  bool _hasCalledComplete = false;
  bool _hasCalledError = false;

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

    // Clear stale state from any previous download immediately so the
    // next build() cycle does not see old importResult / progress.
    notifier.reset();

    // Set dialog context for PIN entry (Aqualung devices)
    notifier.setDialogContext(context);

    // Resolve the diver ID so auto-import assigns the correct owner.
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);

    // Pass computer + diverId so the notifier can auto-import when done.
    await notifier.startDownload(
      widget.device!,
      computer: widget.computer,
      diverId: diverId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Reactively detect when the download+import finishes and fire the
    // onComplete/onError callbacks. importResult being set means the
    // auto-import has finished (the notifier sets it after importDives).
    if (!_hasCalledComplete &&
        _hasStarted &&
        downloadState.importResult != null &&
        downloadState.importResult!.isSuccess) {
      _hasCalledComplete = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete();
      });
    }
    if (!_hasCalledError && downloadState.hasError && _hasStarted) {
      _hasCalledError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onError(
          downloadState.errorMessage ??
              context.l10n.diveComputer_downloadStep_downloadFailed,
        );
      });
    }

    final statusText = switch (downloadState.phase) {
      DownloadPhase.processing =>
        'Importing ${downloadState.downloadedDives.length} dives...',
      DownloadPhase.cancelled =>
        context.l10n.diveComputer_downloadStep_cancelled,
      _ =>
        downloadState.progress?.status ??
            context.l10n.diveComputer_downloadStep_preparing,
    };
    final showPercent =
        downloadState.isDownloading &&
        downloadState.progress != null &&
        downloadState.progress!.totalDives > 0;
    final percentText = showPercent
        ? context.l10n.diveComputer_downloadStep_percentAccessibility(
            (downloadState.progress!.percentage * 100).toStringAsFixed(0),
          )
        : '';

    return Semantics(
      label: context.l10n.diveComputer_downloadStep_progressSemanticLabel(
        statusText,
        percentText,
      ),
      liveRegion: downloadState.isDownloading,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress indicator
            ExcludeSemantics(
              child: _buildProgressIndicator(downloadState, colorScheme),
            ),
            const SizedBox(height: 32),

            // Status text
            Text(
              statusText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Progress percentage
            if (showPercent)
              Text(
                context.l10n.diveComputer_downloadStep_progressPercent(
                  (downloadState.progress!.percentage * 100).toStringAsFixed(0),
                ),
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
                label: Text(context.l10n.diveComputer_downloadStep_cancel),
              ),

            // Error state
            if (downloadState.hasError)
              Column(
                children: [
                  Semantics(
                    label: context.l10n
                        .diveComputer_downloadStep_errorSemanticLabel(
                          downloadState.errorMessage ??
                              context
                                  .l10n
                                  .diveComputer_downloadStep_errorOccurred,
                        ),
                    liveRegion: true,
                    child: Card(
                      color: colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.error,
                                color: colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                downloadState.errorMessage ??
                                    context
                                        .l10n
                                        .diveComputer_downloadStep_errorOccurred,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    label: Text(context.l10n.diveComputer_downloadStep_retry),
                  ),
                ],
              ),

            // Cancelled state
            if (downloadState.isCancelled)
              Column(
                children: [
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      _hasStarted = false;
                      _startDownload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.diveComputer_downloadStep_retry),
                  ),
                ],
              ),
          ],
        ),
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
        child: Icon(Icons.error_outline, size: 64, color: colorScheme.error),
      );
    }

    if (state.isCancelled) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.cancel_outlined,
          size: 64,
          color: colorScheme.onSurfaceVariant,
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
        child: Icon(Icons.check, size: 64, color: colorScheme.primary),
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
                  context.l10n.diveComputer_downloadStep_downloadedDives,
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
                      context.l10n.diveComputer_downloadStep_depthMeters(
                        dive.maxDepth.toStringAsFixed(1),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      context.l10n.diveComputer_downloadStep_durationMin(
                        dive.durationSeconds ~/ 60,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
            if (state.downloadedDives.length > 3)
              Text(
                context.l10n.diveComputer_downloadStep_andMoreDives(
                  state.downloadedDives.length - 3,
                ),
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
