import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/services/download_manager.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Page for downloading dives from a known/saved dive computer.
///
/// This page handles reconnecting to the device and downloading dives.
class DeviceDownloadPage extends ConsumerStatefulWidget {
  final String computerId;

  const DeviceDownloadPage({super.key, required this.computerId});

  @override
  ConsumerState<DeviceDownloadPage> createState() => _DeviceDownloadPageState();
}

class _DeviceDownloadPageState extends ConsumerState<DeviceDownloadPage> {
  DiscoveredDevice? _discoveredDevice;
  bool _isScanning = false;
  bool _hasStartedDownload = false;
  bool _hasStartedImport = false;
  String? _scanError;
  DiveComputer? _computer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanAndConnect();
    });
  }

  Future<void> _startScanAndConnect() async {
    final computer = ref
        .read(diveComputerByIdProvider(widget.computerId))
        .value;
    if (computer == null) {
      setState(() {
        _scanError = context.l10n.diveComputer_download_computerNotFound;
      });
      return;
    }

    _computer = computer;

    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      // Start scanning for the device
      final discoveryNotifier = ref.read(discoveryNotifierProvider.notifier);
      await discoveryNotifier.startScan();

      // Subscribe to the discovery notifier's accumulated devices
      final service = ref.read(diveComputerServiceProvider);
      StreamSubscription<dynamic>? subscription;
      final completer = Completer<DiscoveredDevice?>();

      // Set up timeout
      final timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Listen for discovered devices via the service stream
      subscription = service.discoveredDevices.listen((pigeonDevice) {
        if (completer.isCompleted) return;

        final device = DiscoveredDevice.fromPigeon(pigeonDevice);
        if (_deviceMatchesComputer(device, computer)) {
          if (!completer.isCompleted) {
            completer.complete(device);
          }
        }
      });

      // Wait for device to be found or timeout
      final foundDevice = await completer.future;

      // Cleanup
      timeoutTimer.cancel();
      await subscription.cancel();
      await discoveryNotifier.stopScan();

      if (!mounted) return;

      if (foundDevice != null) {
        setState(() {
          _discoveredDevice = foundDevice;
          _isScanning = false;
        });
        _startDownload();
      } else {
        // Timeout - device not found
        setState(() {
          _isScanning = false;
          _scanError = context.l10n.diveComputer_download_deviceNotFoundError(
            computer.name.isNotEmpty ? computer.name : computer.fullName,
          );
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanError = context.l10n.diveComputer_download_scanError(e.toString());
      });
    }
  }

  bool _deviceMatchesComputer(DiscoveredDevice device, DiveComputer computer) {
    // Match by Bluetooth address if available
    if (computer.bluetoothAddress != null &&
        computer.bluetoothAddress!.isNotEmpty) {
      if (device.id == computer.bluetoothAddress) {
        return true;
      }
    }

    // Match by serial number if available
    if (computer.serialNumber != null && computer.serialNumber!.isNotEmpty) {
      // Check if device name contains serial number
      if (device.name.contains(computer.serialNumber!)) {
        return true;
      }
    }

    // Match by manufacturer and model
    if (computer.manufacturer != null && computer.model != null) {
      final deviceManufacturer =
          device.recognizedModel?.manufacturer.toLowerCase() ?? '';
      final deviceModelName = device.recognizedModel?.model.toLowerCase() ?? '';
      final computerManufacturer = computer.manufacturer!.toLowerCase();
      final computerModelName = computer.model!.toLowerCase();

      if (deviceManufacturer == computerManufacturer &&
          deviceModelName == computerModelName) {
        return true;
      }
    }

    return false;
  }

  Future<void> _startDownload() async {
    if (_hasStartedDownload || _discoveredDevice == null) return;
    _hasStartedDownload = true;

    final notifier = ref.read(downloadNotifierProvider.notifier);

    // Set dialog context for PIN entry (Aqualung devices)
    notifier.setDialogContext(context);

    await notifier.startDownload(_discoveredDevice!);

    if (!mounted) {
      return;
    }

    // Check state for completion (events update state asynchronously)
    final downloadState = ref.read(downloadNotifierProvider);
    if (!downloadState.isComplete || _hasStartedImport) {
      return;
    }

    final computer =
        _computer ??
        ref.read(diveComputerByIdProvider(widget.computerId)).value;
    if (computer == null) {
      return;
    }

    _hasStartedImport = true;

    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final importResult = await notifier.importDives(
      computer: computer,
      mode: ImportMode.newOnly,
      defaultResolution: ConflictResolution.skip,
      diverId: diverId,
    );

    if (!mounted) {
      return;
    }

    if (!importResult.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            importResult.errorMessage ??
                context.l10n.diveComputer_download_importFailed,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    ref.invalidate(diveListNotifierProvider);
    ref.invalidate(paginatedDiveListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final computerAsync = ref.watch(
      diveComputerByIdProvider(widget.computerId),
    );
    final downloadState = ref.watch(downloadNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveComputer_download_title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (downloadState.isDownloading) {
              ref.read(downloadNotifierProvider.notifier).cancelDownload();
            }
            context.pop();
          },
          tooltip: context.l10n.diveComputer_download_closeTooltip,
        ),
      ),
      body: computerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                context.l10n.diveComputer_download_errorWithMessage(
                  error.toString(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: Text(context.l10n.diveComputer_download_goBack),
              ),
            ],
          ),
        ),
        data: (computer) {
          if (computer == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(context.l10n.diveComputer_download_computerNotFound),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: Text(context.l10n.diveComputer_download_goBack),
                  ),
                ],
              ),
            );
          }

          return _buildContent(context, computer, downloadState);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DiveComputer computer,
    DownloadState downloadState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Scanning phase
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(strokeWidth: 8),
            ),
            const SizedBox(height: 32),
            Text(
              context.l10n.diveComputer_download_searchingForDevice(
                computer.name.isNotEmpty ? computer.name : computer.fullName,
              ),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveComputer_download_searchingInstructions,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () {
                ref.read(discoveryNotifierProvider.notifier).stopScan();
                context.pop();
              },
              child: Text(context.l10n.diveComputer_download_cancel),
            ),
          ],
        ),
      );
    }

    // Scan error
    if (_scanError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.errorContainer,
                ),
                child: Icon(
                  Icons.bluetooth_disabled,
                  size: 64,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                context.l10n.diveComputer_download_deviceNotFoundTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                _scanError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _scanError = null;
                  });
                  _startScanAndConnect();
                },
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.diveComputer_download_tryAgain),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(context.l10n.diveComputer_download_cancel),
              ),
            ],
          ),
        ),
      );
    }

    // Download in progress or complete
    return _buildDownloadContent(context, downloadState);
  }

  Widget _buildDownloadContent(BuildContext context, DownloadState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator
          _buildProgressIndicator(state, colorScheme),
          const SizedBox(height: 32),

          // Status text
          Text(
            state.progress?.status ??
                context.l10n.diveComputer_download_preparing,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Progress percentage
          if (state.progress != null && state.progress!.totalDives > 0)
            Text(
              context.l10n.diveComputer_download_progressPercent(
                (state.progress!.percentage * 100).toStringAsFixed(0),
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),

          const SizedBox(height: 32),

          // Downloaded dives count
          if (state.downloadedDives.isNotEmpty) _buildDivesList(context, state),

          // Import results (shown after import completes)
          if (state.importResult != null)
            _buildImportResults(context, state.importResult!),

          const Spacer(),

          // Action buttons based on state
          if (state.isDownloading)
            OutlinedButton.icon(
              onPressed: () {
                ref.read(downloadNotifierProvider.notifier).cancelDownload();
              },
              icon: const Icon(Icons.cancel),
              label: Text(context.l10n.diveComputer_download_cancel),
            ),

          if (state.isComplete)
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.check),
              label: Text(context.l10n.diveComputer_download_done),
            ),

          // Error state
          if (state.hasError)
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
                            state.errorMessage ??
                                context
                                    .l10n
                                    .diveComputer_download_errorOccurred,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: Text(context.l10n.diveComputer_download_cancel),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasStartedDownload = false;
                          _hasStartedImport = false;
                          _discoveredDevice = null;
                        });
                        _startScanAndConnect();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.diveComputer_download_retry),
                    ),
                  ],
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
        child: Icon(Icons.error_outline, size: 64, color: colorScheme.error),
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

    // After import completes, show only imported dives (non-duplicates)
    // During download, show all downloaded dives
    final dives = state.importResult?.importedDives ?? state.downloadedDives;
    final title = state.importResult != null
        ? context.l10n.diveComputer_download_importedDives
        : context.l10n.diveComputer_download_downloadedDives;

    if (dives.isEmpty) {
      return const SizedBox.shrink();
    }

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
                Text(title, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${dives.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Scrollable list of dives with constrained height
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dives.length,
                itemBuilder: (context, index) {
                  final dive = dives[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatDate(dive.startTime),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            context.l10n.diveComputer_download_depthMeters(
                              dive.maxDepth.toStringAsFixed(1),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            context.l10n.diveComputer_download_durationMin(
                              dive.durationSeconds ~/ 60,
                            ),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportResults(BuildContext context, ImportResult result) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Only show if there's something to report
    if (result.imported == 0 && result.skipped == 0 && result.updated == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveComputer_download_importResults,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result.imported > 0)
              _buildImportStatRow(
                context,
                Icons.add_circle_outline,
                context.l10n.diveComputer_download_newDivesImported,
                result.imported,
                colorScheme.primary,
              ),
            if (result.skipped > 0)
              _buildImportStatRow(
                context,
                Icons.skip_next,
                context.l10n.diveComputer_download_duplicatesSkipped,
                result.skipped,
                colorScheme.onSurfaceVariant,
              ),
            if (result.updated > 0)
              _buildImportStatRow(
                context,
                Icons.update,
                context.l10n.diveComputer_download_divesUpdated,
                result.updated,
                colorScheme.secondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportStatRow(
    BuildContext context,
    IconData icon,
    String label,
    int count,
    Color iconColor,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            '$count',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
