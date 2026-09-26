import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/settings/presentation/widgets/gtr_reserve_dialog.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<List<double?>> open(WidgetTester tester) async {
    final results = <double?>[];
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => results.add(
                await showDialog<double>(
                  context: context,
                  builder: (_) => const GtrReserveDialog(
                    initialValue: 50,
                    unitSymbol: 'bar',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('saving an unreadable reserve keeps the dialog open and says '
      'why (#1900)', (tester) async {
    Intl.defaultLocale = 'en_US';
    final results = await open(tester);

    await tester.enterText(find.byType(TextField), '5..0');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(GtrReserveDialog), findsOneWidget);
    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(results, isEmpty, reason: 'used to close with nothing saved');
  });

  testWidgets('a readable reserve is returned', (tester) async {
    Intl.defaultLocale = 'en_US';
    final results = await open(tester);

    await tester.enterText(find.byType(TextField), '60');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(results, [60]);
  });
}
