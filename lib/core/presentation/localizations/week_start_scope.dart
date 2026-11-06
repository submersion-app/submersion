import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/localizations/week_start_material_localizations.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Starts every week below it on the diver's first day of the week (issue
/// #4232), by handing [child] [MaterialLocalizations] whose
/// [MaterialLocalizations.firstDayOfWeekIndex] follows
/// [firstWeekdayProvider].
///
/// Sits in `MaterialApp.builder`, above the navigator, so the routes and
/// dialogs it opens, the date pickers included, inherit it. The override is
/// in place even when the setting resolves to the language's own default,
/// so changing the setting never swaps the widget above the navigator and
/// throws away its routes.
class WeekStartScope extends ConsumerWidget {
  const WeekStartScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstWeekday = ref.watch(firstWeekdayProvider);
    return Localizations.override(
      context: context,
      delegates: [WeekStartMaterialLocalizationsDelegate(firstWeekday)],
      child: child,
    );
  }
}
