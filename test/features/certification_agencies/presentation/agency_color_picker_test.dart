import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/agency_color_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Copilot review on PR #3011: a screen reader names every card colour.
void main() {
  testWidgets('each swatch is labelled with its colour name', (tester) async {
    final handle = tester.ensureSemantics();
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgencyColorPicker(
            selectedArgb: 0xFFEF4444,
            onSelected: (argb) => picked = argb,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Red')),
      matchesSemantics(
        label: 'Red',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Slate'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Blue'));
    expect(picked, 0xFF3B82F6);
    handle.dispose();
  });
}
