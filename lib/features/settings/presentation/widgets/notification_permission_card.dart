import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the notification authorization prompt has already been put to the
/// platform and come back refused.
///
/// No platform will simply tell us this. iOS reports "not granted" identically
/// whether the user has never been asked or has explicitly refused, and
/// `flutter_local_notifications` surfaces only that one boolean. Asking is the
/// only way to learn the difference: once a decision exists, a repeat request
/// returns false without drawing anything, so a false answer here means the
/// sheet can no longer appear and only the Settings app can change the outcome.
///
/// Device-local on purpose. The `settings` table syncs, so a flag stored there
/// would let a phone that has been asked silence the prompt on a tablet that
/// has not.
final notificationPromptRefusedProvider = StateProvider<bool>((ref) => false);

/// Row offering to resolve a missing notification permission.
///
/// The button wording is a store requirement, not a style choice. App Review
/// rejected 1.7.4 under Guideline 5.1.1(iv) for a button that urged the user
/// toward a system authorization sheet, so the action that can raise that
/// sheet here says only "Continue". Once the platform has refused, no sheet is
/// possible and the row switches to "Open Settings", which Apple names as the
/// right destination for a decision already made.
class NotificationPermissionCard extends ConsumerStatefulWidget {
  const NotificationPermissionCard({super.key, this.openSettings});

  /// Opens the platform's per-app settings page. Injectable for tests, which
  /// cannot follow the real call out of the process.
  final Future<bool> Function()? openSettings;

  @override
  ConsumerState<NotificationPermissionCard> createState() =>
      _NotificationPermissionCardState();
}

class _NotificationPermissionCardState
    extends ConsumerState<NotificationPermissionCard> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _recheckPermission);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Re-read the permission after the user has been away.
  ///
  /// [notificationPermissionProvider] caches, and the only route out of this
  /// card sends the user to the Settings app, where the answer can change
  /// behind our back. Without this the card would keep offering "Open
  /// Settings" after the user had already granted there, until something
  /// unrelated happened to invalidate the provider.
  void _recheckPermission() {
    if (!mounted) return;
    ref.invalidate(notificationPermissionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final refused = ref.watch(notificationPromptRefusedProvider);

    return ListTile(
      leading: const Icon(Icons.warning, color: Colors.orange),
      title: Text(context.l10n.settings_notifications_disabled_title),
      subtitle: Text(
        refused
            ? context.l10n.settings_notifications_disabled_subtitle
            : context.l10n.settings_notifications_disabled_subtitleUnrequested,
      ),
      trailing: TextButton(
        onPressed: refused ? _openSettings : _request,
        child: Text(
          refused
              ? context.l10n.settings_notifications_disabled_openSettingsButton
              : context.l10n.settings_notifications_disabled_continueButton,
        ),
      ),
    );
  }

  Future<void> _request() async {
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    if (!mounted) return;
    if (!granted) {
      ref.read(notificationPromptRefusedProvider.notifier).state = true;
    }
    ref.invalidate(notificationPermissionProvider);
  }

  Future<void> _openSettings() async {
    await (widget.openSettings ?? openAppSettings)();
  }
}
