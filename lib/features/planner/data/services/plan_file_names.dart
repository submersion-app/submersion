import 'package:submersion/core/services/export/shared/export_file_name.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';

/// `<plan>.subplan`, the plan's name as a [fileNameSegment];
/// `dive_plan.subplan` when it has none.
String subplanFileName(String planName) =>
    exportFileName([_stem(planName)], subplanExtension);

/// `<plan>_slate.pdf`, named like [subplanFileName].
String planSlateFileName(String planName) =>
    exportFileName([_stem(planName), 'slate'], 'pdf');

String _stem(String planName) {
  final segment = fileNameSegment(planName);
  return segment.isEmpty ? 'dive_plan' : segment;
}
