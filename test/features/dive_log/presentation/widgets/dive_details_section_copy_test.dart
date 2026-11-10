import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../support/clipboard_recorder.dart';

void main() {
  final dive = createTestDiveWithBottomTime().copyWith(
    diveComputerModel: 'Perdix 2',
    diveComputerSerial: 'A7X-20419',
  );

  Future<void> pumpSection(
    WidgetTester tester,
    Dive dive,
    List<DiveComputer> computers,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          computersForDiveProvider(
            dive.id,
          ).overrideWith((ref) async => computers),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: DiveDetailsSection(dive: dive)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the dive computer serial can be copied (issue #3362)', (
    tester,
  ) async {
    final calls = recordClipboardCalls();
    await pumpSection(tester, dive, const []);

    expect(find.byTooltip('Copy'), findsOneWidget);

    await tester.longPress(find.text('A7X-20419'));
    await tester.pump();

    expect(copiedText(calls), 'A7X-20419');
  });

  testWidgets('a linked computer leaves copying to its own page', (
    tester,
  ) async {
    await pumpSection(tester, dive, [
      DiveComputer(
        id: 'computer-1',
        name: 'Perdix',
        serialNumber: 'A7X-20419',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);

    expect(find.textContaining('A7X-20419'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing);
  });

  Future<void> openDetailsInfo(WidgetTester tester, Dive dive) async {
    await pumpSection(tester, dive, const []);
    await tester.tap(find.byTooltip('About Details'));
    await tester.pumpAndSettle();
  }

  testWidgets('the info sheet names gradient factors when both show', (
    tester,
  ) async {
    await openDetailsInfo(
      tester,
      createTestDiveWithBottomTime().copyWith(
        gradientFactorLow: 30,
        gradientFactorHigh: 70,
      ),
    );

    expect(find.textContaining('GF (gradient factors)'), findsOneWidget);
  });

  testWidgets('the info sheet leaves gradient factors out with one missing', (
    tester,
  ) async {
    final lowOnly = createTestDiveWithBottomTime().copyWith(
      gradientFactorLow: 30,
    );
    expect(lowOnly.gradientFactorHigh, isNull);
    await openDetailsInfo(tester, lowOnly);

    expect(find.textContaining('GF (gradient factors)'), findsNothing);
  });
}
