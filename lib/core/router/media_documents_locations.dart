import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The two tabs the Media and Documents screen hosts, in their on-screen
/// order (#3631).
enum MediaDocumentsTab {
  media('/media', 'media'),
  documents('/documents', 'documents');

  const MediaDocumentsTab(this.path, this.featureId);

  /// The tab's list address. Detail and edit pages sit under it.
  final String path;

  /// The feature id whose accent colours the tab's header.
  final String featureId;
}

/// The tab whose list address is exactly [path], or null for any other
/// location, including the detail pages under a tab.
MediaDocumentsTab? mediaDocumentsTabForPath(String path) {
  for (final tab in MediaDocumentsTab.values) {
    if (tab.path == path) return tab;
  }
  return null;
}

/// The page key both tab addresses build the Media and Documents host
/// under.
///
/// The Navigator updates a page in place when the new page has an equal key,
/// so moving between `/media` and `/documents` hands the existing host its
/// new tab instead of replacing it. That is what keeps both tabs' scroll,
/// selection and open forms alive across a switch. go_router would otherwise
/// key each address's page by its own path and rebuild the host.
const ValueKey<String> kMediaDocumentsHostPageKey = ValueKey<String>(
  'media-documents-host',
);

/// The page a Media or Documents tab address shows: [child] under
/// [kMediaDocumentsHostPageKey].
Page<void> mediaDocumentsHostPage(Widget child) =>
    NoTransitionPage<void>(key: kMediaDocumentsHostPageKey, child: child);
