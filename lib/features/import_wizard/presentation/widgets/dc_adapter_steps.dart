import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/import_wizard/presentation/widgets/dc_adapter_download_step.dart';
export 'package:submersion/features/import_wizard/presentation/widgets/dc_no_new_dives_view.dart';

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
                            l10n.importWizard_dc_knownComputer,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            l10n.importWizard_dc_knownComputerBody(
                              knownComputer.displayName,
                            ),
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
                  device.model ?? l10n.diveComputer_title,
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
                                ? l10n.diveComputer_discovery_recognizedDevice
                                : l10n.diveComputer_discovery_unknownDevice,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isRecognized
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                          ),
                          Text(
                            isRecognized
                                ? l10n.diveComputer_discovery_recognizedDeviceDescription
                                : l10n.diveComputer_discovery_unknownDeviceDescription,
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
