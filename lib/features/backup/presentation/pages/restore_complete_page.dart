import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/root_overlay_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show restartApp;

class RestoreCompletePage extends StatelessWidget {
  const RestoreCompletePage({super.key});

  /// Navigate to this page using the root Navigator (not GoRouter).
  /// This ensures the page survives the ProviderScope rebuild.
  ///
  /// Marks [rootOverlayActiveProvider] active first (issue #3361), so an
  /// `AutoConnectController` sitting underneath this root-navigator push
  /// pauses its passive scan. Not reset back on the way out: the only way
  /// off this page is [restartApp], which discards the whole container the
  /// flag and the controller both live in.
  static void show(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(rootOverlayActiveProvider.notifier).state = true;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RestoreCompletePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.backup_restoreComplete_title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.backup_restoreComplete_description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    onPressed: () => restartApp(),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.backup_restoreComplete_continue),
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
