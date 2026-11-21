import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

    // Each surface persists its own value (#3222): switching tabs switches
    // which provider and repository method the switch below reads/writes.
    final alwaysHideLabelsAsync = scope == NavOrderScope.phone
        ? ref.watch(navAlwaysHideLabelsPhoneProvider)
        : ref.watch(navAlwaysHideLabelsDesktopProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_navCustomization_title)),
      // Keyed by scope so switching surfaces builds a fresh editor seeded from
      // the other provider rather than reusing the mirror. The settings ride
      // in as its header so the whole page shares the list's scroll axis
      // (#3370).
      body: NavOrderEditor(
        key: ValueKey(scope),
        scope: scope,
        header: Column(
          mainAxisSize: MainAxisSize.min,
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
            // Both surfaces stay on this device (#2947), which a diver with
            // several devices otherwise reads as a sync bug (#4454).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _DeviceOnlyNote(
                text: l10n.settings_navCustomization_deviceOnlyNote,
              ),
            ),
            const Divider(height: 1),
            alwaysHideLabelsAsync.when(
              data: (alwaysHideLabels) => SwitchListTile(
                key: const ValueKey('navAlwaysHideLabelsSwitch'),
                title: Text(
                  l10n.settings_navCustomization_alwaysHideLabels_title,
                ),
                subtitle: Text(
                  scope == NavOrderScope.phone
                      ? l10n.settings_navCustomization_alwaysHideLabels_subtitle
                      : l10n.settings_navCustomization_alwaysHideLabels_subtitleDesktop,
                ),
                value: alwaysHideLabels,
                onChanged: (value) async {
                  try {
                    final repo = ref.read(appSettingsRepositoryProvider);
                    if (scope == NavOrderScope.phone) {
                      await repo.setNavAlwaysHideLabelsPhone(value);
                      ref.invalidate(navAlwaysHideLabelsPhoneProvider);
                    } else {
                      await repo.setNavAlwaysHideLabelsDesktop(value);
                      ref.invalidate(navAlwaysHideLabelsDesktopProvider);
                    }
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.common_error_tryAgain)),
                    );
                  }
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says the layout is saved on this device only: an info icon beside [text]
/// on a pale primary-coloured panel, shaped like `SafetyNote` but informative
/// rather than a warning.
class _DeviceOnlyNote extends StatelessWidget {
  const _DeviceOnlyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
