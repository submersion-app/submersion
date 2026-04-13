import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/pin_code_dialog.dart';
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
    // next build() cycle does not see old progress.
    notifier.reset();

    // Pass computer so the notifier can persist device info when done.
    await notifier.startDownload(widget.device!, computer: widget.computer);
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadNotifierProvider);

    ref.listen<DownloadState>(downloadNotifierProvider, (previous, next) {
      if (next.phase == DownloadPhase.pinRequired &&
          previous?.phase != DownloadPhase.pinRequired) {
        final notifier = ref.read(downloadNotifierProvider.notifier);
        handlePinCodeRequest(context, notifier.submitPinCode);
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Reactively detect when the download finishes and fire the
    // onComplete/onError callbacks.
    if (!_hasCalledComplete && _hasStarted && downloadState.isComplete) {
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
        context.l10n.diveComputer_download_importingCountDives(
          downloadState.downloadedDives.length,
        ),
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
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Progress indicator
                    ExcludeSemantics(
                      child: _buildProgressIndicator(
                        downloadState,
                        colorScheme,
                      ),
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
                          (downloadState.progress!.percentage * 100)
                              .toStringAsFixed(0),
                        ),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Downloaded dives list
                    if (downloadState.downloadedDives.isNotEmpty)
                      _buildDivesList(context, downloadState),
                  ],
                ),
              ),
            ),

            // Action buttons pinned at bottom
            if (downloadState.isDownloading) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(downloadNotifierProvider.notifier).cancelDownload();
                },
                icon: const Icon(Icons.cancel),
                label: Text(context.l10n.diveComputer_downloadStep_cancel),
              ),
            ],

            // Error state
            if (downloadState.hasError) ...[
              const SizedBox(height: 16),
              Semantics(
                label: context.l10n
                    .diveComputer_downloadStep_errorSemanticLabel(
                      _localizedError(context, downloadState),
                    ),
                liveRegion: true,
                child: Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(Icons.error, color: colorScheme.error),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _localizedError(context, downloadState),
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

            // Cancelled state
            if (downloadState.isCancelled) ...[
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
      case DownloadPhase.pinRequired:
        return Icons.pin;
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
          mainAxisSize: MainAxisSize.min,
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.downloadedDives.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final dive = state.downloadedDives[index];
                  return _buildDiveRow(context, dive, theme, colorScheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiveRow(
    BuildContext context,
    DownloadedDive dive,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final date = dive.startTime;
    final dateStr =
        '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final durationMin = dive.durationSeconds ~/ 60;

    // Build detail chips
    final details = <String>[
      '${dive.maxDepth.toStringAsFixed(1)}m',
      '${durationMin}min',
    ];
    if (dive.avgDepth != null) {
      details.add('avg ${dive.avgDepth!.toStringAsFixed(1)}m');
    }
    if (dive.minTemperature != null) {
      details.add('${dive.minTemperature!.toStringAsFixed(0)}C');
    }

    // Gas mix info from tanks
    final gasMixes = dive.tanks
        .where((t) => t.o2Percent != 21.0)
        .map((t) => 'EAN${t.o2Percent.round()}')
        .toSet();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (dive.diveNumber != null) ...[
                Text(
                  '#${dive.diveNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(dateStr, style: theme.textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              for (final detail in details)
                Text(detail, style: theme.textTheme.bodySmall),
              if (gasMixes.isNotEmpty)
                Text(
                  gasMixes.join(', '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.tertiary,
                  ),
                ),
              if (dive.decoAlgorithm != null)
                Text(
                  dive.decoAlgorithm!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (dive.gfLow != null && dive.gfHigh != null)
                Text(
                  'GF ${dive.gfLow}/${dive.gfHigh}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _localizedError(BuildContext context, DownloadState state) {
    final l10n = context.l10n;
    if (state.errorCode == 'no_serial_ports') {
      return l10n.diveComputer_download_noSerialPortsFound;
    }
    if (state.errorCode == 'connect_failed' && state.errorMessage != null) {
      return l10n.diveComputer_download_serialConnectFailedWithDetails(
        state.errorMessage!,
      );
    }
    return state.errorMessage ?? l10n.diveComputer_downloadStep_errorOccurred;
  }
}
