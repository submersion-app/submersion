import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _field({
  String? hex,
  ValueChanged<String>? onChanged,
  VoidCallback? onCleared,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: EquipmentColorField(
      label: 'Color',
      hex: hex,
      onChanged: onChanged ?? (_) {},
      onCleared: onCleared ?? () {},
    ),
  ),
);

void main() {
  testWidgets('unset shows the placeholder and no clear button', (
    tester,
  ) async {
    await tester.pumpWidget(_field());
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('a value that is not a colour reads as unset', (tester) async {
    await tester.pumpWidget(_field(hex: 'Red'));
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('a palette colour shows its name and swatch', (tester) async {
    await tester.pumpWidget(_field(hex: '#EF4444'));
    expect(find.text('Red'), findsOneWidget);
    expect(find.byKey(const ValueKey('color-field-swatch')), findsOneWidget);
  });

  testWidgets('a colour outside the palette shows its code', (tester) async {
    await tester.pumpWidget(_field(hex: '#123456'));
    expect(find.text('#123456'), findsOneWidget);
  });

  testWidgets('picking a colour reports it', (tester) async {
    String? picked;
    await tester.pumpWidget(_field(onChanged: (hex) => picked = hex));
    await tester.tap(find.byType(EquipmentColorField));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-#22C55E')));
    await tester.pumpAndSettle();
    expect(picked, '#22C55E');
  });

  testWidgets('None in the sheet clears', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      _field(hex: '#EF4444', onCleared: () => cleared = true),
    );
    await tester.tap(find.text('Red'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-none')));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
  });

  testWidgets('the clear button clears without opening the sheet', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      _field(hex: '#EF4444', onCleared: () => cleared = true),
    );
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('Choose a color'), findsNothing);
  });
}
