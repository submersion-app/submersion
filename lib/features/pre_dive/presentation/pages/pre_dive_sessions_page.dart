import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pre-dive checklist sessions list (active run pinned, then history).
/// Stub: replaced with the full page in the session-runner task.
class PreDiveSessionsPage extends ConsumerWidget {
  const PreDiveSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.preDive_templates_title)),
      body: const SizedBox.shrink(),
    );
  }
}
