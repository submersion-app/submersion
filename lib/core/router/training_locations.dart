import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/section_tabs/section_tab.dart';

/// The Training nav entry's own address. It redirects to the Certifications
/// tab; the tabs keep their long-standing addresses (issue #3437).
const String kTrainingLocation = '/training';

/// The two tabs the Training screen hosts, in their on-screen order.
enum TrainingTab implements SectionTab {
  certifications('/certifications', 'certifications'),
  courses('/courses', 'courses');

  const TrainingTab(this.path, this.featureId);

  @override
  final String path;

  @override
  final String featureId;
}

/// The page key both tab addresses build the Training host under, so moving
/// between `/certifications` and `/courses` keeps the host (see
/// [sectionTabsHostPage]).
const ValueKey<String> kTrainingHostPageKey = ValueKey<String>('training-host');

/// The page a Training tab address shows: [child] under
/// [kTrainingHostPageKey].
Page<void> trainingHostPage(Widget child) =>
    sectionTabsHostPage(kTrainingHostPageKey, child);
