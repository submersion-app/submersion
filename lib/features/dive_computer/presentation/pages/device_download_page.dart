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
        _scanError = 'Computer not found';
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

      // Subscribe to the discovered devices stream directly
      // This is necessary because ref.read() on a StreamProvider doesn't
      // create an active subscription, so broadcast stream events are missed
      final connectionManager = ref.read(bluetoothConnectionManagerProvider);
      StreamSubscription<List<DiscoveredDevice>>? subscription;
      final completer = Completer<DiscoveredDevice?>();

      // Set up timeout
      final timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      // Listen for discovered devices
      subscription = connectionManager.discoveredDevices.listen((devices) {
        if (completer.isCompleted) return;

        // Look for a device that matches our saved computer
        for (final device in devices) {
          if (_deviceMatchesComputer(device, computer)) {
            if (!completer.isCompleted) {
              completer.complete(device);
            }
            return;
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
          _scanError =
              'Device not found. Make sure your ${computer.name.isNotEmpty ? computer.name : computer.fullName} '
              'is nearby and in transfer mode.';
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanError = 'Scan error: $e';
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

    final result = await notifier.startDownload(_discoveredDevice!);

    if (!mounted) {
      return;
    }

    if (!result.success || _hasStartedImport) {
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
          content: Text(importResult.errorMessage ?? 'Import failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    ref.invalidate(diveListNotifierProvider);
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
        title: const Text('Download Dives'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (downloadState.isDownloading) {
              ref.read(downloadNotifierProvider.notifier).cancelDownload();
            }
            context.pop();
          },
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
              Text('Error: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
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
                  const Text('Computer not found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
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
              'Searching for ${computer.name.isNotEmpty ? computer.name : computer.fullName}...',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure the device is nearby and in transfer mode',
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
              child: const Text('Cancel'),
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
              Text('Device Not Found', style: theme.textTheme.titleLarge),
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
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
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
            state.progress?.status ?? 'Preparing...',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Progress percentage
          if (state.progress != null && state.progress!.totalDives > 0)
            Text(
              '${(state.progress!.percentage * 100).toStringAsFixed(0)}%',
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
              label: const Text('Cancel'),
            ),

          if (state.isComplete)
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
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
                            state.errorMessage ?? 'An error occurred',
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
                      child: const Text('Cancel'),
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
                      label: const Text('Retry'),
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
        ? 'Imported Dives'
        : 'Downloaded Dives';

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
                            '${dive.maxDepth.toStringAsFixed(1)}m',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${dive.durationSeconds ~/ 60} min',
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
                Text('Import Results', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            if (result.imported > 0)
              _buildImportStatRow(
                context,
                Icons.add_circle_outline,
                'New dives imported',
                result.imported,
                colorScheme.primary,
              ),
            if (result.skipped > 0)
              _buildImportStatRow(
                context,
                Icons.skip_next,
                'Duplicates skipped',
                result.skipped,
                colorScheme.onSurfaceVariant,
              ),
            if (result.updated > 0)
              _buildImportStatRow(
                context,
                Icons.update,
                'Dives updated',
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
