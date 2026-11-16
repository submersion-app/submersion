import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_text_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Buddies card's editor: the dive form's buddy picker, with the
/// diver's own roles as its Me chip, over the sitting's buddies.
///
/// A buddy or a role created from the picker exists at once and outlives a
/// cancelled sitting; only who is on the dive, with which roles, is held
/// until Save.
class DiveBuddiesCardEditor extends ConsumerStatefulWidget {
  const DiveBuddiesCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveBuddiesCardEditor> createState() =>
      _DiveBuddiesCardEditorState();
}

class _DiveBuddiesCardEditorState extends ConsumerState<DiveBuddiesCardEditor> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiveBuddiesCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  /// Reads the buddies again while the diver has not changed them, and
  /// draws them once they are in.
  void _load() {
    diveBuddiesList.load(widget.session).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Reads again after a read that failed, waiting with a spinner.
  void _retry() {
    _load();
    setState(() {});
  }

  /// Plans the dive's legacy text and asks the diver to review it, as the
  /// read card's immediate path does, then holds the links in the sitting.
  Future<void> _linkLegacy(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    final note = context.l10n.buddies_linkText_newBuddyNote;
    final session = widget.session;
    return linkLegacyBuddiesInSitting(
      session,
      read: container.read,
      newBuddyNote: note,
      plan: (diverId) async {
        final (plan, matcher) = await container
            .read(legacyBuddyConversionServiceProvider)
            .planFor(session.working, diverId);
        if (!context.mounted) return null;
        final ConversionPlan? reviewed = await showLegacyBuddyReviewSheet(
          context,
          plan: plan,
          matcher: matcher,
        );
        return reviewed;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final current = diveBuddiesList.current(session);
        if (current == null && diveBuddiesList.failed(session)) {
          return SittingLoadFailed(onRetry: _retry);
        }
        if (current == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final working = session.working;
        final loaded = diveBuddiesList.loaded(session) ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current.isEmpty && LegacyBuddyTextSection.hasContent(working))
              LegacyBuddyTextSection(dive: working, onLink: _linkLegacy),
            BuddyPicker(
              diveId: session.stored.id,
              selectedBuddies: current,
              onChanged: (buddies) {
                diveBuddiesList.set(session, buddies);
                // A buddy taken off the dive takes the signature they gave
                // in this sitting with them.
                dropSignaturesOfRemovedBuddies(session);
              },
              diverRoleIds: session.valueOf(diveDiverRoleIdsField),
              onDiverRoleChanged: (ids) =>
                  session.set(diveDiverRoleIdsField, ids),
              // Roles the dive had when the sitting read it stay offered
              // even when hidden from the pickers (issue #401).
              keepRoleIds: {
                ...session.stored.diverRoleIds,
                for (final b in loaded) ...b.roleIds,
              },
              diveOwnerId: session.stored.diverId,
            ),
          ],
        );
      },
    );
  }
}
