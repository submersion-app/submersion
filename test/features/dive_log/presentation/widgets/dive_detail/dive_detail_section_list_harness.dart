import 'package:flutter/widgets.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart';

/// The dive page's section list for [dive], with a blank profile and
/// actions that do nothing: what the section list tests pump, each inside
/// the provider overrides its own cases need.
DiveDetailSectionList sectionListFor(Dive dive) => DiveDetailSectionList(
  dive: dive,
  profileSection: const SizedBox.shrink(),
  safetyReviewKey: GlobalKey(),
  notesKey: GlobalKey(),
  retention: DiveDetailAnalysisRetention(),
  actions: DiveDetailActions(
    setPrimarySource: (_) {},
    splitSource: (_, _) {},
    removeSource: (_, _, _) {},
    separateSegments: (_, _) {},
    openDocument: (_) {},
  ),
);
