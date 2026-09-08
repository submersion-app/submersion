import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/widgets/nav_order_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Lets the diver arrange the navigation destinations for each surface.
///
/// Phone and desktop keep independent orders, so the page edits one at a time
/// and the segmented control chooses which.
class NavCustomizationPage extends ConsumerStatefulWidget {
  const NavCustomizationPage({super.key});

  @override
  ConsumerState<NavCustomizationPage> createState() =>
      _NavCustomizationPageState();
}

class _NavCustomizationPageState extends ConsumerState<NavCustomizationPage> {
  /// Which surface is being edited. Starts on the one matching this device so
  /// the common case takes no taps, but either is reachable from either.
  NavOrderScope? _scope;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = _scope ??= ResponsiveBreakpoints.isDesktop(context)
        ? NavOrderScope.desktop
        : NavOrderScope.phone;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_navCustomization_title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<NavOrderScope>(
              key: const ValueKey('navScopeSegments'),
              segments: [
                ButtonSegment(
                  value: NavOrderScope.phone,
                  icon: const Icon(Icons.smartphone),
                  label: Text(l10n.settings_navCustomization_scopePhone),
                ),
                ButtonSegment(
                  value: NavOrderScope.desktop,
                  icon: const Icon(Icons.desktop_windows_outlined),
                  label: Text(l10n.settings_navCustomization_scopeDesktop),
                ),
              ],
              selected: {scope},
              onSelectionChanged: (selection) =>
                  setState(() => _scope = selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              scope == NavOrderScope.phone
                  ? l10n.settings_navCustomization_description
                  : l10n.settings_navCustomization_descriptionDesktop,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            // Keyed by scope so switching surfaces builds a fresh editor
            // seeded from the other provider rather than reusing the mirror.
            child: NavOrderEditor(key: ValueKey(scope), scope: scope),
          ),
        ],
      ),
    );
  }
}
