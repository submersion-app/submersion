import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The pre-dive checklist session runner/viewer.
/// Stub: replaced with the full page in the session-runner task.
class PreDiveSessionRunnerPage extends ConsumerWidget {
  final String sessionId;

  const PreDiveSessionRunnerPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.preDive_templates_title)),
      body: const SizedBox.shrink(),
    );
  }
}
