import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_info_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../support/clipboard_recorder.dart';

void main() {
  testWidgets('only the serial number offers to be copied (issue #3362)', (
    tester,
  ) async {
    final calls = recordClipboardCalls();
    final computer = DiveComputer(
      id: 'computer-1',
      name: 'Perdix',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      serialNumber: 'A7X-20419',
      firmwareVersion: 'V95',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveComputerInfoCard(computer: computer, icon: Icons.watch),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Copy'), findsOneWidget);

    await tester.longPress(find.text('A7X-20419'));
    await tester.pump();

    expect(copiedText(calls), 'A7X-20419');
  });
}
