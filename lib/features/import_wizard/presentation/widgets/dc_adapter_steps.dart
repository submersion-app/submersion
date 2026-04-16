import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DcAdapterScanStep extends ConsumerWidget {
  const DcAdapterScanStep({super.key, required this.adapter});

  final DiveComputerAdapter adapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScanStepWidget(
      onDeviceSelected: (device) {
        ref.read(discoveryNotifierProvider.notifier).selectDevice(device);
        // Reset then set so the provider transitions false -> true,
        // enabling auto-advance even when re-selecting a device.
        ref.read(dcAdapterScanCanAdvanceProvider.notifier).state = false;
        ref.read(dcAdapterScanCanAdvanceProvider.notifier).state = true;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Confirm device step (discovery mode only)
// ---------------------------------------------------------------------------

class DcConfirmDeviceStep extends ConsumerStatefulWidget {
  const DcConfirmDeviceStep({super.key, required this.adapter, this.onGoBack});

  final DiveComputerAdapter adapter;
  final VoidCallback? onGoBack;

  @override
  ConsumerState<DcConfirmDeviceStep> createState() =>
      _DcConfirmDeviceStepState();
}

class _DcConfirmDeviceStepState extends ConsumerState<DcConfirmDeviceStep> {
  late final TextEditingController _nameController;
  bool _resolved = false;
  bool _isKnownComputer = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkKnown());
  }

  Future<void> _checkKnown() async {
    if (!mounted) return;
    final discoveryState = ref.read(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    if (device != null) {
      await widget.adapter.resolveKnownComputer(device);
    }
    if (mounted) {
      setState(() {
        _isKnownComputer = widget.adapter.computer != null;
        _resolved = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onConnectAndDownload() {
    if (!_isKnownComputer) {
      widget.adapter.setCustomDeviceName(_nameController.text);
    }
    ref.read(dcAdapterConfirmCanAdvanceProvider.notifier).state = true;
  }

  void _onChooseDifferent() {
    ref.read(dcAdapterScanCanAdvanceProvider.notifier).state = false;
    ref.read(dcAdapterConfirmCanAdvanceProvider.notifier).state = false;
    widget.onGoBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final discoveryState = ref.watch(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    if (device == null || !_resolved) {
      return const Center(child: CircularProgressIndicator());
    }

    final isRecognized = device.isRecognized;
    final knownComputer = widget.adapter.computer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Device info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(device.displayName, style: theme.textTheme.titleLarge),
                  if (device.manufacturer != null)
                    Text(
                      device.manufacturer!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_isKnownComputer && knownComputer != null)
            // Known computer badge
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Known Computer',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Saved as "${knownComputer.displayName}". '
                            'Only new dives will be downloaded.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Device name text field (new computer only)
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.diveComputer_discovery_deviceNameLabel,
                hintText: l10n.diveComputer_discovery_deviceNameHint(
                  device.model ?? 'Dive Computer',
                ),
                prefixIcon: const Icon(Icons.edit),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // Recognized device badge
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isRecognized
                          ? Icons.verified
                          : Icons.warning_amber_rounded,
                      color: isRecognized
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRecognized
                                ? 'Recognized Device'
                                : 'Unknown Device',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isRecognized
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                          ),
                          Text(
                            isRecognized
                                ? 'This device is in our supported devices '
                                      'library. Dive download should work '
                                      'automatically.'
                                : 'This device may not be fully supported.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Connect & Download button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _onConnectAndDownload,
              icon: const Icon(Icons.download),
              label: Text(l10n.diveComputer_discovery_connectAndDownload),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            ),
          ),

          const SizedBox(height: 12),

          // Choose Different Device button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _onChooseDifferent,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: Text(l10n.diveComputer_discovery_chooseDifferentDevice),
            ),
          ),
        ],
      ),
    );
  }
}

class DcAdapterDownloadStep extends ConsumerStatefulWidget {
  const DcAdapterDownloadStep({
    super.key,
    required this.adapter,
    this.knownComputer,
  });

  final DiveComputerAdapter adapter;
  final DiveComputer? knownComputer;

  @override
  ConsumerState<DcAdapterDownloadStep> createState() =>
      _DcAdapterDownloadStepState();
}

