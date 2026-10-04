import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A section of the trip edit form that it can open at (#2880), named in
/// the URL's `section` query parameter.
enum TripEditSection {
  planning;

  /// The section a `section` query parameter names; null when there is none
  /// or the name is unknown.
  static TripEditSection? fromQuery(String? name) =>
      name == null ? null : values.asNameMap()[name];
}

/// Opens trip [tripId]'s edit form, at [section] when one is given.
///
/// A trip shown [embedded] in the master-detail pane edits in that pane, the
/// way the pane's own edit button does; anywhere else the edit page is pushed.
void openTripEdit(
  BuildContext context,
  String tripId, {
  required bool embedded,
  TripEditSection? section,
}) {
  final sectionQuery = {if (section != null) 'section': section.name};
  if (embedded) {
    final path = GoRouterState.of(context).uri.path;
    context.go(
      Uri(
        path: path,
        queryParameters: {'selected': tripId, 'mode': 'edit', ...sectionQuery},
      ).toString(),
    );
  } else {
    context.push(
      Uri(
        path: '/trips/$tripId/edit',
        // An empty map would leave a bare '?' on the location.
        queryParameters: sectionQuery.isEmpty ? null : sectionQuery,
      ).toString(),
    );
  }
}
