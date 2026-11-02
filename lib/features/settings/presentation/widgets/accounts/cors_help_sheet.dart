import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/platform/web/cors_diagnoser.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows why a browser's connection test failed and, where a CORS rule
/// fixes it, the rule to add with the site's address filled in
/// (issue #4121).
Future<void> showCorsHelpSheet(BuildContext context, CorsDiagnosis diagnosis) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CorsHelpSheet(diagnosis: diagnosis),
    );

/// The verdict's title.
String corsVerdictTitle(AppLocalizations l10n, CorsVerdict verdict) =>
    switch (verdict) {
      CorsVerdict.blockedByCors => l10n.web_cors_title_blockedByCors,
      CorsVerdict.methodBlockedByCors =>
        l10n.web_cors_title_methodBlockedByCors,
      CorsVerdict.writeBlockedByCors => l10n.web_cors_title_writeBlockedByCors,
      CorsVerdict.forbidden => l10n.web_cors_title_forbidden,
      CorsVerdict.notFound => l10n.web_cors_title_notFound,
      CorsVerdict.tlsOrUnreachable => l10n.web_cors_title_tlsOrUnreachable,
      CorsVerdict.ok => l10n.web_cors_title_ok,
      CorsVerdict.unknown => l10n.web_cors_title_unknown,
    };

/// The verdict's one-paragraph explanation.
String corsVerdictExplanation(
  AppLocalizations l10n,
  CorsVerdict verdict,
) => switch (verdict) {
  CorsVerdict.blockedByCors => l10n.web_cors_explain_blockedByCors,
  CorsVerdict.methodBlockedByCors => l10n.web_cors_explain_methodBlockedByCors,
  CorsVerdict.writeBlockedByCors => l10n.web_cors_explain_writeBlockedByCors,
  CorsVerdict.forbidden => l10n.web_cors_explain_forbidden,
  CorsVerdict.notFound => l10n.web_cors_explain_notFound,
  CorsVerdict.tlsOrUnreachable => l10n.web_cors_explain_tlsOrUnreachable,
  CorsVerdict.ok => l10n.web_cors_explain_ok,
  CorsVerdict.unknown => l10n.web_cors_explain_unknown,
};

class CorsHelpSheet extends StatelessWidget {
  const CorsHelpSheet({super.key, required this.diagnosis});

  final CorsDiagnosis diagnosis;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.l10n.web_cors_copied;
    await Clipboard.setData(ClipboardData(text: diagnosis.ruleTemplate));
    messenger?.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              corsVerdictTitle(l10n, diagnosis.verdict),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(corsVerdictExplanation(l10n, diagnosis.verdict)),
            if (diagnosis.needsRule) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  diagnosis.ruleTemplate.trimRight(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Courier New'],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.web_cors_copyRule),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
