import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_delete_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Deleting a device's Equipment item deletes the device too (issue #3676),
/// and the confirmation says what goes with it.
void main() {
  Future<bool?> open(WidgetTester tester, EquipmentType type) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await confirmEquipmentDelete(context, type),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the delete dialog for a computer item says the download '
      'history goes too', (tester) async {
    await open(tester, EquipmentType.computer);
    expect(find.textContaining('download history'), findsOneWidget);
  });

  testWidgets('the delete dialog for a transmitter item suggests Retired', (
    tester,
  ) async {
    await open(tester, EquipmentType.transmitter);
    expect(find.textContaining('Retired'), findsOneWidget);
  });

  testWidgets('other gear keeps the plain confirmation', (tester) async {
    await open(tester, EquipmentType.mask);
    expect(
      find.text(
        'Are you sure you want to delete this equipment? This action cannot '
        'be undone.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('confirming returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmEquipmentDelete(
              context,
              EquipmentType.computer,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  group('bulkDeleteBody (review)', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('a selection with a device says the device goes too', () {
      final body = bulkDeleteBody(l10n, [
        EquipmentType.mask,
        EquipmentType.computer,
      ]);
      expect(body, startsWith(l10n.common_bulkDelete_body));
      expect(body, contains('download history'));
    });

    test('a selection with a transmitter says so too', () {
      expect(
        bulkDeleteBody(l10n, [EquipmentType.transmitter]),
        contains('download history'),
      );
    });

    test('other gear keeps the plain body', () {
      expect(
        bulkDeleteBody(l10n, [EquipmentType.mask, EquipmentType.fins]),
        l10n.common_bulkDelete_body,
      );
    });
  });
}
