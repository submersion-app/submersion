import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_account_choice.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// "Copies in {account}" with Change, or "Not set up" with Set up (spec
/// section 8.3). Choosing an account attaches this device's copies there:
/// today's marker check joins the store already in that account or starts
/// one. Choosing another account says what that does first
/// ([photosChoiceConsequence]).
class PhotosUsingRow extends ConsumerStatefulWidget {
  const PhotosUsingRow({super.key});

  @override
  ConsumerState<PhotosUsingRow> createState() => _PhotosUsingRowState();
}

class _PhotosUsingRowState extends ConsumerState<PhotosUsingRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(photosCopiesProvider);
    final copies = async.value;
    if (copies == null) {
      return ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: Text(
          async.hasError
              ? l10n.settings_connectedAccounts_loadError
              : l10n.settings_data_status_checking,
        ),
      );
    }
    final label = copies.label;
    final hasCopies =
        copies.attached || (label != null && copies.store != null);
    final group = copies.group;
    return ListTile(
      key: const Key('photos-using'),
      leading: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              group != null
                  ? accountKindIcon(group.kind)
                  : hasCopies
                  ? Icons.cloud_outlined
                  : Icons.cloud_off_outlined,
            ),
      title: Text(
        !hasCopies
            ? l10n.settings_sync_notSetUp
            : label != null
            ? l10n.settings_photos_copiesIn(label)
            // Attached through a store this device cannot name yet.
            : l10n.settings_photos_cloudHeader,
      ),
      subtitle: TileSubtitleAction(
        actionKey: const Key('photos-using-change'),
        // Attached here: Change. Not attached (nothing, or a store this
        // device has not joined): Set up.
        label: copies.attached
            ? l10n.settings_sync_change
            : l10n.settings_data_setUp,
        semanticsLabel: copies.attached
            ? null
            : l10n.settings_data_setUpFeature(l10n.settings_photosVideos_title),
        onPressed: _busy ? null : () => _choose(copies),
      ),
    );
  }

  Future<void> _choose(PhotosCopies copies) async {
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final facts = await readPhotosChoiceFacts(container, copies);
    if (!mounted) return;
    final choice = await showAccountSheet(
      context,
      allowedKinds: photoAccountKinds,
      currentKey: copies.group?.key,
      consequenceOf: (AccountGroup c) =>
          photosChoiceConsequence(l10n, copies, facts, c),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    // The same decision the sheet's text came from. The account in use
    // again attaches again: that is how a marker mismatch or a store this
    // device could not reach is recovered.
    final switching = isPhotosSwitch(copies, facts, choice);
    final attach = container.read(mediaStoreAccountAttachProvider);
    Future<MediaStoreConnectResult> run() => switching
        ? attach.switchTo(choice)
        : attach.attach(
            choice,
            storeAccountId: copies.store?.accountId,
            storeId: copies.store?.id,
          );
    try {
      MediaStoreConnectResult result;
      try {
        result = await run();
      } on MediaStoreException catch (e) {
        final untrusted = untrustedCertificateOf(e);
        if (untrusted == null || !mounted) rethrow;
        if (!await showWebDavTrustDialog(context, untrusted)) rethrow;
        await attach.trustCertificate(choice, untrusted.certificate.sha256);
        result = await run();
      }
      // Meant to join the library's copies, but the account held none: say
      // a second set was started rather than claim the join.
      final announced = copies.store?.id;
      final startedSeparate =
          !switching &&
          result.createdNewStore &&
          announced != null &&
          announced != result.storeId;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            startedSeparate
                ? l10n.settings_photos_startedSeparate(choice.label)
                : l10n.settings_photos_attached(choice.label),
          ),
        ),
      );
    } on MediaStoreException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(photosAttachErrorText(l10n, e, choice))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      // Every reader of the attachment and the accounts' uses re-reads,
      // whichever way the choice went.
      invalidateMediaStoreAttachmentWith(container.invalidate);
      container.invalidate(photosCopiesProvider);
      refreshAccountState(container.invalidate);
      if (mounted) setState(() => _busy = false);
    }
  }
}
