import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/navigation/dive_computer_location.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_providers.dart';
import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/auto_connect_global_switch.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/clock_sync_global_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Transfer tab's Dive Computers section.
class ComputersSectionContent extends ConsumerStatefulWidget {
  const ComputersSectionContent({super.key});

  @override
  ConsumerState<ComputersSectionContent> createState() =>
      _ComputersSectionContentState();
}

/// Hosts the passive auto-connect scan for as long as this section is what
/// the diver sees (issue #3361): `initState`/`dispose` cover entering and
/// leaving the section itself (a sibling-section switch, or leaving Transfer
/// entirely, really disposes this widget); `RouteAware` covers a route
/// pushed on top and later popped, which leaves this widget mounted but
/// hidden underneath; and the app lifecycle covers the app leaving the
/// foreground.
class _ComputersSectionContentState
    extends ConsumerState<ComputersSectionContent>
    with RouteAware, WidgetsBindingObserver {
  // Cached, not read fresh via `ref` each time: `dispose()` runs after
  // Riverpod has already marked this element's `ref` unsafe to use
  // ("Using ref when a widget is about to or has been unmounted"), so the
  // notifier reference itself - not just the `activate()`/`release()`
  // calls - has to be captured while `ref` is still valid.
  late final AutoConnectController _autoConnectController;

  /// This section's route, and the one holding the whole shell on the root
  /// navigator. Something can cover the section from either.
  List<ModalRoute<void>> _routes = const [];

  bool get _isOnTop => _routes.every((route) => route.isCurrent);

  @override
  void initState() {
    super.initState();
    _autoConnectController = ref.read(autoConnectControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _activateOnceBuilt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell's route as well as this one: a buddy card, a dropped file or
    // any dialog opens on the root navigator above the shell, which this
    // section's own route never hears about.
    _routes = [
      ?ModalRoute.of<void>(context),
      ?ModalRoute.of<void>(Navigator.of(context).context),
    ];
    for (final route in _routes) {
      computersRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    computersRouteObserver.unsubscribe(this);
    _autoConnectController.release();
    super.dispose();
  }

  /// Deferred: Riverpod forbids modifying a provider's state while the
  /// widget tree is still building, which `activate()` does (it starts the
  /// scan and writes `isActive`).
  void _activateOnceBuilt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOnTop) _autoConnectController.activate();
    });
  }

  @override
  void didPushNext() {
    // Right away, not deferred: `release()` sets no provider state, which is
    // what `RouteObserver` dispatching this from inside the navigator's
    // rebuild forbids, and waiting a frame would let a match open a download
    // page over the page just pushed.
    _autoConnectController.release();
  }

  @override
  void didPopNext() => _activateOnceBuilt();

  /// A scan is for the screen in front of the diver: out of the foreground
  /// it would keep the radio busy and could connect with nobody looking.
  /// `inactive` passes: a permission prompt or a window losing focus leaves
  /// the section on screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isOnTop) _autoConnectController.activate();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _autoConnectController.release();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AutoConnectState>(autoConnectControllerProvider, (
      previous,
      next,
    ) {
      final computer = next.justTriggered;
      if (computer == null) return;
      // The same page the computer's own download button opens: it imports
      // the dives, which a bare download here would not.
      context.push('/dive-computers/${computer.id}/download');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.transfer_computers_autoConnect_downloadingSnackbar(
              computer.displayName,
            ),
          ),
        ),
      );
      ref.read(autoConnectControllerProvider.notifier).clearTriggerFeedback();
    });

    final isScanning = ref.watch(
      autoConnectControllerProvider.select((s) => s.isActive),
    );
    final computersAsync = ref.watch(allDiveComputersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = ref.watch(unitFormatterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same installation-wide switch as the Dive Computers page (#1910)
          const Card(
            clipBehavior: Clip.antiAlias,
            child: ClockSyncGlobalSwitch(),
          ),
          const SizedBox(height: 8),

          const Card(
            clipBehavior: Clip.antiAlias,
            child: AutoConnectGlobalSwitch(),
          ),
          if (isScanning) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.transfer_computers_autoConnect_searching,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Connect new computer
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/dive-computers/discover'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.bluetooth_searching,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.transfer_computers_connectTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.transfer_computers_connectSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Known computers list
          computersAsync.when(
            data: (computers) {
              if (computers.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  transferSectionHeader(
                    context,
                    context.l10n.transfer_computers_knownComputersHeader,
                  ),
                  const SizedBox(height: 8),
                  ...computers.map(
                    (computer) => _buildComputerCard(
                      context,
                      computer,
                      theme,
                      colorScheme,
                      units,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),

          if (Platform.isIOS) ...[
            const SizedBox(height: 16),
            transferSectionHeader(
              context,
              context.l10n.transfer_computers_appleWatchHeader,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.watch),
                title: Text(context.l10n.transfer_computers_appleWatchTitle),
                subtitle: Text(
                  context.l10n.transfer_computers_appleWatchSubtitle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/wearable-import'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComputerCard(
    BuildContext context,
    DiveComputer computer,
    ThemeData theme,
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push(diveComputerLocation(computer)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: computer.isFavorite
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getConnectionIcon(computer.connectionType),
                  size: 20,
                  color: computer.isFavorite
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            computer.displayName,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (computer.isFavorite)
                          Icon(
                            Icons.star,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                    Text(
                      computer.fullName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.scuba_diving,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.transfer_computers_diveCount(
                            computer.diveCount,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatLastDownload(
                            context,
                            computer.lastDownload,
                            units: units,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    context.push('/dive-computers/${computer.id}/download'),
                icon: const Icon(Icons.download, size: 20),
                tooltip: context.l10n.transfer_computers_downloadTooltip,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getConnectionIcon(String? connectionType) {
    switch (connectionType?.toLowerCase()) {
      case 'bluetooth':
        return Icons.bluetooth;
      case 'ble':
        return Icons.bluetooth;
      case 'usb':
        return Icons.usb;
      default:
        return Icons.watch;
    }
  }
}
