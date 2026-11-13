import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';

/// The file import wizard, with a [UniversalAdapter] built from Riverpod.
///
/// Public so both the router's `/transfer/import-wizard` route and the
/// import wizard nav shortcut (#2936) build the same page.
class UniversalImportWizardRoute extends ConsumerWidget {
  const UniversalImportWizardRoute({
    super.key,
    this.startGarminDeviceImport = false,
  });

  /// The `source` query value that opens the wizard straight into the
  /// Garmin device import (issue #4223).
  static const garminDeviceSource = 'garmin-device';

  /// Where Connect New Computer's Garmin entry and a saved Garmin's download
  /// screen send the diver.
  static const garminDeviceImportLocation =
      '/transfer/import-wizard?source=$garminDeviceSource';

  final bool startGarminDeviceImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnifiedImportWizard(
      adapter: UniversalAdapter(
        ref: ref,
        startGarminDeviceImport: startGarminDeviceImport,
      ),
    );
  }
}
