import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';

class _WhatIfEntry {}

final _log = LoggerService.forClass(_WhatIfEntry);

/// The single "Compare..." front door on dive detail: the Compare page when the
/// dive can be branched or has a linked plan, else the rebuild-in-planner
/// sheet, so a gauge dive with a profile keeps the path it has today.
Future<void> openWhatIf(BuildContext context, Dive dive) async {
  if (isDiveLabEligible(dive)) return showDiveLab(context, dive.id);
  final container = ProviderScope.containerOf(context, listen: false);
  LinkedPlanComparison? comparison;
  try {
    comparison = await container.read(
      linkedPlanComparisonProvider(dive.id).future,
    );
  } catch (e, stackTrace) {
    // A plan that will not load must not cost the dive its way in.
    _log.error(
      'Failed to read the plan linked to dive ${dive.id}',
      error: e,
      stackTrace: stackTrace,
    );
  }
  if (!context.mounted) return;
  if (comparison != null) return showDiveLab(context, dive.id);
  return showWhatIfSheet(context, dive);
}
