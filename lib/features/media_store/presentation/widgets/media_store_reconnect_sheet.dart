import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/domain/media_store_reconnect_situation.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_reconnect_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where Photos & videos lives, for the choice that sends the diver there.
const _photosRoute = '/settings/photos-media';

/// Opens the guided reconnect for a store marker mismatch (issue #2303).
/// [account] names the account the copies are in; null reads it from the
/// copies' own label.
///
/// Choosing the account again opens Photos & videos from [context], so a
/// caller in the desktop settings pane opens it in the pane (the sheet's own
/// navigator sits above the pane). A caller already on that page passes
/// [openPhotosPage] false: closing the sheet leaves the diver where the
/// account is chosen. A host that routes settings pages itself (the setup
/// card's) passes [onChooseAccount] in place of either.
Future<void> showMediaStoreReconnectSheet(
  BuildContext context, {
  String? account,
  bool openPhotosPage = true,
  VoidCallback? onChooseAccount,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => MediaStoreReconnectSheet(
    account: account,
    onChooseAccount:
        onChooseAccount ??
        () {
          if (openPhotosPage && context.mounted) {
            unawaited(context.pushSettingsPage(_photosRoute));
          }
        },
  ),
);

/// Looks at what the account's folder holds now and offers the choices
/// that fit it, each saying what happens to the copies before it is
/// tapped (guided reconnect design 5.2): use the copies there, start them
/// again where none are left, choose the account again where this device
/// cannot reach it, or stop keeping copies here.
class MediaStoreReconnectSheet extends ConsumerStatefulWidget {
  const MediaStoreReconnectSheet({
    super.key,
    this.account,
    required this.onChooseAccount,
  });

  final String? account;

  /// Runs once the sheet has closed for "Choose the account again".
  final VoidCallback onChooseAccount;

  @override
  ConsumerState<MediaStoreReconnectSheet> createState() =>
      _MediaStoreReconnectSheetState();
}

class _MediaStoreReconnectSheetState
    extends ConsumerState<MediaStoreReconnectSheet> {
  late Future<MediaStoreReconnectSituation> _situation;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _situation = _inspect();
  }

  Future<MediaStoreReconnectSituation> _inspect() async {
    // Read before the await: the sheet may be dismissed during the read.
    final container = ref.container;
    final found = await ref.read(mediaStoreReconnectProvider).inspect();
    // The marker matches again and the flag is cleared: wake the queue
    // rather than leave it to the suspended worker's retry window.
    if (found is ReconnectResolved) unawaited(_drain(container));
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account =
        widget.account ??
        ref.watch(photosCopiesProvider).value?.label ??
        l10n.settings_photos_cloudHeader;
    return FutureBuilder<MediaStoreReconnectSituation>(
      future: _situation,
      builder: (context, snapshot) {
        // A retry hands over a new future, and FutureBuilder keeps the old
        // answer while it loads: show the check, not the stale choices.
        final loading = snapshot.connectionState != ConnectionState.done;
        final found = loading ? null : snapshot.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.settings_photos_reconnect_title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (!loading && snapshot.hasError)
                ..._unreadable(l10n, account, '${snapshot.error}')
              else if (found == null)
                _checking(l10n, account)
              else
                ..._choices(l10n, account, found),
            ],
          ),
        );
      },
    );
  }

  Widget _checking(AppLocalizations l10n, String account) => ListTile(
    key: const Key('reconnect-checking'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    leading: const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    title: Text(l10n.settings_photos_reconnect_checking(account)),
  );

  List<Widget> _choices(
    AppLocalizations l10n,
    String account,
    MediaStoreReconnectSituation found,
  ) => switch (found) {
    ReconnectResolved() => [
      _intro(l10n.settings_photos_reconnect_resolved(account)),
      _close(l10n),
    ],
    ReconnectDetached() => [
      _intro(l10n.settings_photos_suspended_detached),
      _chooseAccount(l10n),
    ],
    ReconnectOtherStore(:final knownToLibrary) => [
      _intro(
        knownToLibrary
            ? l10n.settings_photos_reconnect_otherKnown(account)
            : l10n.settings_photos_reconnect_otherUnknown(account),
      ),
      ..._heldOnly(l10n, found),
      _choice(
        key: const Key('reconnect-adopt'),
        icon: Icons.cloud_sync_outlined,
        title: l10n.settings_photos_reconnect_adopt,
        body: knownToLibrary
            ? l10n.settings_photos_reconnect_adoptBody
            : l10n.settings_photos_reconnect_adoptUnknownBody(account),
        onTap: () => _reconnect(account),
      ),
      _detach(l10n),
    ],
    ReconnectNoMarker() => [
      _intro(l10n.settings_photos_reconnect_noMarker(account)),
      ..._heldOnly(l10n, found),
      _choice(
        key: const Key('reconnect-rebuild'),
        icon: Icons.cloud_upload_outlined,
        title: l10n.settings_photos_reconnect_rebuild,
        body: l10n.settings_photos_reconnect_rebuildBody(account),
        onTap: () => _reconnect(account),
      ),
      _detach(l10n),
    ],
    ReconnectUnreadable(:final message) => _unreadable(
      l10n,
      account,
      message,
      heldOnly: _heldOnly(l10n, found),
    ),
    ReconnectNeedsAccount() => [
      _intro(l10n.settings_photos_reconnect_needsAccount),
      ..._heldOnly(l10n, found),
      _chooseAccount(l10n),
      _detach(l10n),
    ],
  };

  List<Widget> _unreadable(
    AppLocalizations l10n,
    String account,
    String message, {
    List<Widget> heldOnly = const [],
  }) => [
    _intro(l10n.settings_photos_reconnect_unreadable(account)),
    // Raw, as the paused notice shows it: the wording anyone searching for
    // the problem would recognize.
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    ),
    ...heldOnly,
    _choice(
      key: const Key('reconnect-retry'),
      icon: Icons.refresh,
      title: l10n.common_action_tryAgain,
      onTap: () => setState(() {
        _situation = _inspect();
      }),
    ),
    _detach(l10n),
  ];

  Widget _intro(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    child: Text(text),
  );

  List<Widget> _heldOnly(
    AppLocalizations l10n,
    MediaStoreReconnectSituation found,
  ) {
    if (found.heldOnlyInCloud <= 0) return const [];
    final colors = Theme.of(context).colorScheme;
    return [
      ListTile(
        key: const Key('reconnect-held-only'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(Icons.warning_amber_outlined, color: colors.error),
        title: Text(
          l10n.settings_photos_reconnect_heldOnly(found.heldOnlyInCloud),
        ),
      ),
    ];
  }

  Widget _choice({
    required Key key,
    required IconData icon,
    required String title,
    String? body,
    required VoidCallback onTap,
    Color? color,
  }) => ListTile(
    key: key,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    leading: Icon(icon, color: color),
    title: Text(title, style: color == null ? null : TextStyle(color: color)),
    subtitle: body == null ? null : Text(body),
    enabled: !_busy,
    onTap: onTap,
  );

  Widget _detach(AppLocalizations l10n) => _choice(
    key: const Key('reconnect-detach'),
    icon: Icons.cloud_off_outlined,
    title: l10n.settings_photos_stopKeeping,
    body: l10n.settings_photos_stopKeepingBody,
    color: Theme.of(context).colorScheme.error,
    onTap: _detachCopies,
  );

  Widget _chooseAccount(AppLocalizations l10n) => _choice(
    key: const Key('reconnect-choose-account'),
    icon: Icons.manage_accounts_outlined,
    title: l10n.settings_photos_reconnect_chooseAccount,
    body: l10n.settings_photos_reconnect_chooseAccountBody,
    onTap: () {
      Navigator.of(context).pop();
      widget.onChooseAccount();
    },
  );

  Widget _close(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FilledButton(
        key: const Key('reconnect-close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.common_action_close),
      ),
    ),
  );

  /// Adopts what the folder holds, or starts it again where it holds
  /// nothing: one call, and the marker check decides which (the snackbar
  /// says which happened).
  Future<void> _reconnect(String account) async {
    final l10n = context.l10n;
    final container = ref.container;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final reconnect = ref.read(mediaStoreReconnectProvider);
    final MediaStoreConnectResult result;
    try {
      result = (await reconnect.reconnect()).result;
    } on MediaStoreException catch (e) {
      _failed(messenger, e.message);
      return;
    } catch (e) {
      _failed(messenger, '$e');
      return;
    } finally {
      // The attach may have landed even when the queueing after it failed.
      // Before the drain: it reads the runtime this rebuilds.
      _refresh(container);
    }
    unawaited(_drain(container));
    // A sheet dragged away meanwhile has already gone; popping again would
    // close the page beneath it.
    if (mounted) navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.createdNewStore
              ? l10n.settings_photos_reconnect_started(account)
              : l10n.settings_photos_reconnect_joined(account),
        ),
      ),
    );
  }

  Future<void> _detachCopies() async {
    final container = ref.container;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final reconnect = ref.read(mediaStoreReconnectProvider);
    try {
      await reconnect.detach();
      if (mounted) navigator.pop();
    } catch (e) {
      _failed(messenger, '$e');
    } finally {
      _refresh(container);
    }
  }

  void _failed(ScaffoldMessengerState messenger, String message) {
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Every reader of the attachment and the accounts' uses re-reads, as
  /// after any attach change (attachPhotosAccount does the same).
  static void _refresh(ProviderContainer container) {
    invalidateMediaStoreAttachmentWith(container.invalidate);
    container.invalidate(photosCopiesProvider);
    refreshAccountState(container.invalidate);
  }

  /// Runs the queue now, on whatever runtime the attachment builds. Fired
  /// and forgotten, so a failure is logged here: the paused notice and the
  /// status line report a queue that still cannot run.
  static Future<void> _drain(ProviderContainer container) async {
    try {
      final runtime = await container.read(mediaStoreRuntimeProvider.future);
      await runtime?.worker?.drain();
    } catch (e, stackTrace) {
      _log.warning(
        'Drain after reconnect failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static final _log = LoggerService.forClass(MediaStoreReconnectSheet);
}
