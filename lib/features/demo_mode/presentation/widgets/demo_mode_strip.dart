import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_confirm.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A strip on every screen while the sample logbook is open, saying so and
/// offering the way out (issue #3708). Nothing at all when demo mode is off.
class DemoModeStrip extends ConsumerWidget {
  const DemoModeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(demoModeActiveProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.explore_outlined,
                size: 20,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              // Label and button share a line when they fit and stack when
              // a narrow window or large text would squeeze the label.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      l10n.demo_strip_label,
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onTertiaryContainer,
                      ),
                      onPressed: () => confirmAndExitDemo(context, ref),
                      child: Text(l10n.demo_strip_exit),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
