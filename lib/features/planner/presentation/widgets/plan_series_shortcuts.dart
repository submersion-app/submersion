import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:submersion/core/accessibility/not_while_typing_activator.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';

/// The planner's shortcut category, and the labels its entries are listed
/// under in the shortcuts help: English identifiers, translated at render
/// time like the app's own (see `shortcut_display.dart`).
const plannerShortcutCategory = 'Planner';
const previousPlannedDiveShortcut = 'Previous planned dive';
const nextPlannedDiveShortcut = 'Next planned dive';

const _previous = SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true);
const _next = SingleActivator(LogicalKeyboardKey.arrowRight, alt: true);

/// Keyboard shortcuts for moving through a repetitive series (issue #3565):
/// Alt+Left and Alt+Right select the previous and next dive. Neither fires
/// while a text field has focus, where Alt+arrow moves by word.
///
/// They are listed in the shortcuts help while the planner is open.
class PlanSeriesShortcuts extends ConsumerStatefulWidget {
  const PlanSeriesShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlanSeriesShortcuts> createState() =>
      _PlanSeriesShortcutsState();
}

class _PlanSeriesShortcutsState extends ConsumerState<PlanSeriesShortcuts> {
  @override
  void initState() {
    super.initState();
    ShortcutCatalog.instance
      ..unregisterCategory(plannerShortcutCategory)
      ..registerAll(const [
        ShortcutEntry(
          label: previousPlannedDiveShortcut,
          category: plannerShortcutCategory,
          activator: _previous,
        ),
        ShortcutEntry(
          label: nextPlannedDiveShortcut,
          category: plannerShortcutCategory,
          activator: _next,
        ),
      ]);
  }

  @override
  void dispose() {
    ShortcutCatalog.instance.unregisterCategory(plannerShortcutCategory);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final series = ref.read(planSeriesNotifierProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        const NotWhileTypingActivator(_previous): series.previous,
        const NotWhileTypingActivator(_next): series.next,
      },
      child: Focus(child: widget.child),
    );
  }
}
