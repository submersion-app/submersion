import 'package:equatable/equatable.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';

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

/// The [MediaDropDestination] for the screen [state] describes, or null when
/// that screen does not take photos and videos.
///
/// [detailPaneVisible] is whether the window is wide enough for a list to
/// show its selected item beside it (`ResponsiveBreakpoints.isMasterDetail`).
MediaDropDestination? mediaDropDestinationFor(
  GoRouterState state, {
  required bool detailPaneVisible,
}) => mediaDropDestinationForRoute(
  routeName: state.topRoute?.name,
  pathParameters: state.pathParameters,
  uri: state.uri,
  detailPaneVisible: detailPaneVisible,
);

/// Pure form of [mediaDropDestinationFor], keyed on the deepest matched
/// route's name rather than on the path, so a sibling route such as
/// `/dives/new` or a page under a dive such as its editor never reads as a
/// dive detail.
///
/// On wide layouts the dive and site lists show the selected item beside
/// the list (`?selected=<id>`). That item is the destination only while its
/// detail is what the pane shows: not in a window too narrow for the pane
/// ([detailPaneVisible] false), where the list stands alone and the id left
/// in the URL names a dive or site the user cannot see; not while it is
/// being edited or created; and not while the map replaces the detail.
MediaDropDestination? mediaDropDestinationForRoute({
  required String? routeName,
  required Map<String, String> pathParameters,
  required Uri uri,
  required bool detailPaneVisible,
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
      final diveId = detailPaneVisible ? _selectedDetailId(uri) : null;
      return diveId == null
          ? null
          : MediaDropDestination(target: DiveAttachTarget(diveId));
    case 'sites':
      final siteId = detailPaneVisible ? _selectedDetailId(uri) : null;
      return siteId == null
          ? null
          : MediaDropDestination(target: SiteAttachTarget(siteId));
  }
  return null;
}

/// The id of the item a master-detail list is showing in view mode, if any.
String? _selectedDetailId(Uri uri) {
  final query = uri.queryParameters;
  final selected = query['selected'];
  if (selected == null || selected.isEmpty) return null;
  if (query.containsKey('mode') || query['view'] == 'map') return null;
  return selected;
}
