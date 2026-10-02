import 'package:flutter/material.dart';

import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// The Dive Edit page's "Underwater Route" row, under Site (spec
/// 2026-10-02-underwater-route-entry-points-design.md, section 1). Shows
/// the routes the dive will have once saved; tapping opens the route sheet.
///
/// A null [draft] means the dive's current links are still loading, or
/// failed to load ([loadFailed], which the row says instead of "None"). Taps
/// are ignored either way, so a Save can never treat "not loaded" as "every
/// route removed".
class RouteRow extends StatelessWidget {
  const RouteRow({
    super.key,
    required this.draft,
    required this.onTap,
    this.loadFailed = false,
  });

  final DiveRouteLinkDraft? draft;
  final VoidCallback onTap;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final routes = draft?.current ?? const [];
    final value = switch (routes) {
      [] => null,
      [final only] => only.displayName,
      [final first, ...] => l10n.navTrack_editRow_more(
        routes.length - 1,
        first.displayName,
      ),
    };
    return FormRow.picker(
      key: const ValueKey('dive-edit-route-row'),
      label: l10n.navTrack_section_title,
      value: value,
      placeholder: loadFailed && draft == null
          ? l10n.navTrack_editRow_loadFailed
          : l10n.navTrack_editRow_none,
      onTap: () {
        if (draft != null) onTap();
      },
    );
  }
}
