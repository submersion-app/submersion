import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';

/// The single "Compare..." front door on dive detail: the Compare page when the
/// dive can be branched or has a linked plan, else the rebuild-in-planner
/// sheet, so a gauge dive with a profile keeps the path it has today.
Future<void> openWhatIf(BuildContext context, Dive dive) async {
  if (isDiveLabEligible(dive)) return showDiveLab(context, dive.id);
  final comparison = await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(linkedPlanComparisonProvider(dive.id).future);
  if (!context.mounted) return;
  if (comparison != null) return showDiveLab(context, dive.id);
  return showWhatIfSheet(context, dive);
}
