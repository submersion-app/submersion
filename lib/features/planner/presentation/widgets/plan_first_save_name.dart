import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/planner/domain/services/plan_name_generator.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for the name of the plan in the editor the first time it is saved,
/// suggesting one from its site, depth and date, and names the plan with
/// what was entered. Shared by the planner's Save and the save a replace
/// prompt offers, so the saved-plans list is not a wall of identically-named
/// rows whichever saved it.
///
/// False when the diver cancels, so nothing is written and the plan stays
/// unsaved, or when [context] is gone by the time the dialog would open.
Future<bool> nameFirstSave(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final siteId = ref.read(divePlanNotifierProvider).siteId;
  final site = siteId == null
      ? null
      : await ref.read(siteProvider(siteId).future);
  if (!context.mounted) return false;

  // Re-read after the site lookup rather than before it. No modal is up
  // while that read resolves, so the diver can still edit the plan and the
  // suggested name must describe what the plan is now.
  final planState = ref.read(divePlanNotifierProvider);
  final suggestedDepth = ref.read(planOutcomeProvider).maxDepth;
  // The lookup was keyed on the pre-await id. If the diver switched sites
  // while it resolved, the fetched name describes a site the plan no longer
  // uses, so drop it rather than pair it with fresh depth and date.
  final siteName = planState.siteId == siteId ? site?.name : null;

  final entered = await showPlanNameDialog(
    context,
    initialName: generateDefaultPlanName(
      siteName: siteName,
      depthLabel: suggestedDepth > 0 ? units.formatDepth(suggestedDepth) : null,
      dateLabel: units.formatMonthDay(
        planState.startDateTime ?? DateTime.now(),
      ),
      fallbackLabel: l10n.plannerCanvas_name_defaultFallback,
    ),
    title: l10n.plannerCanvas_name_dialogTitle,
  );
  // Cancel aborts the save entirely: nothing is written and the plan stays
  // dirty, so the diver is never surprised by a name they rejected.
  if (entered == null || !context.mounted) return false;
  ref.read(divePlanNotifierProvider.notifier).updateName(entered);
  return true;
}
