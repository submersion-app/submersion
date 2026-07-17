import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Create/edit page for a pre-dive checklist template.
/// Stub: replaced with the full editor in the template-editor task.
class PreDiveTemplateEditPage extends ConsumerStatefulWidget {
  final String? templateId;

  const PreDiveTemplateEditPage({super.key, this.templateId});

  bool get isEditing => templateId != null;

  @override
  ConsumerState<PreDiveTemplateEditPage> createState() =>
      _PreDiveTemplateEditPageState();
}

class _PreDiveTemplateEditPageState
    extends ConsumerState<PreDiveTemplateEditPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.preDive_templates_title)),
      body: const SizedBox.shrink(),
    );
  }
}