class _DcAdapterDownloadStepState extends ConsumerState<DcAdapterDownloadStep> {
  bool _captured = false;
  bool _computerResolved = false;
  bool _noDives = false;

  @override
  void initState() {
    super.initState();
    // In discovery mode, check if the device matches a known computer
    // BEFORE the download starts. If found, the computer's fingerprint
    // enables incremental download (only new dives).
    if (widget.knownComputer != null) {
      _computerResolved = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveComputer());
    }
  }

  Future<void> _resolveComputer() async {
    if (!mounted) return;
    final discoveryState = ref.read(discoveryNotifierProvider);
    final device = discoveryState.selectedDevice;
    if (device != null) {
      await widget.adapter.resolveKnownComputer(device);
    }
    if (mounted) setState(() => _computerResolved = true);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for download completion to capture dives. Using ref.listen
    // (not ref.watch + build-time check) so stale DownloadPhase.complete
    // from a previous session is ignored — only fresh transitions trigger.
    ref.listen<DownloadState>(downloadNotifierProvider, (previous, next) {
      if (!_captured && next.phase == DownloadPhase.complete) {
        _captured = true;
        widget.adapter.setDownloadedDives(next.downloadedDives);

        // No new dives — show an informational message instead of advancing
        // to an empty Review step.
        if (next.downloadedDives.isEmpty) {
          if (mounted) setState(() => _noDives = true);
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          final discoveryState = ref.read(discoveryNotifierProvider);
          final device = discoveryState.selectedDevice;
          if (device != null) {
            await widget.adapter.ensureComputer(
              device: device,
              serialNumber: next.serialNumber,
              firmwareVersion: next.firmwareVersion,
            );
          }

          if (mounted) {
            ref.read(dcAdapterDownloadCanAdvanceProvider.notifier).state = true;
          }
        });
      }
    });

    // No new dives to import — show a terminal message.
    if (_noDives) {
      return DcNoNewDivesView(onDone: () => context.pop());
    }

    // Wait for computer resolution before creating the download widget.
    // This ensures the fingerprint is available for incremental download.
    if (!_computerResolved) {
      return const Center(child: CircularProgressIndicator());
    }

    final discoveryState = ref.watch(discoveryNotifierProvider);
    var device = discoveryState.selectedDevice;
    final computer = widget.knownComputer ?? widget.adapter.computer;

    // For known-computer downloads, synthesize a DiscoveredDevice from the
    // computer's stored connection info when discovery state has no device.
    // The device descriptor lookup provides the dcModel integer that
    // libdivecomputer needs to select the right driver.
    if (device == null &&
        computer != null &&
        computer.bluetoothAddress != null) {
      final descriptorsAsync = ref.watch(deviceDescriptorsProvider);
      if (descriptorsAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      final descriptors = descriptorsAsync.valueOrNull ?? [];
      final matchingDescriptor = descriptors
          .where(
            (d) =>
                d.vendor == computer.manufacturer &&
                d.product == computer.model,
          )
          .firstOrNull;

      device = DiscoveredDevice(
        id: computer.id,
        name: computer.displayName,
        connectionType: _connectionTypeFromString(computer.connectionType),
        address: computer.bluetoothAddress!,
        recognizedModel: matchingDescriptor != null
            ? DeviceModel.fromDescriptor(matchingDescriptor)
            : null,
        discoveredAt: DateTime.now(),
      );
    }

    return DownloadStepWidget(
      device: device,
      computer: computer,
      forceFullDownload: widget.adapter.forceFullDownload,
      onComplete: () {
        // Handled by the state watcher above.
      },
      onError: (error) {
        // Download errors are shown by the DownloadStepWidget itself.
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DeviceConnectionType _connectionTypeFromString(String? type) {
  switch (type?.toLowerCase()) {
    case 'bluetooth':
    case 'ble':
      return DeviceConnectionType.ble;
    case 'usb':
      return DeviceConnectionType.usb;
    case 'infrared':
      return DeviceConnectionType.infrared;
    default:
      return DeviceConnectionType.ble;
  }
}

// ---------------------------------------------------------------------------
// No new dives view
// ---------------------------------------------------------------------------

class DcNoNewDivesView extends StatelessWidget {
  const DcNoNewDivesView({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No new dives to download',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'All dives from this computer have already been imported.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
