import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The Training nav entry's own address. It redirects to the Certifications
/// tab; the tabs keep their long-standing addresses (issue #3437).
const String kTrainingLocation = '/training';

/// The two tabs the Training screen hosts, in their on-screen order.
enum TrainingTab {
  certifications('/certifications', 'certifications'),
  courses('/courses', 'courses');

  const TrainingTab(this.path, this.featureId);

  /// The tab's list address. Detail and edit pages sit under it.
  final String path;

  /// The feature id whose accent colours the tab's header.
  final String featureId;
}

/// The tab whose list address is exactly [path], or null for any other
/// location, including the detail pages under a tab.
TrainingTab? trainingTabForPath(String path) {
  for (final tab in TrainingTab.values) {
    if (tab.path == path) return tab;
  }
  return null;
}

/// The page key both tab addresses build the Training host under.
///
/// The Navigator updates a page in place when the new page has an equal key,
/// so moving between `/certifications` and `/courses` hands the existing host
/// its new tab instead of replacing it. That is what keeps both tabs' scroll,
/// selection and open forms alive across a switch. go_router would otherwise
/// key each address's page by its own path and rebuild the host.
const ValueKey<String> kTrainingHostPageKey = ValueKey<String>('training-host');

/// The page a Training tab address shows: [child] under
/// [kTrainingHostPageKey].
Page<void> trainingHostPage(Widget child) =>
    NoTransitionPage<void>(key: kTrainingHostPageKey, child: child);
