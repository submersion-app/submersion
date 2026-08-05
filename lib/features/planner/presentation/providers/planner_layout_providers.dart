import 'package:submersion/core/providers/provider.dart';

/// Session-scoped layout state for the planner's Mission Control layout.
/// Collapse state is remembered for the session, not persisted (same policy
/// as the contingencies-expanded toggle in plan_canvas_providers.dart).

/// Whether the desktop editor pane (segments/tanks/setup) is collapsed.
final editorPaneCollapsedProvider = StateProvider<bool>((_) => false);

/// Whether the desktop results pane is collapsed.
final resultsPaneCollapsedProvider = StateProvider<bool>((_) => false);

/// Whether the results pane is shown at middle widths (760-1160), where it
/// defaults to hidden so the always-visible editor and the chart get the
/// space. Distinct from [resultsPaneCollapsedProvider] (wide-mode state).
final resultsPaneNarrowExpandedProvider = StateProvider<bool>((_) => false);

/// Active phone tab: 0 Plan, 1 Tanks, 2 Setup, 3 Results.
final plannerPhoneTabProvider = StateProvider<int>((_) => 0);

/// Which Setup-accordion sections are expanded (session memory). Kept here
/// instead of PageStorage: ExpansionTile writes its bool into PageStorage
/// under its PageStorageKey, and any TextField inside the section then reads
/// that bool back as a scroll offset (double cast) and crashes.
final setupExpandedSectionsProvider = StateProvider<Set<String>>((_) => {});

/// Setup-accordion section to reveal (header chip deep-links). Keys:
/// 'deco' | 'rates' | 'gas' | 'environment' | 'contingencies' | 'gear'
/// always, plus 'ccr' (CCR mode) and 'pscr' (pSCR mode).
/// Consumed and cleared by the accordion after expanding the section.
final setupFocusSectionProvider = StateProvider<String?>((_) => null);
