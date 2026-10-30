import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_route.dart';

/// The compact Set up this device card at the top of the Settings root list
/// (issue #3482).
///
/// The scheduled backup runs in another isolate and can change the backup
/// settings (a revoked folder is cleared), so the card reloads them from
/// disk whenever it appears and each time the app returns, as Settings >
/// Data does.
class SettingsRootSetUpCard extends ConsumerStatefulWidget {
  /// On the desktop settings list, beside the detail pane: every page the
  /// card opens goes to the Data pane. While Settings > Data is in the pane,
  /// its own card is on screen, so this one shows nothing.
  const SettingsRootSetUpCard.desktop({
    super.key,
    required this.selectedSectionId,
  }) : desktop = true;

  /// On a phone's settings list: pages are pushed over the list.
  const SettingsRootSetUpCard.phone({super.key})
    : desktop = false,
      selectedSectionId = null;

  final bool desktop;
  final String? selectedSectionId;

  @override
  ConsumerState<SettingsRootSetUpCard> createState() =>
      _SettingsRootSetUpCardState();
}

class _SettingsRootSetUpCardState extends ConsumerState<SettingsRootSetUpCard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reloadBackup);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadBackup());
  }

  void _reloadBackup() {
    if (!mounted) return;
    ref.read(backupSettingsProvider.notifier).reloadFromDisk();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _open(String route) {
    final paneLocation = widget.desktop ? dataPaneLocation(route) : null;
    if (paneLocation != null) {
      context.go(paneLocation);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.desktop && widget.selectedSectionId == 'data') {
      return const SizedBox.shrink();
    }
    return SetUpDeviceCard(compact: true, onOpen: _open);
  }
}
