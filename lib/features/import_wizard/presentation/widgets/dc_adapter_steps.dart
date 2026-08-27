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

class DcAdapterDownloadStep extends ConsumerStatefulWidget {
  const DcAdapterDownloadStep({
    super.key,
    required this.adapter,
    this.knownComputer,
  });

  final DiveComputerAdapter adapter;
  final DiveComputer? knownComputer;

  /// How long a saved-computer download scans for the computer's stored
  /// address before falling back to a direct connect with that address.
  /// Matches the first resolve attempt of the macOS/iOS native resolver.
  static const knownDeviceScanTimeout = Duration(seconds: 15);

  @override
  ConsumerState<DcAdapterDownloadStep> createState() =>
      _DcAdapterDownloadStepState();
}

class _DcAdapterDownloadStepState extends ConsumerState<DcAdapterDownloadStep> {
  bool _captured = false;
  bool _computerResolved = false;
  bool _searchingForKnownDevice = false;
  bool _noDives = false;

  @override
  void initState() {
    super.initState();
    final computer = widget.knownComputer;
    if (computer == null) {
      // In discovery mode, check if the device matches a known computer
      // BEFORE the download starts. If found, the computer's fingerprint
      // enables incremental download (only new dives).
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveComputer());
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reacquireKnownDevice(computer),
      );
    }
  }

  /// Re-acquires a saved Bluetooth computer by scanning for its stored
  /// address before the download connects (issue #1232).
  ///
  /// Connecting straight to a stored address fails on Android and Windows
  /// unless the stack has recently seen the device advertise, which is why
  /// the scan-and-download flow worked for the same computer while the
  /// saved entry did not. If the scan does not see the address, the step
  /// falls back to the stored address exactly as before.
  Future<void> _reacquireKnownDevice(DiveComputer computer) async {
    if (!mounted) return;
    final address = computer.bluetoothAddress;
    final notifier = ref.read(discoveryNotifierProvider.notifier);
    final selected = ref.read(discoveryNotifierProvider).selectedDevice;
    final alreadyAcquired =
        selected != null &&
        address != null &&
        bluetoothAddressesMatch(selected.address, address);
    // A saved computer downloads only from a device carrying its stored
    // address. A selection left over from an earlier discovery session is
    // dropped from the provider itself, because the completion path reads
    // the provider's selection to capture the descriptor the import
    // service records; hiding it locally here would not be enough.
    if (selected != null && !alreadyAcquired) {
      notifier.clearSelectedDevice();
    }
    final isBluetooth =
        _connectionTypeFromString(computer.connectionType) ==
        DeviceConnectionType.ble;

    if (address == null || !isBluetooth || alreadyAcquired) {
      setState(() => _computerResolved = true);
      return;
    }

    setState(() => _searchingForKnownDevice = true);
    final device = await notifier.scanForAddress(
      address,
      timeout: DcAdapterDownloadStep.knownDeviceScanTimeout,
    );
    if (device != null) notifier.selectDevice(device);
    if (!mounted) return;
    setState(() {
      _searchingForKnownDevice = false;
      _computerResolved = true;
    });
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
        _captureAndAdvance(next);
      }
    });

    // No new dives to import — show a terminal message.
    if (_noDives) {
      return DcNoNewDivesView(onDone: () => context.pop());
    }

    // Wait for computer resolution before creating the download widget.
    // This ensures the fingerprint is available for incremental download.
    if (!_computerResolved) {
      final knownComputer = widget.knownComputer;
      if (_searchingForKnownDevice && knownComputer != null) {
        return _KnownDeviceSearchView(computer: knownComputer);
      }
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

    // The first-sync cutoff prompt only ever applies when this computer has
    // no stored fingerprint yet and the caller isn't forcing a full
    // re-download -- in every other case the default's value is irrelevant.
    // Only wait on the provider when it could matter: firstSyncCutoffDefault
    // is a FutureProvider backed by a real Drift query, so the very first
    // watch always yields AsyncLoading (valueOrNull == null) synchronously.
    // If DownloadStepWidget were constructed immediately with that
    // transient null, its initState would read "no cutoff" and
    // unconditionally auto-start the download before the query resolves;
    // the later rebuild with the real value could arrive after the
    // download already started (or, worse, after this widget's state
    // already decided not to show the prompt), silently skipping it.
    // Gating here -- the same pattern already used above for
    // _computerResolved and deviceDescriptorsProvider -- ensures
    // DownloadStepWidget only ever sees the final, settled value.
    final promptCouldApply =
        computer?.lastDiveFingerprint == null &&
        !widget.adapter.forceFullDownload;
    DateTime? cutoffDefault;
    if (promptCouldApply) {
      final cutoffAsync = ref.watch(firstSyncCutoffDefaultProvider);
      if (cutoffAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      // A diver with an empty log (or no active diver) resolves to null
      // here and falls through to the normal auto-start path below --
      // this branch never hangs once the future settles, error or not.
      cutoffDefault = cutoffAsync.valueOrNull;
    }

    return DownloadStepWidget(
      device: device,
      computer: computer,
      forceFullDownload: widget.adapter.forceFullDownload,
      firstSyncCutoffDefault: cutoffDefault,
      onComplete: () {
        // Handled by the state watcher above.
      },
      onError: (error) {
        // Download errors are shown by the DownloadStepWidget itself.
      },
      onImportPartial: () {
        // The user chose to keep the dives delivered before an interrupted
        // download. For drivers that deliver oldest-first (as Shearwater
        // does), this is a contiguous prefix of the oldest dives, so capturing
        // it advances the fingerprint to a correct resume point for the next
        // download. Ordering depends on the native driver, not this code.
        _captureAndAdvance(ref.read(downloadNotifierProvider));
      },
    );
  }

  /// Captures the downloaded dives into the adapter and advances the wizard to
  /// the Review step. Shared by the normal completion path and the
  /// import-partial action for an interrupted download.
  void _captureAndAdvance(DownloadState state) {
    if (_captured) return;
    _captured = true;
    widget.adapter.setSinceCutoff(state.sinceCutoff);
    widget.adapter.setDownloadedDives(state.downloadedDives);

    // No dives — show an informational message instead of advancing to an
    // empty Review step. The computer itself is still saved below: reaching
    // this point means it paired, connected and completed a download, which is
    // exactly what makes it worth remembering for next time. Returning early
    // here used to strand a working computer as unknown whenever the diver's
    // first download had nothing new on it (issue #865).
    final hasDives = state.downloadedDives.isNotEmpty;
    if (!hasDives && mounted) {
      setState(() => _noDives = true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final discoveryState = ref.read(discoveryNotifierProvider);
      final device = discoveryState.selectedDevice;
      if (device != null) {
        // Serial and firmware ride on the completion event, not on the dives,
        // so the hardware-identity rebind still works with an empty download.
        await widget.adapter.ensureComputer(
          device: device,
          serialNumber: state.serialNumber,
          firmwareVersion: state.firmwareVersion,
        );
      }

      // Only a download that actually produced dives has a Review step to
      // advance to; the empty case stays on DcNoNewDivesView.
      if (hasDives && mounted) {
        ref.read(dcAdapterDownloadCanAdvanceProvider.notifier).state = true;
      }
    });
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
// Searching for a saved computer
// ---------------------------------------------------------------------------

class _KnownDeviceSearchView extends StatelessWidget {
  const _KnownDeviceSearchView({required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.diveComputer_download_searchingForDevice(computer.displayName),
          ),
        ],
      ),
    );
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
    final l10n = context.l10n;

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
              l10n.importWizard_dc_noNewDives,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.importWizard_dc_noNewDivesBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onDone,
              child: Text(l10n.universalImport_action_done),
            ),
          ],
        ),
      ),
    );
  }
}
