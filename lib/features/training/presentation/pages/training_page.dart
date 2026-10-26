import 'package:flutter/material.dart';

import 'package:submersion/core/router/training_locations.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_list_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_list_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tabs_host.dart';

/// The Training screen: Certifications and Courses as two tabs of a
/// [SectionTabsHost] (#3437).
class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key, required this.tab, this.tabBodyBuilder});

  /// The tab the current address names.
  final TrainingTab tab;

  /// Builds a tab's list; the real list pages when null.
  final SectionTabBodyBuilder<TrainingTab>? tabBodyBuilder;

  /// The switch's names, in tab order.
  static List<String> labels(BuildContext context) => [
    context.l10n.nav_certifications,
    context.l10n.nav_courses,
  ];

  static Widget _list(
    BuildContext context,
    TrainingTab tab,
    SectionHeaderTitle headerTitle,
    Map<String, String> query,
  ) => switch (tab) {
    TrainingTab.certifications => CertificationListPage(
      headerTitle: headerTitle,
    ),
    TrainingTab.courses => CourseListPage(headerTitle: headerTitle),
  };

  @override
  Widget build(BuildContext context) => SectionTabsHost<TrainingTab>(
    tabs: TrainingTab.values,
    tab: tab,
    labels: labels,
    toggleKey: const ValueKey('training_section_toggle'),
    bodyBuilder: tabBodyBuilder ?? _list,
  );
}
