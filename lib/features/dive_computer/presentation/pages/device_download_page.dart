import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/summary_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Download page for a known dive computer.
///
/// Scans for the device automatically, then reuses the same
/// [DownloadStepWidget] and [SummaryStepWidget] as the discovery wizard
/// for a consistent download experience.
class DeviceDownloadPage extends ConsumerStatefulWidget {
  final String computerId;

  const DeviceDownloadPage({super.key, required this.computerId});

  @override
  ConsumerState<DeviceDownloadPage> createState() => _DeviceDownloadPageState();
}

enum _Phase { scanning, downloading, complete, error }

class _DeviceDownloadPageState extends ConsumerState<DeviceDownloadPage> {
  _Phase _phase = _Phase.scanning;
  DiscoveredDevice? _discoveredDevice;
  DiveComputer? _computer;
  String? _errorMessage;
  bool _hasInvalidatedDiveList = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanForDevice();
    });
  }

  Future<void> _scanForDevice() async {
    ref.invalidate(diveComputerByIdProvider(widget.computerId));
    final computer = await ref.read(
      diveComputerByIdProvider(widget.computerId).future,
    );
    if (computer == null) {
      setState(() {
        _phase = _Phase.error;
        _errorMessage = context.l10n.diveComputer_download_computerNotFound;
      });
      return;
    }

    _computer = computer;
    setState(() => _phase = _Phase.scanning);

    try {
      final discoveryNotifier = ref.read(discoveryNotifierProvider.notifier);
      await discoveryNotifier.startScan();

      final service = ref.read(diveComputerServiceProvider);
      final completer = Completer<DiscoveredDevice?>();

      final timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      final subscription = service.discoveredDevices.listen((pigeonDevice) {
        if (completer.isCompleted) return;
        final device = DiscoveredDevice.fromPigeon(pigeonDevice);
        if (_deviceMatchesComputer(device, computer)) {
          if (!completer.isCompleted) completer.complete(device);
        }
      });

      final foundDevice = await completer.future;

      timeoutTimer.cancel();
      await subscription.cancel();
      await discoveryNotifier.stopScan();

      if (!mounted) return;

      if (foundDevice != null) {
        _discoveredDevice = foundDevice;
        setState(() => _phase = _Phase.downloading);
      } else {
        setState(() {
          _phase = _Phase.error;
          _errorMessage = context.l10n
              .diveComputer_download_deviceNotFoundError(
                computer.name.isNotEmpty ? computer.name : computer.fullName,
              );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = context.l10n.diveComputer_download_scanError(
          e.toString(),
        );
      });
    }
  }

  bool _deviceMatchesComputer(DiscoveredDevice device, DiveComputer computer) {
    if (computer.bluetoothAddress != null &&
        computer.bluetoothAddress!.isNotEmpty &&
        device.id == computer.bluetoothAddress) {
      return true;
    }

    if (computer.serialNumber != null &&
        computer.serialNumber!.isNotEmpty &&
        device.name.contains(computer.serialNumber!)) {
      return true;
    }

    if (computer.manufacturer != null && computer.model != null) {
      final deviceManufacturer =
          device.recognizedModel?.manufacturer.toLowerCase() ?? '';
      final deviceModelName = device.recognizedModel?.model.toLowerCase() ?? '';
      if (deviceManufacturer == computer.manufacturer!.toLowerCase() &&
          deviceModelName == computer.model!.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  void _onDownloadComplete() {
    if (!_hasInvalidatedDiveList) {
      _hasInvalidatedDiveList = true;
      ref.invalidate(divesProvider);
      ref.invalidate(diveListNotifierProvider);
      ref.invalidate(paginatedDiveListProvider);
    }
    setState(() => _phase = _Phase.complete);
  }

  void _onDownloadError(String error) {
    setState(() {
      _phase = _Phase.error;
      _errorMessage = error;
    });
  }

  Future<void> _handleClose() async {
    final downloadState = ref.read(downloadNotifierProvider);
    if (downloadState.isDownloading) {
      final shouldLeave = await showDownloadExitConfirmation(context);
      if (!shouldLeave || !mounted) return;
      await ref.read(downloadNotifierProvider.notifier).cancelDownload();
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: _phase != _Phase.downloading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _computer?.displayName ?? context.l10n.diveComputer_download_title,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleClose,
            tooltip: context.l10n.diveComputer_download_closeTooltip,
          ),
        ),
        body: switch (_phase) {
          _Phase.scanning => _buildScanningState(theme, colorScheme),
          _Phase.downloading => DownloadStepWidget(
            device: _discoveredDevice,
            computer: _computer,
            onComplete: _onDownloadComplete,
            onError: _onDownloadError,
          ),
          _Phase.complete => SummaryStepWidget(
            computer: _computer,
            onDone: () => context.pop(),
            onViewDives: () {
              context.pop();
              context.go('/dives');
            },
          ),
          _Phase.error => _buildErrorState(theme, colorScheme),
        },
      ),
    );
  }

  Widget _buildScanningState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.diveComputer_download_searchingForDevice(
              _computer?.displayName ?? '',
            ),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your dive computer is on and nearby.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                      _phase = _Phase.scanning;
                      _errorMessage = null;
                      _discoveredDevice = null;
                      _hasInvalidatedDiveList = false;
                    });
                    ref.read(downloadNotifierProvider.notifier).reset();
                    _scanForDevice();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.diveComputer_download_retry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Show exit confirmation when download is in progress.
Future<bool> showDownloadExitConfirmation(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel download?'),
      content: const Text(
        'A download is in progress. Are you sure you want to leave?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return result ?? false;
}
