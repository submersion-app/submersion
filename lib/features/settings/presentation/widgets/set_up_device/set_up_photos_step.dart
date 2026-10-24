import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/photos_using_row.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_photo_count_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_scaffold.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What step 4 of Set up this device does, each through the code path the
/// Photos page already uses. One object so a test can stand in for it.
class SetUpPhotosActions {
  const SetUpPhotosActions();

  /// The account's own sign-in on this device; true when signed in.
  Future<bool> signIn(
    BuildContext context,
    WidgetRef ref,
    AccountGroup group,
  ) => signInToGroup(context, ref, group);

  /// The account sheet, for copies whose account this device cannot name.
  Future<AccountGroup?> chooseAccount(BuildContext context) =>
      showAccountSheet(context, allowedKinds: photoAccountKinds);

  /// Joins the store [copies] names in [group], or starts one there.
  Future<bool> attach(
    BuildContext context,
    AccountGroup group,
    PhotosCopies copies,
  ) => attachPhotosAccount(context, group, copies: copies);
}

/// Step 4, "Photos on every device" (issue #3482, spec 6.4), optional. A
/// first device offers to start copies in the flow's account (off); a
/// device whose library already keeps copies offers to use them (on).
/// Nothing is written until Next; Skip only settles the step.
class SetUpPhotosStep extends ConsumerStatefulWidget {
  const SetUpPhotosStep({
    super.key,
    required this.navigation,
    this.actions = const SetUpPhotosActions(),
  });

  final SetUpStepNavigation navigation;
  final SetUpPhotosActions actions;

  @override
  ConsumerState<SetUpPhotosStep> createState() => _SetUpPhotosStepState();
}

class _SetUpPhotosStepState extends ConsumerState<SetUpPhotosStep> {
  /// Null until the diver flips it: off on a first device, on when the
  /// library already keeps copies.
  bool? _on;
  bool _auto = true;
  bool _cellular = false;
  bool _busy = false;

  bool _isOn(PhotosCopies copies) => _on ?? copies.store != null;

  /// Attaches when the switch is on (signing in to the copies' account
  /// first when this device is not signed in to it), applies the upload
  /// switches, then leaves. A sign-in or attach that does not finish stays.
  Future<void> _next(PhotosCopies copies, AccountGroup? account) async {
    if (copies.attached || !_isOn(copies)) {
      widget.navigation.onNext();
      return;
    }
    setState(() => _busy = true);
    final firstDevice = copies.store == null;
    var target = firstDevice
        ? account
        : copies.group ?? await widget.actions.chooseAccount(context);
    if (target != null && target.status != AccountStatus.signedIn) {
      if (!mounted) return;
      if (!await widget.actions.signIn(context, ref, target)) target = null;
    }
    if (!mounted) return;
    final attached =
        target != null && await widget.actions.attach(context, target, copies);
    if (!mounted) return;
    if (attached) {
      final policies = ref.read(mediaStorePoliciesProvider);
      await policies.setAutoUpload(_auto);
      if (firstDevice) await policies.setPhotosOnCellular(_cellular);
      if (!mounted) return;
      widget.navigation.onNext();
    }
    setState(() => _busy = false);
  }

  Future<void> _skip() async {
    await ref
        .read(setUpCardPrefsNotifierProvider.notifier)
        .setPhotosSkipped(true);
    (widget.navigation.onSkip ?? widget.navigation.onNext)();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final account = ref.watch(setUpFlowProvider) ?? groups.syncing;
    final copies = ref.watch(photosCopiesProvider).value;
    final (intro, children) = copies == null
        ? (null, const [Center(child: CircularProgressIndicator())])
        : _body(copies, account);
    return SetUpStepScaffold(
      title: l10n.settings_setUpDevice_photos_title,
      intro: intro,
      backLabel: l10n.common_action_back,
      onBack: widget.navigation.onBack,
      primaryLabel: l10n.settings_setUpDevice_next,
      onPrimary: copies == null ? null : () => _next(copies, account),
      busy: _busy,
      secondary: TextButton(
        onPressed: _busy ? null : _skip,
        child: Text(l10n.settings_setUpDevice_skip),
      ),
      children: children,
    );
  }

  (String?, List<Widget>) _body(PhotosCopies copies, AccountGroup? account) {
    final l10n = context.l10n;
    final note = Text(
      l10n.settings_setUpDevice_photos_firstNote,
      style: Theme.of(context).textTheme.bodySmall,
    );
    if (copies.attached) {
      // Run again on a device already attached: nothing to choose.
      return (
        null,
        [
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(
              copies.label == null
                  ? l10n.settings_photos_cloudHeader
                  : l10n.settings_photos_copiesIn(copies.label!),
            ),
          ),
        ],
      );
    }
    final on = _isOn(copies);
    void flip(bool v) => setState(() => _on = v);
    if (copies.store == null) {
      if (account == null || !photoAccountKinds.contains(account.kind)) {
        return (null, [note]);
      }
      final count = ref.watch(setUpPhotoCountProvider).value;
      return (
        l10n.settings_setUpDevice_photos_firstIntro(account.label),
        [
          SwitchListTile(
            secondary: Icon(accountKindIcon(account.kind)),
            title: Text(
              l10n.settings_setUpDevice_photos_keepCopies(account.label),
            ),
            subtitle: count == null
                ? null
                : Text(l10n.settings_setUpDevice_photos_attachedCount(count)),
            value: on,
            onChanged: _busy ? null : flip,
          ),
          if (on) ...[
            SwitchListTile(
              title: Text(l10n.settings_photos_autoUpload),
              value: _auto,
              onChanged: _busy ? null : (v) => setState(() => _auto = v),
            ),
            SwitchListTile(
              title: Text(l10n.settings_photos_cellular),
              value: _cellular,
              onChanged: _busy ? null : (v) => setState(() => _cellular = v),
            ),
          ],
          const SizedBox(height: 8),
          note,
        ],
      );
    }
    final group = copies.group;
    final label = copies.label ?? copies.store!.displayHint;
    final String? detail;
    if (group != null && group.key == account?.key) {
      detail = l10n.settings_setUpDevice_photos_sameAccount;
    } else if (group == null || group.status != AccountStatus.signedIn) {
      detail = l10n.settings_setUpDevice_photos_signInFirst(label);
    } else {
      detail = null;
    }
    return (
      l10n.settings_setUpDevice_photos_secondIntro(label),
      [
        SwitchListTile(
          secondary: Icon(
            group == null ? Icons.cloud_outlined : accountKindIcon(group.kind),
          ),
          title: Text(l10n.settings_setUpDevice_photos_useCopies(label)),
          subtitle: detail == null ? null : Text(detail),
          value: on,
          onChanged: _busy ? null : flip,
        ),
        if (on)
          SwitchListTile(
            title: Text(l10n.settings_setUpDevice_photos_autoUploadHere),
            value: _auto,
            onChanged: _busy ? null : (v) => setState(() => _auto = v),
          ),
      ],
    );
  }
}
