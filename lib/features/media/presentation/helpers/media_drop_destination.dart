import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Where photos and videos dropped onto the app window are imported.
///
/// A null [target] is the Media section's library importer, which matches
/// each file to a dive by its capture time. A non-null one is the dive or
/// site on screen, which owns the files the way it does when its own "add
/// photos" action is used.
class MediaDropDestination extends Equatable {
  const MediaDropDestination({this.target});

  final MediaAttachTarget? target;

  @override
  List<Object?> get props => [target];
}

/// The [MediaDropDestination] for the screen on show at [context], or null
/// when that screen does not take photos and videos.
MediaDropDestination? mediaDropDestinationFor(
  BuildContext context,
  WidgetRef ref,
) {
  final state = GoRouterState.of(context);
  final wideWindow = ResponsiveBreakpoints.isMasterDetail(context);
  return mediaDropDestinationForRoute(
    routeName: state.topRoute?.name,
    pathParameters: state.pathParameters,
    uri: state.uri,
    isDetailVisible: (sectionKey) => isListDetailVisible(
      wideWindow: wideWindow,
      tableMode:
          ref.read(
            sectionKey == 'sites'
                ? siteListViewModeProvider
                : diveListViewModeProvider,
          ) ==
          ListViewMode.table,
      tableDetailsPane: ref.read(tableDetailsPaneProvider(sectionKey)),
      uri: state.uri,
    ),
  );
}

/// Whether a dive or site list is showing its selected item's detail, which
/// is what makes that item a drop's destination. Mirrors the two layouts:
///
/// - Both need a window wide enough for a detail pane ([wideWindow]); below
///   it the list stands alone, and the id left in the URL names a dive or
///   site the user cannot see.
/// - The table layout shows the pane only while its per-section toggle
///   ([tableDetailsPane]) is on, and keeps it beside the map.
/// - The list layout swaps the detail for the map (`view=map`).
bool isListDetailVisible({
  required bool wideWindow,
  required bool tableMode,
  required bool tableDetailsPane,
  required Uri uri,
}) {
  if (!wideWindow) return false;
  if (tableMode) return tableDetailsPane;
  return uri.queryParameters['view'] != 'map';
}

/// Pure form of [mediaDropDestinationFor], keyed on the deepest matched
/// route's name rather than on the path, so a sibling route such as
/// `/dives/new` or a page under a dive such as its editor never reads as a
/// dive detail.
///
/// On wide layouts the dive and site lists show the selected item beside
/// the list (`?selected=<id>`). That item is the destination only while its
/// detail is on screen, which [isDetailVisible] answers for the route's
/// section (`dives` or `sites`; see [isListDetailVisible]), and not while it
/// is being edited or created.
MediaDropDestination? mediaDropDestinationForRoute({
  required String? routeName,
  required Map<String, String> pathParameters,
  required Uri uri,
  required bool Function(String sectionKey) isDetailVisible,
}) {
  switch (routeName) {
    case 'media':
      return const MediaDropDestination();
    case 'diveDetail':
      final diveId = pathParameters['diveId'];
      return diveId == null
          ? null
          : MediaDropDestination(target: DiveAttachTarget(diveId));
    case 'siteDetail':
      final siteId = pathParameters['siteId'];
      return siteId == null
          ? null
          : MediaDropDestination(target: SiteAttachTarget(siteId));
    case 'dives':
      final diveId = isDetailVisible('dives') ? _selectedDetailId(uri) : null;
      return diveId == null
          ? null
          : MediaDropDestination(target: DiveAttachTarget(diveId));
    case 'sites':
      final siteId = isDetailVisible('sites') ? _selectedDetailId(uri) : null;
      return siteId == null
          ? null
          : MediaDropDestination(target: SiteAttachTarget(siteId));
  }
  return null;
}

/// The id of the item a list has selected in view mode, if any.
String? _selectedDetailId(Uri uri) {
  final query = uri.queryParameters;
  final selected = query['selected'];
  if (selected == null || selected.isEmpty) return null;
  if (query.containsKey('mode')) return null;
  return selected;
}
