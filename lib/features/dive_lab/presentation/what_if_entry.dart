import 'package:flutter/widgets.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';

/// The single "What if..." front door on dive detail: the Dive Lab when the
/// dive can be branched, else the rebuild-in-planner sheet, so a gauge dive
/// with a profile keeps the path it has today.
Future<void> openWhatIf(BuildContext context, Dive dive) {
  if (isDiveLabEligible(dive)) return showDiveLab(context, dive.id);
  return showWhatIfSheet(context, dive);
}
