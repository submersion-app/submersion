import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reviews and links [dive]'s legacy buddy and dive-master text (#1831).
Future<void> linkLegacyBuddiesForDive(BuildContext context, Dive dive) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final diverId =
      dive.diverId ??
      await container.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null || !context.mounted) return;
  final (ConversionPlan, BuddyNameMatcher) planned;
  try {
    planned = await container
        .read(legacyBuddyConversionServiceProvider)
        .planFor(dive, diverId);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.buddies_linkText_error('$e'))),
    );
    return;
  }
  if (!context.mounted) return;
  final (plan, matcher) = planned;
  final reviewed = await showLegacyBuddyReviewSheet(
    context,
    plan: plan,
    matcher: matcher,
  );
  if (reviewed == null || reviewed.isEmpty) return;
  await applyLegacyBuddyPlans(
    container: container,
    messenger: messenger,
    l10n: l10n,
    plans: [reviewed],
    diverId: diverId,
    successMessage: (receipt) =>
        l10n.buddies_linkText_linkedSnackbar(receipt.linkIds.length),
  );
}

/// Applies [plans], refreshes what they change, and offers Undo. Returns the
/// receipt, or null when applying failed (after showing an error).
///
/// Works through [container] rather than a `WidgetRef` so Undo still works
/// after the page that ran the conversion is gone.
Future<ConversionReceipt?> applyLegacyBuddyPlans({
  required ProviderContainer container,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required List<ConversionPlan> plans,
  required String diverId,
  required String Function(ConversionReceipt receipt) successMessage,
}) async {
  final service = container.read(legacyBuddyConversionServiceProvider);
  final ConversionReceipt receipt;
  try {
    receipt = await service.apply(
      plans,
      diverId: diverId,
      newBuddyNote: l10n.buddies_linkText_newBuddyNote,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.buddies_linkText_error('$e'))),
    );
    return null;
  }
  refreshAfterLegacyBuddyConversion(container);
  if (receipt.isEmpty) return receipt;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(successMessage(receipt)),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss and
        // allow closing without triggering Undo.
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.diveLog_bulkDelete_undo,
          onPressed: () async {
            try {
              await service.undo(receipt);
              refreshAfterLegacyBuddyConversion(container);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(l10n.buddies_linkText_undone),
                  duration: const Duration(seconds: 2),
                ),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.buddies_linkText_error('$e'))),
              );
            }
          },
        ),
      ),
    );
  return receipt;
}
