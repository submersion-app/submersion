import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  DiveTypeEntity type(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Widget harness({
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    return ProviderScope(
      overrides: [
        diveTypesProvider.overrideWith(
          (ref) async => [
            type('shore', 'Shore'),
            type('wreck', 'Wreck'),
            type('night', 'Night'),
          ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiveTypeMultiSelectField(
            selectedTypeIds: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('renders a chip per selected type', (tester) async {
    await tester.pumpWidget(harness(selected: ['shore'], onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Shore'), findsOneWidget);
  });

  testWidgets('toggling a type in the dropdown fires onChanged', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(selected: ['shore'], onChanged: (v) => result = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first); // open the dropdown
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxMenuButton, 'Wreck'),
    ); // check Wreck
    await tester.pumpAndSettle();

    expect(result, ['shore', 'wreck']);
  });

  testWidgets('cannot uncheck the last remaining type (>= 1)', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(selected: ['shore'], onChanged: (v) => result = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxMenuButton, 'Shore'),
    ); // try to uncheck the only type
    await tester.pumpAndSettle();

    expect(result, isNull); // the uncheck was ignored
  });
}
