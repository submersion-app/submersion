import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../dive_log/domain/entities/dive_computer.dart';
import '../../../dive_log/presentation/providers/dive_computer_providers.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/services/dive_import_service.dart';
import '../../domain/entities/device_model.dart';
import '../../domain/services/download_manager.dart';
import '../providers/discovery_providers.dart';
import '../providers/download_providers.dart';

/// Page for downloading dives from a known/saved dive computer.
///
/// This page handles reconnecting to the device and downloading dives.
class DeviceDownloadPage extends ConsumerStatefulWidget {
  final String computerId;

  const DeviceDownloadPage({
    super.key,
    required this.computerId,
  });

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
    final computer =
        ref.read(diveComputerByIdProvider(widget.computerId)).value;
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

      // Wait for the device to be found (with timeout)
      final startTime = DateTime.now();
      const timeout = Duration(seconds: 15);

      while (DateTime.now().difference(startTime) < timeout) {
        final devicesAsync = ref.read(discoveredDevicesProvider);
        final devices = devicesAsync.value ?? [];

        // Look for a device that matches our saved computer
        for (final device in devices) {
          if (_deviceMatchesComputer(device, computer)) {
            await discoveryNotifier.stopScan();
            setState(() {
              _discoveredDevice = device;
              _isScanning = false;
            });
            _startDownload();
            return;
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Timeout - device not found
      await discoveryNotifier.stopScan();
      setState(() {
        _isScanning = false;
        _scanError =
            'Device not found. Make sure your ${computer.name.isNotEmpty ? computer.name : computer.fullName} '
            'is nearby and in transfer mode.';
      });
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
      final deviceModelName =
          device.recognizedModel?.model.toLowerCase() ?? '';
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
        _computer ?? ref.read(diveComputerByIdProvider(widget.computerId)).value;
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
    final computerAsync =
        ref.watch(diveComputerByIdProvider(widget.computerId));
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
              Text(
                'Device Not Found',
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
                            style:
                                TextStyle(color: colorScheme.onErrorContainer),
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
