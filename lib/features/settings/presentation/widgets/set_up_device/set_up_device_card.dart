import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_pending_items.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_marks.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/device_kind.dart';

/// "Set up this device" (issue #3482): the four steps with their marks and
/// Continue, then whatever needs the diver later (spec 6.5). The full form
/// sits on the Data page, the compact form (title, count, Continue) on the
/// Settings root. Renders nothing when there is nothing to show, so it can
/// sit permanently at the top of either list.
class SetUpDeviceCard extends ConsumerWidget {
  const SetUpDeviceCard({
    super.key,
    this.compact = false,
    required this.onOpenStep,
    this.onSignIn,
    this.margin,
  });

  final bool compact;

  /// Opens [step] of the flow.
  final ValueChanged<SetUpStep> onOpenStep;

  /// Signs in to the account of a sign-in item. Defaults to the account's
  /// own sign-in, or the page that resolves it for a connector.
  final Future<void> Function(BuildContext context, PendingSetupItem item)?
  onSignIn;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(setUpProgressProvider);
    if (progress == null) return const SizedBox.shrink();
    final photosOutstanding =
        progress.showsSteps &&
        progress.marks[SetUpStep.photos] != SetUpMark.done &&
        progress.marks[SetUpStep.photos] != SetUpMark.skipped;
    final items = [
      for (final item
          in ref.watch(pendingSetupItemsProvider).value ??
              const <PendingSetupItem>[])
        // The photo step already covers joining the announced store.
        if (!item.dismissed &&
            !(photosOutstanding && item.kind == SetupItemKind.mediaStoreAttach))
          item,
    ];
    if (!progress.showsSteps && items.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final device = deviceKindArg(deviceKindOf(context));
    final title = progress.anyDone
        ? l10n.settings_setUpDevice_titleFinish(device)
        : l10n.settings_setUpDevice_title(device);
    final count = Semantics(
      label: l10n.settings_setUpDevice_countSemantics(
        progress.settled,
        SetUpStep.values.length,
      ),
      excludeSemantics: true,
      child: Text(
        l10n.settings_setUpDevice_count(
          progress.settled,
          SetUpStep.values.length,
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
    final continueButton = FilledButton(
      onPressed: () => onOpenStep(progress.next!),
      child: Text(l10n.settings_setUpDevice_continue),
    );

    return Card(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.showsSteps && compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        count,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  continueButton,
                ],
              ),
            ),
          if (progress.showsSteps && !compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      count,
                      PopupMenuButton<void>(
                        itemBuilder: (context) => [
                          PopupMenuItem<void>(
                            onTap: () => ref
                                .read(setUpCardPrefsProvider.notifier)
                                .setHidden(true),
                            child: Text(l10n.settings_setUpDevice_hide),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SetUpStepMarks(marks: progress.marks),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: continueButton,
                    ),
                  ),
                ],
              ),
            ),
          if (progress.showsSteps && items.isNotEmpty) const Divider(height: 1),
          if (items.isNotEmpty)
            SetUpPendingItems(
              items: items,
              onOpenStep: onOpenStep,
              onSignIn: (item) =>
                  (onSignIn ?? _signIn(ref)).call(context, item),
              onDismiss: (item) async {
                await PendingSetupService.dismissKey(
                  ref.read(sharedPreferencesProvider),
                  item.key,
                );
                ref.invalidate(pendingSetupItemsProvider);
              },
            ),
        ],
      ),
    );
  }

  /// The account's own sign-in when the account sheet can run it here;
  /// otherwise (a connector, or a row not in any group) the page that
  /// resolves the item.
  Future<void> Function(BuildContext, PendingSetupItem) _signIn(
    WidgetRef ref,
  ) => (context, item) async {
    final groups = await ref.read(accountGroupsProvider.future);
    final group = groups.firstWhereOrNull(
      (g) => g.rows.any((r) => r.id == item.accountId),
    );
    if (!context.mounted) return;
    if (group == null || group.kind == AccountKind.adobeLightroom) {
      await context.pushSettingsPage(item.route);
      return;
    }
    await signInToGroup(context, ref, group);
    // The item may have resolved and taken the card's tile away meanwhile.
    if (!context.mounted) return;
    refreshAccountState(ref.invalidate);
  };
}
