import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compartment_group.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('groups compartments 1-5, 6-10 and 11-16 (issue #4503)', () {
    expect(
      [for (var n = 1; n <= 16; n++) CompartmentGroup.ofNumber(n)],
      [
        ...List.filled(5, CompartmentGroup.fast),
        ...List.filled(5, CompartmentGroup.medium),
        ...List.filled(6, CompartmentGroup.slow),
      ],
    );
  });

  testWidgets('labels each group in English', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(CompartmentGroup.fast.label(l10n), 'Fast, blood-rich tissue');
    expect(CompartmentGroup.medium.label(l10n), 'Medium, muscle and skin');
    expect(CompartmentGroup.slow.label(l10n), 'Slow, fat and bone');
  });
}
