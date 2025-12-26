import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/device_model.dart';
import '../providers/discovery_providers.dart';

/// Widget for the scan/select step of the discovery wizard.
///
/// Provides tabs for Bluetooth and USB device discovery.
class ScanStepWidget extends ConsumerStatefulWidget {
  final void Function(DiscoveredDevice device) onDeviceSelected;

  const ScanStepWidget({
    super.key,
    required this.onDeviceSelected,
  });

  @override
  ConsumerState<ScanStepWidget> createState() => _ScanStepWidgetState();
}

class _ScanStepWidgetState extends ConsumerState<ScanStepWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Start Bluetooth scanning when widget is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryNotifierProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: colorScheme.onPrimaryContainer,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bluetooth, size: 18),
                    SizedBox(width: 8),
                    Text('Bluetooth'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.usb, size: 18),
                    SizedBox(width: 8),
                    Text('USB Cable'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _BluetoothScanTab(onDeviceSelected: widget.onDeviceSelected),
              _UsbDevicesTab(onDeviceSelected: widget.onDeviceSelected),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tab for Bluetooth device scanning.
class _BluetoothScanTab extends ConsumerWidget {
  final void Function(DiscoveredDevice device) onDeviceSelected;

  const _BluetoothScanTab({required this.onDeviceSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryState = ref.watch(discoveryNotifierProvider);
    final devicesAsync = ref.watch(discoveredDevicesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Scanning indicator
        if (discoveryState.isScanning)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Scanning for dive computers...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

        // Error message
        if (discoveryState.errorMessage != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    discoveryState.errorMessage!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(discoveryNotifierProvider.notifier).startScan();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

        // Device list
        Expanded(
          child: devicesAsync.when(
            data: (devices) {
              if (devices.isEmpty && !discoveryState.isScanning) {
                return _buildEmptyState(context, colorScheme);
              }
              return _buildDeviceList(context, devices);
            },
            loading: () => _buildEmptyState(context, colorScheme),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          ),
        ),

        // Scan controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: discoveryState.isScanning
                    ? OutlinedButton.icon(
                        onPressed: () {
                          ref
                              .read(discoveryNotifierProvider.notifier)
                              .stopScan();
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Scanning'),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          ref
                              .read(discoveryNotifierProvider.notifier)
                              .startScan();
                        },
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Scan Again'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Looking for Devices',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Make sure your dive computer is:\n'
              '• Turned on\n'
              '• In Bluetooth pairing mode\n'
              '• Close to your device',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    List<DiscoveredDevice> devices,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceListTile(
          device: device,
          onTap: () => onDeviceSelected(device),
        );
      },
    );
  }
}

/// Tab for USB device selection.
class _UsbDevicesTab extends ConsumerWidget {
  final void Function(DiscoveredDevice device) onDeviceSelected;

  const _UsbDevicesTab({required this.onDeviceSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usbDevicesByManufacturer = ref.watch(usbDevicesByManufacturerProvider);
    final usbScanner = ref.watch(usbDeviceScannerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (usbDevicesByManufacturer.isEmpty) {
      return Center(
        child: Text(
          'No USB devices available',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return Column(
      children: [
        // Instructions
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connect your dive computer via USB cable, then select it below.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Device list grouped by manufacturer
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: usbDevicesByManufacturer.length,
            itemBuilder: (context, index) {
              final manufacturer =
                  usbDevicesByManufacturer.keys.elementAt(index);
              final devices = usbDevicesByManufacturer[manufacturer]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manufacturer header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      manufacturer,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Devices
                  ...devices.map(
                    (model) => _UsbDeviceListTile(
                      model: model,
                      onTap: () {
                        final discoveredDevice =
                            usbScanner.createDiscoveredDevice(model);
                        onDeviceSelected(discoveredDevice);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// List tile for a USB device model.
class _UsbDeviceListTile extends StatelessWidget {
  final DeviceModel model;
  final VoidCallback onTap;

  const _UsbDeviceListTile({
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.usb,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.model,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'USB Cable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List tile for a discovered device.
class _DeviceListTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: device.isRecognized
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  device.connectionType == DeviceConnectionType.ble
                      ? Icons.bluetooth
                      : Icons.usb,
                  color: device.isRecognized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.displayName,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (device.isRecognized)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Supported',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (device.manufacturer != null)
                          Text(
                            device.manufacturer!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (device.signalStrength != null) ...[
                          const SizedBox(width: 12),
                          _SignalIndicator(strength: device.signalLevel),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signal strength indicator.
class _SignalIndicator extends StatelessWidget {
  final SignalStrength strength;

  const _SignalIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    int bars;

    switch (strength) {
      case SignalStrength.excellent:
        color = Colors.green;
        bars = 4;
      case SignalStrength.good:
        color = Colors.green;
        bars = 3;
      case SignalStrength.fair:
        color = Colors.orange;
        bars = 2;
      case SignalStrength.weak:
        color = Colors.red;
        bars = 1;
      case SignalStrength.unknown:
        color = colorScheme.onSurfaceVariant;
        bars = 0;
    }

    return Row(
      children: List.generate(4, (index) {
        final height = 4.0 + (index * 3);
        return Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: index < bars ? color : color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
