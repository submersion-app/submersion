import 'package:flutter/material.dart';

import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/helpers/site_suggestion_actions.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_banner.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/media/presentation/widgets/quick_site_from_gps_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

const _log = LoggerService('SiteSuggestionCard');

/// The note a sitting keeps while the suggestion resolves a site for it, so
/// a second tap meanwhile starts no second resolve.
const _pickRunningKey = 'siteSuggestionPickRunning';

/// The suggestion banner with its display filled in, given the actions it
/// offers: null disables one.
typedef _BannerFor =
    SiteSuggestionBanner Function({
      VoidCallback? onAssign,
      VoidCallback? onChooseNearby,
      VoidCallback? onCreate,
      VoidCallback? onAddLocation,
      VoidCallback? onDismiss,
    });

/// How the page showing a [SiteSuggestionCard] edits the dive (issue #4527).
sealed class SiteSuggestionEditing {
  const SiteSuggestionEditing();
}

/// A locked dive page: the card keeps its place, and every button and its
/// close are disabled. A locked page shows no control that writes.
final class SiteSuggestionLocked extends SiteSuggestionEditing {
  const SiteSuggestionLocked();
}

/// An editing sitting: the card's actions go to [session], held until Save.
///
/// [layout] is the dive the page lays itself out from while a card is open
/// (`RecordEditController.layoutRecord`), or null while none is, when the
/// page follows the sitting. With one open the card keeps its place even
/// once its suggestion no longer applies, its buttons disabled, so the open
/// editor below it does not move.
final class SiteSuggestionSitting extends SiteSuggestionEditing {
  const SiteSuggestionSitting(this.session, {this.layout});

  final EditSession<Dive> session;
  final Dive? layout;
}

/// How the dive page around [context] edits the dive, for its suggestion
/// card: locked, or the sitting's.
SiteSuggestionEditing siteSuggestionEditingOf(BuildContext context) {
  final controller = RecordEditScope.of<Dive>(context);
  final session = controller.session;
  if (session == null) return const SiteSuggestionLocked();
  return SiteSuggestionSitting(session, layout: controller.layoutRecord);
}

/// Watches the site suggestion for [diveId] and renders the banner with its
/// actions wired. Renders nothing when there is no suggestion, so callers
/// place it unconditionally. Used by the dive page, whose sitting holds
/// what the actions do until Save (issue #4527).
class SiteSuggestionCard extends ConsumerWidget {
  const SiteSuggestionCard({
    super.key,
    required this.diveId,
    required this.currentSite,
    required this.editing,
  });

  final String diveId;

  /// The site the dive page shows for the dive while it is locked: the
  /// persisted one.
  ///
  /// Null means the page is showing no site, not "unset, fall back to the
  /// dive's own": the guard in [build] hides the card whenever this
  /// disagrees with what is persisted, so a caller that omits a site the
  /// dive actually has gets no suggestion rather than one aimed at a site it
  /// is not displaying.
  final DiveSite? currentSite;

