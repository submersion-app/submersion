import 'dart:math';

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized, unit-aware message for a plan issue. Reuses the existing
/// `divePlanner_warning_*` strings where a type overlaps, so only genuinely
/// new issue types need new keys.
String planIssueMessage(
  BuildContext context,
  PlanIssue issue,
  UnitFormatter units,
) {
  final l10n = context.l10n;
  switch (issue.type) {
    case PlanIssueType.ppO2High:
      return l10n.divePlanner_warning_ppO2High(
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.ppO2Critical:
      return l10n.divePlanner_warning_ppO2Critical(
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.hypoxicGas:
      return l10n.plannerCanvas_issue_hypoxic(
        units.formatDepth(issue.atDepth ?? 0, decimals: 0),
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.endExceeded:
      // The engine compares unrounded values, so plain rounding could print
      // "30m exceeds the 30m limit" for an END of 30.05 m. Round the END up
      // and the limit down; the epsilon stops float noise (32.0000001) from
      // bumping a whole value. The engine only raises this issue when the END
      // is above the limit, so an END within the epsilon of it is still shown
      // one unit higher rather than equal.
      const epsilon = 1e-6;
      final limit = (units.convertDepth(issue.threshold ?? 0) + epsilon)
          .floor();
      final end = max(
        (units.convertDepth(issue.value ?? 0) - epsilon).ceil(),
        limit + 1,
      );
      return l10n.divePlanner_warning_endExceedsLimit(
        units.formatDepth(units.depthToMeters(end.toDouble()), decimals: 0),
        units.formatDepth(units.depthToMeters(limit.toDouble()), decimals: 0),
      );
    case PlanIssueType.gasDensityHigh:
      return l10n.plannerCanvas_issue_gasDensityHigh(
        issue.value?.toStringAsFixed(1) ?? '--',
      );
    case PlanIssueType.gasDensityCritical:
      return l10n.plannerCanvas_issue_gasDensityCritical(
        issue.value?.toStringAsFixed(1) ?? '--',
      );
    case PlanIssueType.cnsWarning:
      return l10n.divePlanner_warning_cnsWarning(
        issue.value?.toStringAsFixed(0) ?? '--',
      );
    case PlanIssueType.cnsCritical:
      return l10n.divePlanner_warning_cnsCritical;
    case PlanIssueType.otuHigh:
      return l10n.divePlanner_warning_otuWarning;
    case PlanIssueType.gasReserveViolation:
      return l10n.divePlanner_warning_gasLow(
        units.formatPressure(issue.threshold ?? 0),
      );
    case PlanIssueType.gasOut:
      return l10n.divePlanner_warning_gasOut;
    case PlanIssueType.ndlExceededNoDecoGas:
      return l10n.plannerCanvas_issue_noDecoGas;
    case PlanIssueType.noBailoutCarried:
      return l10n.plannerCanvas_issue_noBailout;
    case PlanIssueType.minGasViolation:
      return l10n.plannerCanvas_issue_minGas(
        units.formatPressure(issue.threshold ?? 0),
      );
    case PlanIssueType.noUsableGas:
      return l10n.plannerCanvas_issue_noUsableGas(
        units.formatPressure(issue.value ?? 0),
        units.formatPressure(issue.threshold ?? 0),
      );
    case PlanIssueType.diluentModExceeded:
      return l10n.plannerCanvas_issue_diluentModExceeded(
        units.formatDepth(issue.atDepth ?? 0, decimals: 0),
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.ceilingViolated:
      return l10n.plannerCanvas_issue_ceilingViolated(
        units.formatDepth(issue.value ?? 0, decimals: 1),
      );
  }
}

/// Icon for a plan-issue severity, as the warnings list shows it.
IconData planIssueIcon(PlanIssueSeverity severity) {
  switch (severity) {
    case PlanIssueSeverity.critical:
      return Icons.error;
    case PlanIssueSeverity.alert:
      return Icons.warning;
    case PlanIssueSeverity.warning:
      return Icons.warning_amber;
    case PlanIssueSeverity.info:
      return Icons.info_outline;
  }
}
