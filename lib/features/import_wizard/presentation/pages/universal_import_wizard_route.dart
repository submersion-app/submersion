import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';

/// The file import wizard, with a [UniversalAdapter] built from Riverpod.
///
/// Public so both the router's `/transfer/import-wizard` route and the
/// import wizard nav shortcut (#2936) build the same page.
class UniversalImportWizardRoute extends ConsumerWidget {
  const UniversalImportWizardRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedImportWizard(adapter: UniversalAdapter(ref: ref));
  }
}
