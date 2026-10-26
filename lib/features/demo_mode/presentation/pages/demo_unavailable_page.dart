import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_confirm.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown in place of a screen demo mode seals: the feature exists, and this
/// says why it cannot be used while exploring the sample logbook.
class DemoUnavailablePage extends ConsumerWidget {
  const DemoUnavailablePage({super.key, required this.feature});

  final DemoSealedFeature feature;

  /// The feature named in a `?feature=` query, defaulting to import.
  static DemoSealedFeature featureFromQuery(String? name) =>
      DemoSealedFeature.values.where((f) => f.name == name).firstOrNull ??
      DemoSealedFeature.fileImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.demo_unavailable_title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.demo_unavailable_title,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.demo_unavailable_body,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.demo_strip_exit),
                    onPressed: () => confirmAndExitDemo(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