  /// How the page edits the dive. With a sitting, [currentSite] is not
  /// read: the card follows the sitting.
  final SiteSuggestionEditing editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched in the card's own build: a sitting's changes rebuild only the
    // builder below, which must not subscribe to providers of its own.
    final suggestion = ref.watch(siteSuggestionForDiveProvider(diveId)).value;
    if (suggestion == null) return const SizedBox.shrink();
    final units = ref.watch(unitFormatterProvider);
    final editing = this.editing;
    if (editing is SiteSuggestionSitting) {
      return ListenableBuilder(
        listenable: editing.session,
        builder: (context, _) =>
            _buildFor(context, ref, suggestion, units, editing),
      );
    }
    return _buildFor(context, ref, suggestion, units, null);
  }

  Widget _buildFor(
    BuildContext context,
    WidgetRef ref,
    SiteSuggestion suggestion,
    UnitFormatter units,
    SiteSuggestionSitting? sitting,
  ) {
    final proposal = suggestion.proposal;
    final session = sitting?.session;
    // The site the card's place is decided from: during a sitting, the dive
    // the page is laid out from.
    final currentSite = sitting == null
        ? this.currentSite
        : (sitting.layout ?? session!.working).site;
    final applies = session == null || _appliesTo(session, suggestion);
    // With no card open the page follows the sitting, and so does this.
    if (sitting != null && sitting.layout == null && !applies) {
      return const SizedBox.shrink();
    }
    // While the sitting is saved the card keeps its place, disabled: the
    // page must not jump under the diver as it saves.
    final live =
        editing is! SiteSuggestionLocked &&
        applies &&
        !(session?.isFrozen ?? false);
    // The suggestion describes what is persisted, but a sitting can hold a
    // site the diver has not saved yet. If that one already has coordinates,
    // or is simply a different site, the banner would offer to place a site
    // it is not actually going to write to. Wait until the sitting and the
    // database agree again.
    if (currentSite?.hasCoordinates == true) return const SizedBox.shrink();
    if (currentSite?.id != proposal.dive.site?.id) {
      return const SizedBox.shrink();
    }
    // Past the guard the sitting and the database agree, so the shown site is
    // the persisted one; no fallback to proposal.dive.site is reachable.
    final hasSite = currentSite != null;
    final recommended = proposal.recommendedCandidateId == null
        ? null
        : proposal.candidates
              .where((c) => c.id == proposal.recommendedCandidateId)
              .firstOrNull;
    final siteName = currentSite?.name ?? recommended?.name ?? '';

    final actions = SiteSuggestionActions(
      diveId: diveId,
      suggestion: suggestion,
    );
    SiteSuggestionBanner banner({
      VoidCallback? onAssign,
      VoidCallback? onChooseNearby,
      VoidCallback? onCreate,
      VoidCallback? onAddLocation,
      VoidCallback? onDismiss,
    }) => SiteSuggestionBanner(
      pointSource: suggestion.pointSource,
      fromDraft: proposal.dive.isDraft,
      coordinates: units.formatCoordinates(
        suggestion.point.latitude,
        suggestion.point.longitude,
      ),
      status: proposal.status,
      hasSite: hasSite,
      siteName: siteName,
      candidateCount: proposal.candidates.length,
      recommendedDistanceMeters: recommended?.distanceMeters,
      onAssign: onAssign,
      onChooseNearby: onChooseNearby,
      onCreate: onCreate,
      onAddLocation: onAddLocation,
      onDismiss: onDismiss,
    );
    if (session != null) {
      return _sittingBanner(
        context,
        ref,
        session,
        suggestion,
        actions,
        banner: banner,
        recommended: recommended,
        live: live,
      );
    }
    // Locked: the card keeps its place, and offers nothing.
    return banner();
  }

  /// Whether the suggestion still applies to the dive of [session]: it has
  /// the site the suggestion is about, that site has no location in the
  /// sitting, and nothing the card does has been held already.
  static bool _appliesTo(EditSession<Dive> session, SiteSuggestion suggestion) {
    if (session.isDisposed) return false;
    final site = session.valueOf(diveSiteField);
    if (site?.id != suggestion.proposal.dive.site?.id) return false;
    if (site?.hasCoordinates ?? false) return false;
    if (session.isHeld(siteSuggestionDismissKey)) return false;
    return site == null || !session.isHeld(siteLocationChangeKey(site.id));
  }

  /// The banner during a sitting: each action goes to [session] and is held
  /// until Save. A site the action creates (a catalogue site adopted, a site
  /// made in the dialog) exists at once; only the dive's link waits.
  Widget _sittingBanner(
    BuildContext context,
    WidgetRef ref,
    EditSession<Dive> session,
    SiteSuggestion suggestion,
    SiteSuggestionActions actions, {
    required _BannerFor banner,
    required MatchCandidateView? recommended,
    required bool live,
  }) {
    final site = suggestion.proposal.dive.site;
    return banner(
      onAssign: !live || recommended == null
          ? null
          : () {
              final rulesAfterCreate = captureRulesAfterCreate(context, ref);
              _pickInSitting(context, session, () async {
                final resolved = await actions.resolve(recommended.id);
                await rulesAfterCreate(
                  subject: RuleSubject.sites,
                  ids: resolved.createdSiteIds,
                );
                return resolved.site;
              });
            },
      onChooseNearby: !live
          ? null
          : () => pickSiteForSitting(context, ref, session),
      onCreate: !live
          ? null
          : () => _createInSitting(context, ref, session, actions, suggestion),
      onAddLocation: !live || site == null
          ? null
          : () {
              final sites = ref.read(siteRepositoryProvider);
              final point = suggestion.point;
              session.holdChange(
                siteLocationChangeKey(site.id),
                cardId: diveHeaderCardId,
                write: () async {
                  await sites.updateSiteCoordinates(site.id, point);
                  // Its altitude is looked up once the save commits, as the
                  // immediate path does once a site gains its location.
                  // Read back: a library site this profile may not edit
                  // declines the write without saying so, and has no new
                  // location to work an altitude or a tide out from.
                  final stored = await sites.getSiteById(site.id);
                  if (stored?.location == point && stored?.altitude == null) {
                    noteSiteLocated(session, site.id, point);
                  }
                },
              );
            },
      onDismiss: !live
          ? null
          : () {
              final dives = ref.read(diveRepositoryProvider);
              session.holdChange(
                siteSuggestionDismissKey,
                cardId: diveHeaderCardId,
                write: () => dives.setSiteSuggestionDismissed(diveId, true),
              );
            },
    );
  }

  Future<void> _createInSitting(
    BuildContext context,
    WidgetRef ref,
    EditSession<Dive> session,
    SiteSuggestionActions actions,
    SiteSuggestion suggestion,
  ) async {
    final draft = await QuickSiteFromGpsDialog.show(
      context,
      latitude: suggestion.point.latitude,
      longitude: suggestion.point.longitude,
    );
    if (draft == null || !context.mounted) return;
    final rulesAfterCreate = captureRulesAfterCreate(context, ref);
    await _pickInSitting(context, session, () async {
      final created = await actions.createUnlinked(draft);
      await rulesAfterCreate(subject: RuleSubject.sites, ids: [created.id]);
      return created;
    });
  }

  /// Puts the site [find] answers with on the dive of [session], with its
  /// rules, if the sitting is still open and still has the site the action
  /// was for. A failure says so and sets nothing.
  ///
  /// The work is the sitting's own ([EditSession.track]), so a Save waits
  /// for it, and one runs at a time: a tap while one runs does nothing.
  Future<void> _pickInSitting(
    BuildContext context,
    EditSession<Dive> session,
    Future<DiveSite?> Function() find,
  ) {
    if (session.recall<bool>(_pickRunningKey) ?? false) return Future.value();
    session.remember(_pickRunningKey, true);
    // Read now: the card may be gone by the time the site comes back.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final assign = readDiveSiteAssigner(context);
    final siteBefore = session.valueOf(diveSiteField)?.id;
    Future<void> pick() async {
      try {
        final site = await find();
        if (site == null || session.isDisposed || session.isFrozen) return;
        if (session.valueOf(diveSiteField)?.id != siteBefore) return;
        assign(session, site);
      } catch (error, stackTrace) {
        _log.warning(
          'Could not resolve the suggested site in a sitting',
          error: error,
          stackTrace: stackTrace,
        );
        // The messenger is the app's: it still shows this once the card
        // has gone. A sitting the diver ended has nobody waiting for it.
        if (session.isDisposed) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.siteMatchReview_applyError)),
        );
      } finally {
        if (!session.isDisposed) session.remember(_pickRunningKey, false);
      }
    }

    final work = pick();
    session.track(work);
    return work;
  }
}
