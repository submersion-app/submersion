import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/pin_code_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Widget for the download step of the discovery wizard.
class DownloadStepWidget extends ConsumerStatefulWidget {
  final DiscoveredDevice? device;

  /// The saved dive computer — passed to the notifier for auto-import.
  final DiveComputer? computer;
  final VoidCallback onComplete;
  final void Function(String error) onError;

  /// Invoked when the user chooses to import the dives that were delivered
  /// before an interrupted (errored or cancelled) download. Null disables the
  /// action. When the native driver delivers dives oldest-first (as the
  /// Shearwater driver does), the retained set is a contiguous prefix of the
  /// oldest dives, so importing it and advancing the fingerprint yields a
  /// correct resume point for the next download. This widget does not itself
  /// enforce that ordering — it relies on the driver's delivery order.
  final VoidCallback? onImportPartial;

  /// When true, `newDivesOnly` is set to false after the notifier reset,
  /// causing the download to bypass the stored fingerprint and fetch every
  /// dive on the device. Used by the "Re-import all dives" flow.
  final bool forceFullDownload;

  /// Default first-sync cutoff date, computed from the newest dive already
  /// in the active diver's log (see `firstSyncCutoffDefaultProvider`). When
  /// non-null and the computer has no stored fingerprint yet (and
  /// [forceFullDownload] is not set), the widget shows a prompt letting the
  /// diver skip re-downloading dives they already have instead of
  /// auto-starting the download.
  final DateTime? firstSyncCutoffDefault;

  const DownloadStepWidget({
    super.key,
    required this.device,
    this.computer,
    required this.onComplete,
    required this.onError,
    this.onImportPartial,
    this.forceFullDownload = false,
    this.firstSyncCutoffDefault,
  });

  @override
  ConsumerState<DownloadStepWidget> createState() => _DownloadStepWidgetState();
}

class _DownloadStepWidgetState extends ConsumerState<DownloadStepWidget> {
  bool _hasStarted = false;
  bool _hasCalledComplete = false;
  bool _hasCalledError = false;

  // First-sync cutoff prompt state. _cutoff seeds from the widget's default
  // and can be edited via the date picker before the prompt is resolved.
  DateTime? _cutoff;
  bool _promptResolved = false;
  bool _useCutoff = false;

  /// Whether the first-sync cutoff prompt should be shown instead of
  /// auto-starting the download. True only for a genuinely first-ever
  /// download of a computer with no stored fingerprint, when a default
  /// cutoff (the newest existing dive) is available, and the caller has not
  /// forced a full re-download.
  bool get _promptApplies =>
      widget.firstSyncCutoffDefault != null &&
      widget.computer?.lastDiveFingerprint == null &&
      !widget.forceFullDownload;

