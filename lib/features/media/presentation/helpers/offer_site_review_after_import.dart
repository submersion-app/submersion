import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// After a multi-dive photo import, offers the batch site review for the
/// dives that just became eligible (siteless or coordinate-less site, now
/// with a GPS point, not dismissed). Silent when there is nothing to offer.
/// Pass [messenger] when the calling page is about to pop, so the snackbar
/// lands on the page underneath.
///
/// Best-effort throughout: a missing router, a failed eligibility lookup, a
/// page that went away mid-lookup, or a messenger with nothing to present to
/// all mean "no offer", never a thrown error. Callers invoke this from inside
/// the try that reports an import failure.
Future<void> offerSiteReviewAfterImport(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> diveIds, {
  ScaffoldMessengerState? messenger,
}) async {
  // Sorted so the same dive set always produces the same
  // [ImportedDiveIds] key: it is an Equatable over the list, so two callers
  // holding the ids in different orders would otherwise address two separate
  // autoDispose family entries and repeat the query. The offer's own ordering
  // is unaffected, since the repository returns dives newest-first regardless.
  final ids = diveIds.toSet().toList()..sort();
  if (ids.isEmpty) return;
  // Every context lookup is nullable on purpose. An embedded host or a test
  // tree may carry no messenger, router or localizations, and none of that
  // may become the reason an import reports failure.
  final scaffold = messenger ?? ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.maybeOf(context);
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (scaffold == null || router == null || l10n == null) return;
  final List<String> eligible;
  try {
    eligible = await ref.read(
      eligibleImportedDivesProvider(ImportedDiveIds(ids)).future,
    );
  } catch (_) {
    return;
  }
  if (eligible.isEmpty) return;
  // The lookup is async, so the importing page may be gone by now. Callers
  // run this inside the try that reports an import failure, so a throw here
  // would tell the diver the import broke when it actually succeeded.
  if (!context.mounted) return;
  try {
    scaffold.showSnackBar(
      SnackBar(
        content: Text(l10n.mediaImport_offerSiteReview(eligible.length)),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l10n.mediaImport_reviewSitesAction,
          onPressed: () => router.push('/dives/match-sites', extra: eligible),
        ),
      ),
    );
  } catch (_) {
    // A messenger with nothing left to present to. The offer is a
    // convenience; losing it is not worth failing an import that worked.
  }
}
