import 'package:flutter/widgets.dart';

import 'package:submersion/features/planner/presentation/planner_navigation.dart';

/// Id of the trim calculator on the Planning hub, and its path segment.
const String kTrimCalculatorToolId = 'trim-calculator';

/// The query parameter naming the dive the trim calculator opens on.
const String kTrimCalculatorDiveParam = 'dive';

/// Where the trim calculator lives, opened on [diveId] (null: the diver's
/// latest dive).
String trimCalculatorLocation({String? diveId}) => Uri(
  path: '/planning/$kTrimCalculatorToolId',
  queryParameters: diveId == null ? null : {kTrimCalculatorDiveParam: diveId},
).toString();

/// Opens the trim calculator on [diveId] from elsewhere in the app, such as
/// the dive's Weights and buoyancy card: pushed, so Back returns to the dive
/// (issue #5028).
void openTrimCalculator(BuildContext context, {required String diveId}) =>
    openInPlanningSection(context, trimCalculatorLocation(diveId: diveId));