  @override
  void initState() {
    super.initState();
    _cutoff = widget.firstSyncCutoffDefault;
    if (!_promptApplies) {
      // Start download when widget is shown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logFailure(
          _startDownload(),
          _DownloadStepWidgetState,
          'start download',
        );
      });
    }
  }

  Future<void> _startDownload() async {
    if (_hasStarted || widget.device == null) return;
    _hasStarted = true;

    final notifier = ref.read(downloadNotifierProvider.notifier);

    // Clear stale state from any previous download immediately so the
    // next build() cycle does not see old progress.
    notifier.reset();

    // Apply forceFullDownload AFTER reset so the flag survives until
    // startDownload reads state.newDivesOnly. Any earlier mutation (e.g.,
    // from the parent widget's initState) would be wiped by reset().
    if (widget.forceFullDownload) {
      notifier.setNewDivesOnly(false);
    }

    // Likewise, the first-sync cutoff must be set after reset() and before
    // startDownload() reads state.sinceCutoff. Only "Download new dives"
    // sets _useCutoff; "Download all dives" and the auto-start path leave
    // it false so the download proceeds without a cutoff.
    if (_useCutoff && _cutoff != null) {
      notifier.setSinceCutoff(_cutoff);
    }

    // Pass computer so the notifier can persist device info when done.
    await notifier.startDownload(widget.device!, computer: widget.computer);
  }

  Future<void> _pickCutoffDate(BuildContext context) async {
    final now = DateTime.now();
    // The default cutoff is the diver's newest logged dive, which can carry
    // a timestamp in a different timezone than the device's local calendar
    // day. If that dive's local-time timestamp lands after `now` (e.g. a
    // dive logged in a timezone ahead of the device's), a `lastDate: now`
    // with `initialDate: _cutoff` violates showDatePicker's
    // `initialDate <= lastDate` assertion. Extend `lastDate` to cover
    // `_cutoff` in that case rather than clamping `initialDate` down --
    // clamping down would silently move the picker's starting point away
    // from the diver's actual cutoff.
    final cutoff = _cutoff;
    final lastDate = (cutoff != null && cutoff.isAfter(now)) ? cutoff : now;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _cutoff,
      firstDate: DateTime(2000),
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      setState(() {
        // Start-of-day so the picked day's dives are included in the
        // download rather than excluded by a mid-day floor.
        _cutoff = DateTime.utc(picked.year, picked.month, picked.day);
      });
    }
  }

  void _resolvePrompt({required bool useCutoff}) {
    setState(() {
      _useCutoff = useCutoff;
      _promptResolved = true;
    });
    logFailure(_startDownload(), _DownloadStepWidgetState, 'start download');
  }

  @override
  Widget build(BuildContext context) {
    // The `_cutoff != null` check is a defensive belt-and-suspenders: the
    // caller (DcAdapterDownloadStep) is expected to only ever construct
    // this widget with a settled firstSyncCutoffDefault (see the comment
    // there), so _promptApplies implies _cutoff != null in practice. But
    // should a future caller pass a changing firstSyncCutoffDefault across
    // rebuilds, this keeps `_cutoff!` in _buildCutoffPrompt from ever
    // null-check-crashing instead of silently falling through to the
    // normal (auto-starting) UI for that frame.
    if (_promptApplies && !_promptResolved && _cutoff != null) {
      return _buildCutoffPrompt(context);
    }

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
            // Fixed progress area (never scrolls)
            ExcludeSemantics(
              child: _buildProgressIndicator(downloadState, colorScheme),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 16),

            // Scrollable dives list (fills remaining space)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
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
              ..._buildInterruptedActions(context, downloadState),
            ],

            // Cancelled state
            if (downloadState.isCancelled) ...[
              const SizedBox(height: 16),
              ..._buildInterruptedActions(context, downloadState),
            ],
          ],
        ),
      ),
    );
  }

  /// Prompt shown before a genuinely first-ever download of a computer,
  /// when the diver's log already has dives. Lets them skip re-downloading
  /// dives they already logged by hand or from another source, instead of
  /// silently pulling the device's full history.
  Widget _buildCutoffPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final cutoff = _cutoff!;
    final dateLabel = DateFormat.yMMMd().format(cutoff);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.diveComputer_downloadStep_firstSyncTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.diveComputer_downloadStep_firstSyncBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    key: const Key('cutoff-date-row'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      context.l10n.diveComputer_downloadStep_onlyAfterDate(
                        dateLabel,
                      ),
                    ),
                    onTap: () => _pickCutoffDate(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _resolvePrompt(useCutoff: true),
            child: Text(context.l10n.diveComputer_downloadStep_downloadNew),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _resolvePrompt(useCutoff: false),
            child: Text(context.l10n.diveComputer_downloadStep_downloadAll),
          ),
        ],
      ),
    );
  }

  /// Actions shown after an interrupted (errored or cancelled) download.
  ///
  /// When the download delivered some dives before stopping, offers to import
  /// that partial set. For drivers that deliver dives oldest-first (as
  /// Shearwater does), the retained dives are a contiguous prefix of the
  /// oldest dives; importing them advances the fingerprint to a correct
  /// high-water mark and the next download resumes with the newer dives.
  /// Ordering is the driver's responsibility, not this widget's. Retry is
  /// always available.
  List<Widget> _buildInterruptedActions(
    BuildContext context,
    DownloadState state,
  ) {
    final retryButton = OutlinedButton.icon(
      onPressed: () {
        _hasStarted = false;
        logFailure(
          _startDownload(),
          _DownloadStepWidgetState,
          'start download',
        );
      },
      icon: const Icon(Icons.refresh),
      label: Text(context.l10n.diveComputer_downloadStep_retry),
    );

    final canImportPartial =
        widget.onImportPartial != null && state.downloadedDives.isNotEmpty;
    if (!canImportPartial) {
      // No partial dives to keep: retry is the only, and therefore primary,
      // action.
      return [
        FilledButton.icon(
          onPressed: () {
            _hasStarted = false;
            logFailure(
              _startDownload(),
              _DownloadStepWidgetState,
              'start download',
            );
          },
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.diveComputer_downloadStep_retry),
        ),
      ];
    }

    return [
      FilledButton.icon(
        onPressed: widget.onImportPartial,
        icon: const Icon(Icons.download_done),
        label: Text(
          context.l10n.diveComputer_downloadStep_importPartialCount(
            state.downloadedDives.length,
          ),
        ),
      ),
      const SizedBox(height: 8),
      retryButton,
    ];
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.downloadedDives.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final dive = state.downloadedDives[index];
                return _buildDiveRow(context, dive, theme, colorScheme);
              },
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
    // Apple platforms expose no API for deleting a pairing record, so a stale
    // one can only be cleared by the diver in Bluetooth settings. Say so
    // instead of showing the generic connect failure (issue #865).
    if (state.errorCode == 'stale_pairing') {
      return l10n.diveComputer_download_stalePairing;
    }
    if (state.errorCode == 'discovery_stalled') {
      return l10n.diveComputer_download_discoveryStalled;
    }
    if (state.errorCode == 'connect_failed' && state.errorMessage != null) {
      return l10n.diveComputer_download_serialConnectFailedWithDetails(
        state.errorMessage!,
      );
    }
    return state.errorMessage ?? l10n.diveComputer_downloadStep_errorOccurred;
  }
}
