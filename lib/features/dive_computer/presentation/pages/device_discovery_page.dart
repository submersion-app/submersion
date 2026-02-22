import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/summary_step_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Multi-step wizard for discovering and connecting to dive computers.
class DeviceDiscoveryPage extends ConsumerStatefulWidget {
  const DeviceDiscoveryPage({super.key});

  @override
  ConsumerState<DeviceDiscoveryPage> createState() =>
      _DeviceDiscoveryPageState();
}

class _DeviceDiscoveryPageState extends ConsumerState<DeviceDiscoveryPage> {
  final PageController _pageController = PageController();
  String? _customName;
  DiveComputer? _savedComputer;

  /// Stored eagerly so we can call reset() in dispose() without relying on
  /// ref, which may already be invalidated in Riverpod 3.x lifecycle.
  late final DiscoveryNotifier _discoveryNotifier;

  @override
  void initState() {
    super.initState();
    _discoveryNotifier = ref.read(discoveryNotifierProvider.notifier);
  }

  @override
  void dispose() {
    _discoveryNotifier.reset();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryNotifierProvider);
    final theme = Theme.of(context);

    // Listen for step changes and animate page
    ref.listen<DiscoveryState>(discoveryNotifierProvider, (previous, next) {
      if (previous?.currentStep != next.currentStep) {
        final stepIndex = DiscoveryStep.values.indexOf(next.currentStep);
        _pageController.animateToPage(
          stepIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    return PopScope(
      canPop: discoveryState.currentStep == DiscoveryStep.scan,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle(discoveryState.currentStep)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitConfirmation(context),
            tooltip: context.l10n.diveComputer_discovery_exitTooltip,
          ),
        ),
        body: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(discoveryState.currentStep, theme),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Scan step
                  ScanStepWidget(onDeviceSelected: _onDeviceSelected),
                  // Select step (combined with scan)
                  const SizedBox.shrink(),
                  // Pair step (handled automatically)
                  _buildPairStep(),
                  // Confirm step
                  _buildConfirmStep(discoveryState),
                  // Download step
                  DownloadStepWidget(
                    device: discoveryState.selectedDevice,
                    computer: _savedComputer,
                    onComplete: _onDownloadComplete,
                    onError: _onDownloadError,
                  ),
                  // Summary step
                  SummaryStepWidget(
                    computer: _savedComputer,
                    onDone: () => context.pop(),
                    onViewDives: _onViewDives,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(DiscoveryStep currentStep, ThemeData theme) {
    final steps = [
      context.l10n.diveComputer_discovery_stepScan,
      context.l10n.diveComputer_discovery_stepConnect,
      context.l10n.diveComputer_discovery_stepDownload,
      context.l10n.diveComputer_discovery_stepDone,
    ];
    final currentIndex = _getProgressIndex(currentStep);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= currentIndex;
          final isComplete = index < currentIndex;

          return Expanded(
            child: Row(
              children: [
                // Step circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: isComplete
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                // Connector line
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < currentIndex
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  int _getProgressIndex(DiscoveryStep step) {
    switch (step) {
      case DiscoveryStep.scan:
      case DiscoveryStep.select:
        return 0;
      case DiscoveryStep.pair:
      case DiscoveryStep.confirm:
        return 1;
      case DiscoveryStep.download:
        return 2;
      case DiscoveryStep.summary:
        return 3;
    }
  }

  String _getStepTitle(DiscoveryStep step) {
    switch (step) {
      case DiscoveryStep.scan:
      case DiscoveryStep.select:
        return context.l10n.diveComputer_discovery_titleFindDevice;
      case DiscoveryStep.pair:
        return context.l10n.diveComputer_discovery_titleConnecting;
      case DiscoveryStep.confirm:
        return context.l10n.diveComputer_discovery_titleConfirmDevice;
      case DiscoveryStep.download:
        return context.l10n.diveComputer_discovery_titleDownloading;
      case DiscoveryStep.summary:
        return context.l10n.diveComputer_discovery_titleComplete;
    }
  }

  Widget _buildPairStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.diveComputer_discovery_connectingToDevice,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveComputer_discovery_pleaseWaitConnection,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(DiscoveryState state) {
    final device = state.selectedDevice;
    if (device == null) {
      return Center(
        child: Text(context.l10n.diveComputer_discovery_noDeviceSelected),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Device card
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      device.connectionType == DeviceConnectionType.ble
                          ? Icons.bluetooth
                          : Icons.usb,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    device.displayName,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (device.manufacturer != null)
                    Text(
                      device.manufacturer!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Custom name field
                  TextField(
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.diveComputer_discovery_deviceNameLabel,
                      hintText: context.l10n
                          .diveComputer_discovery_deviceNameHint(
                            device.model ??
                                context.l10n.diveComputer_discovery_computer,
                          ),
                      prefixIcon: const Icon(Icons.edit),
                    ),
                    onChanged: (value) {
                      _customName = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Device info
          if (device.isRecognized) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.diveComputer_discovery_recognizedDevice,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context
                          .l10n
                          .diveComputer_discovery_recognizedDeviceDescription,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.diveComputer_discovery_unknownDevice,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context
                          .l10n
                          .diveComputer_discovery_unknownDeviceDescription,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Error message
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Actions
          FilledButton.icon(
            onPressed: _onConfirmDevice,
            icon: const Icon(Icons.download),
            label: Text(context.l10n.diveComputer_discovery_connectAndDownload),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ref
                  .read(discoveryNotifierProvider.notifier)
                  .goToStep(DiscoveryStep.scan);
            },
            child: Text(
              context.l10n.diveComputer_discovery_chooseDifferentDevice,
            ),
          ),
        ],
      ),
    );
  }

  void _onDeviceSelected(DiscoveredDevice device) {
    ref.read(discoveryNotifierProvider.notifier).selectDevice(device);
  }

  Future<void> _onConfirmDevice() async {
    final notifier = ref.read(discoveryNotifierProvider.notifier);
    final state = ref.read(discoveryNotifierProvider);
    final device = state.selectedDevice;

    if (device == null) return;

    final hasCustomName = _customName?.trim().isNotEmpty == true;
    final name = hasCustomName ? _customName!.trim() : device.displayName;

    // Reuse existing computer if one matches this bluetooth address
    final repo = ref.read(diveComputerRepositoryProvider);
    final existing = await repo.findByBluetoothAddress(device.address);

    if (existing != null) {
      if (hasCustomName && existing.name != name) {
        final updated = existing.copyWith(
          name: name,
          updatedAt: DateTime.now(),
        );
        await ref.read(diveComputerNotifierProvider.notifier).update(updated);
        _savedComputer = updated;
      } else {
        _savedComputer = existing;
      }
    } else {
      final computer = DiveComputer(
        id: '',
        name: name,
        manufacturer: device.manufacturer,
        model: device.model,
        connectionType: device.connectionType.name,
        bluetoothAddress: device.address,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _savedComputer = await ref
          .read(diveComputerNotifierProvider.notifier)
          .create(computer);
    }

    // Try to connect
    final connected = await notifier.connectToDevice();

    if (!connected) {
      // Stay on confirm step with error message
      return;
    }

    // Move to download step (handled by notifier)
  }

  Future<void> _onDownloadComplete() async {
    // Import is handled automatically by the DownloadNotifier's auto-import.
    // Just invalidate the dive list so the Dives page refreshes.
    ref.invalidate(diveListNotifierProvider);
    ref.invalidate(paginatedDiveListProvider);

    ref.read(discoveryNotifierProvider.notifier).goToSummary();
  }

  void _onDownloadError(String error) {
    // Show error but stay on download step
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _onViewDives() {
    context.pop();
    context.push('/dives');
  }

  void _handleBack() {
    final state = ref.read(discoveryNotifierProvider);

    if (state.currentStep == DiscoveryStep.scan) {
      _discoveryNotifier.reset();
      context.pop();
    } else {
      _discoveryNotifier.goBack();
    }
  }

  void _showExitConfirmation(BuildContext context) {
    final state = ref.read(discoveryNotifierProvider);

    if (state.currentStep == DiscoveryStep.scan) {
      _discoveryNotifier.reset();
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveComputer_discovery_exitDialogTitle),
        content: Text(context.l10n.diveComputer_discovery_exitDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.diveComputer_discovery_exitDialogCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(discoveryNotifierProvider.notifier).reset();
              this.context.pop();
            },
            child: Text(context.l10n.diveComputer_discovery_exitDialogConfirm),
          ),
        ],
      ),
    );
  }
}
