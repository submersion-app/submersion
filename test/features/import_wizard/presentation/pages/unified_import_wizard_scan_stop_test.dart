import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/pages/unified_import_wizard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

import '../../../dive_computer/presentation/widgets/scan_step_test_support.dart';

final _canAdvance = StateProvider<bool>((_) => false);

class _DiveComputerAdapter extends Fake implements DiveComputerAdapter {
  @override
  VoidCallback? goBackFromConfirm;

  @override
  String get displayName => 'Perdix';

  @override
  void resetState() {}

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Scan',
      builder: (_) => const Text('Scan'),
      canAdvance: _canAdvance,
    ),
  ];
}

class _StopCountingNotifier extends TestDiscoveryNotifier {
  int stops = 0;

  @override
  Future<void> stopScanOwnedBy(Object? owner) async => stops++;
}

void main() {
  testWidgets('a dive computer import stops its scan as the wizard closes, '
      'not before (issue #4088)', (tester) async {
    final notifier = _StopCountingNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoveryNotifierProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UnifiedImportWizard(adapter: _DiveComputerAdapter()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(notifier.stops, 0);

    await tester.pumpWidget(const SizedBox());

    expect(notifier.stops, 1);
  });
}
