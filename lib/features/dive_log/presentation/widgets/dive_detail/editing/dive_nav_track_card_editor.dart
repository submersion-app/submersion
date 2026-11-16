import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_link_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/route_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The Underwater track card's editor: the dive form's route row and sheet
/// over the sitting's draft, and, with more than one route, which is the
/// primary. A route imported from a file in the sheet is created at once,
/// unlinked, as today; linking it is held until Save. A planned dive has no
/// route (plan 4), so the editor offers none.
class DiveNavTrackCardEditor extends StatelessWidget {
  const DiveNavTrackCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final working = session.working;
        if (working.isPlanned) return const SizedBox.shrink();
        final draft = sittingRouteDraft(session);
        final routes = draft?.current ?? const [];
        final primary =
            draft?.primaryId ??
            routes.where((r) => r.isPrimary).firstOrNull?.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RouteRow(
              draft: draft,
              onTap: () {
                final current = sittingRouteDraft(session);
                if (current == null) return;
                showRouteLinkSheet(
                  context,
                  draft: current,
                  entryTime: working.effectiveEntryTime,
                  onChanged: (next) => setRouteDraft(session, next),
                );
              },
            ),
            if (routes.length > 1)
              for (final route in routes)
                ListTile(
                  key: ValueKey('nav-track-primary-${route.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(route.displayName),
                  // Under the title, so a longer translation leaves the
                  // route's name its width.
                  subtitle: route.id == primary
                      ? Text(context.l10n.navTrack_section_primaryTag)
                      : TileSubtitleAction(
                          label: context.l10n.navTrack_section_menuMakePrimary,
                          onPressed: () {
                            final current = sittingRouteDraft(session);
                            if (current == null) return;
                            setRouteDraft(
                              session,
                              current.withPrimary(route.id),
                            );
                          },
                        ),
                ),
          ],
        );
      },
    );
  }
}
