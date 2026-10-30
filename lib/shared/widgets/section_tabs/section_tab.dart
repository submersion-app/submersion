import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// One tab of a nav entry that holds two sections as tabs, such as
/// Training's Certifications and Courses (#3437) or Media's Photos/Videos
/// and Documents (#3631). Implemented by an enum whose declaration order is
/// the tabs' on-screen order.
abstract interface class SectionTab implements Enum {
  /// The tab's list address. Detail and edit pages sit under it.
  String get path;

  /// The feature id whose accent colours the tab's header.
  String get featureId;
}

/// The tab of [tabs] whose list address is exactly [path], or null for any
/// other location, including the detail pages under a tab.
T? sectionTabForPath<T extends SectionTab>(List<T> tabs, String path) {
  for (final tab in tabs) {
    if (tab.path == path) return tab;
  }
  return null;
}

/// The page every tab address of one host builds: [child] under [key].
///
/// The Navigator updates a page in place when the new page has an equal key,
/// so moving between two tabs' addresses hands the existing host its new tab
/// instead of replacing it. That is what keeps both tabs' scroll, selection
/// and open forms alive across a switch. go_router would otherwise key each
/// address's page by its own path and rebuild the host.
Page<void> sectionTabsHostPage(ValueKey<String> key, Widget child) =>
    NoTransitionPage<void>(key: key, child: child);
