import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_reconnect_sheet.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_pending_items.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_marks.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_route.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/device_kind.dart';

final _log = LoggerService.forClass(SetUpDeviceCard);

/// Runs an account's own sign-in; true when it is signed in afterwards.
typedef SignInAccount =
    Future<bool> Function(
      BuildContext context,
      WidgetRef ref,
      AccountGroup group,
    );

/// "Set up this device" (issue #3482): the four steps with their marks and
/// Continue, then whatever needs the diver later (spec 6.5). The full form
/// sits on the Data page, the compact form (title, count, Continue) on the
/// Settings root. Renders nothing when there is nothing to show, so it can
/// sit permanently at the top of either list.
class SetUpDeviceCard extends ConsumerWidget {
  const SetUpDeviceCard({
    super.key,
    this.compact = false,
    this.onOpen,
    this.signInAccount = signInToGroup,
    this.margin,
  });

  final bool compact;

  /// Opens a settings page: a step's page, or the page that resolves an
  /// item. Every page the card opens goes through it, so a host outside
  /// Settings > Data (the desktop settings list) keeps them all in the Data
  /// pane. Defaults to opening it as pages inside Settings > Data do.
  final ValueChanged<String>? onOpen;

  final SignInAccount signInAccount;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(setUpProgressProvider);
    if (progress == null) return const SizedBox.shrink();
    // The full card's photo step already covers joining the announced
    // store; the compact card shows no steps, so it lists the item.
    final photoStepShown =
        progress.showsSteps &&
        !compact &&
        progress.marks[SetUpStep.photos] != SetUpMark.done &&
        progress.marks[SetUpStep.photos] != SetUpMark.skipped;
    final items = [
      for (final item
          in ref.watch(pendingSetupItemsProvider).value ??
              const <PendingSetupItem>[])
        if (!item.dismissed &&
            !(photoStepShown && item.kind == SetupItemKind.mediaStoreAttach))
          item,
    ];
    if (!progress.showsSteps && items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.showsSteps)
            _Steps(
              progress: progress,
              compact: compact,
              onContinue: () => _open(context, setUpStepRoute(progress.next!)),
              onHide: () => ref
                  .read(setUpCardPrefsNotifierProvider.notifier)
                  .setHidden(true),
            ),
          if (progress.showsSteps && items.isNotEmpty) const Divider(height: 1),
          if (items.isNotEmpty)
            SetUpPendingItems(
              items: items,
              onOpen: (route) => _open(context, route),
              onSignIn: (item) => _signIn(context, ref, item),
              onReconnect: (item) => showMediaStoreReconnectSheet(
                context,
                account: item.label,
                // Through the card's host, so the desktop list opens the
                // page in the Data pane like the card's other items.
                onChooseAccount: () => _open(context, item.route),
              ),
              onDismiss: (item) => _dismiss(context, item),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String route) {
    final open = onOpen;
    if (open != null) {
      open(route);
    } else {
      unawaited(context.pushSettingsPage(route));
    }
  }

  /// The account's own sign-in when this build can run it; otherwise (a
  /// connector, a row no account holds, a kind this build cannot sign in
  /// to, a lookup that failed) the page that resolves the item.
  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    PendingSetupItem item,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final kind = item.accountKind;
    final group = kind == null || kind == AccountKind.adobeLightroom
        ? null
        : await _groupOf(container, item, kind);
    if (!context.mounted) return;
    if (group == null) {
      _open(context, item.route);
      return;
    }
    final signedIn = await signInAccount(context, ref, group);
    // The photo copies' store and runtime were built without this
    // account's keys; rebuild them now that it has them.
    if (signedIn && item.usages.contains(AccountUsageKind.mediaStorage)) {
      invalidateMediaStoreAttachmentWith(container.invalidate);
    }
  }

  /// The account holding [item]'s row, or null when this build cannot sign
  /// in to [kind] or the lookup fails. Probes only accounts of [kind].
  static Future<AccountGroup?> _groupOf(
    ProviderContainer container,
    PendingSetupItem item,
    AccountKind kind,
  ) async {
    final groups = accountGroupsOfKindsProvider(accountKindsKey({kind}));
    // Held while read: nothing on the card's pages watches the groups, and
    // an unwatched autoDispose provider is disposed partway through its
    // build.
    final subscription = container.listen(groups, (_, _) {});
    try {
      if (!await canSignInOnThisBuild(container, kind)) return null;
      return (await container.read(groups.future)).holding(item.accountId);
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not look up the account to sign in to',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      subscription.close();
    }
  }

  /// Records the dismissal, then refreshes every card through the
  /// container, which outlives this card if it goes away during the write.
  Future<void> _dismiss(BuildContext context, PendingSetupItem item) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await PendingSetupService.dismissKey(
      container.read(sharedPreferencesProvider),
      item.key,
    );
    container.invalidate(pendingSetupItemsProvider);
  }
}

/// The title, the count and Continue; the full form adds the step marks and
/// the menu with Hide this card.
class _Steps extends StatelessWidget {
  const _Steps({
    required this.progress,
    required this.compact,
    required this.onContinue,
    required this.onHide,
  });

  final SetUpProgress progress;
  final bool compact;
  final VoidCallback onContinue;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final device = deviceKindArg(deviceKindOf(context));
    final title = Text(
      progress.anyDone
          ? l10n.settings_setUpDevice_titleFinish(device)
          : l10n.settings_setUpDevice_title(device),
      style: textTheme.titleMedium,
    );
    final total = SetUpStep.values.length;
    final count = Semantics(
      label: l10n.settings_setUpDevice_countSemantics(progress.settled, total),
      excludeSemantics: true,
      child: Text(
        l10n.settings_setUpDevice_count(progress.settled, total),
        style: textTheme.bodySmall,
      ),
    );
    final continueButton = FilledButton(
      onPressed: onContinue,
      child: Text(l10n.common_action_continue),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, count],
              ),
            ),
            const SizedBox(width: 12),
            continueButton,
          ],
        ),
      );
    }
    // The menu's own tap target reaches the end edge; everything under the
    // header row keeps the card's 16 dp end inset.
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              count,
              PopupMenuButton<void>(
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    onTap: onHide,
                    child: Text(l10n.settings_setUpDevice_hide),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SetUpStepMarks(marks: progress.marks),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: continueButton,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
