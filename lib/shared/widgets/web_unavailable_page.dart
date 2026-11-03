import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/web_unavailable_routes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown in place of a screen a browser cannot serve: the feature exists in
/// the app, and this says why a web page cannot offer it.
class WebUnavailablePage extends StatelessWidget {
  const WebUnavailablePage({super.key, required this.feature});

  final WebUnavailableFeature feature;

  /// The feature named in a `?feature=` query, defaulting to dive computers.
  static WebUnavailableFeature featureFromQuery(String? name) =>
      WebUnavailableFeature.values.where((f) => f.name == name).firstOrNull ??
      WebUnavailableFeature.diveComputers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reason = switch (feature.reason) {
      WebUnavailableReason.hardware => l10n.web_unavailable_reason_hardware,
      WebUnavailableReason.background => l10n.web_unavailable_reason_background,
      WebUnavailableReason.files => l10n.web_unavailable_reason_files,
      WebUnavailableReason.icloud => l10n.web_unavailable_reason_icloud,
      WebUnavailableReason.git => l10n.web_unavailable_reason_git,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.web_unavailable_title)),
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
                    Icons.web_asset_off_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.web_unavailable_title,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/dashboard'),
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
