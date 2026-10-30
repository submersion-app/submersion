import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_mnd_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';

/// [TankMndField] is the one MND input the dive log's tank card and the
/// saved-cylinder card share (issue #3660), so the two cannot work out a
/// different He for the same MND.
void main() {
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  /// The mix the host holds, updated from every reported He, as both
  /// editors do.
  late GasMix current;
  late List<double> reported;

  Widget host({
    required GasMix gas,
    UnitFormatter units = metric,
    GlobalKey<FormState>? formKey,
  }) {
    current = gas;
    reported = [];
    return testApp(
      locale: const Locale('en'),
      child: Form(
        key: formKey,
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              // Shown only for a mix with helium, as both editors do.
              if (current.he > 0)
                TankMndField(
                  gas: current,
                  units: units,
                  onHeChanged: (he) => setState(() {
                    reported.add(he);
                    current = GasMix(o2: current.o2, he: he);
                  }),
                ),
              // Changes the mix from outside the field, as the O2 and He
              // fields or a gas chip do.
              TextButton(
                onPressed: () =>
                    setState(() => current = const GasMix(o2: 21, he: 35)),
                child: const Text('outside'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final field = find.byType(TankMndField);

  String textOf(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      )
      .controller!
      .text;

  testWidgets('labels itself from the ARB files', (tester) async {
    await tester.pumpWidget(host(gas: const GasMix(o2: 18, he: 45)));
    await tester.pumpAndSettle();

    final label = lookupAppLocalizations(
      const Locale('en'),
    ).diveLog_tank_label_mnd;
    final decoration = tester
        .widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        )
        .decoration!;
    expect(decoration.labelText, label);
    expect(find.text(label), findsOneWidget);
  });

  group('shows the mix MND', () {
    testWidgets('in metres, to a whole metre', (tester) async {
      // 18/45 at a 30 m END: 4 bar / 0.55 narcotic = 62.7 m.
      await tester.pumpWidget(host(gas: const GasMix(o2: 18, he: 45)));
      await tester.pumpAndSettle();

      expect(textOf(tester), '63');
      expect(find.text('m'), findsOneWidget);
    });

    testWidgets('in feet, to a whole foot', (tester) async {
      // 62.7 m is 205.8 ft.
      await tester.pumpWidget(
        host(gas: const GasMix(o2: 18, he: 45), units: imperial),
      );
      await tester.pumpAndSettle();

      expect(textOf(tester), '206');
      expect(find.text('ft'), findsOneWidget);
    });

    testWidgets('follows a mix changed from outside the field', (tester) async {
      await tester.pumpWidget(host(gas: const GasMix(o2: 18, he: 45)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('outside'));
      await tester.pumpAndSettle();

      // 21/35: 4 bar / 0.65 = 51.5 m.
      expect(textOf(tester), '52');
    });
  });

  group('typing an MND', () {
    testWidgets('reports the He for it, to a whole percent', (tester) async {
      await tester.pumpWidget(host(gas: const GasMix(o2: 21, he: 10)));
      await tester.pumpAndSettle();

      // 40 m is 5 bar; a 30 m END is 4 bar, so 20% He.
      await tester.enterText(field, '40');
      await tester.pumpAndSettle();

      expect(reported, [20]);
      expect(current, const GasMix(o2: 21, he: 20));
    });

    testWidgets('reads feet in a feet unit', (tester) async {
      await tester.pumpWidget(
        host(gas: const GasMix(o2: 21, he: 10), units: imperial),
      );
      await tester.pumpAndSettle();

      // 131 ft is 39.9 m: 19.9% He, so 20.
      await tester.enterText(field, '131');
      await tester.pumpAndSettle();

      expect(reported, [20]);
    });

    testWidgets('uses the diver END limit', (tester) async {
      await tester.pumpWidget(
        host(
          gas: const GasMix(o2: 21, he: 10),
          units: const UnitFormatter(AppSettings(endLimit: 20)),
        ),
      );
      await tester.pumpAndSettle();

      // A 20 m END is 3 bar: 1 - 3/5 = 40% He.
      await tester.enterText(field, '40');
      await tester.pumpAndSettle();

      expect(reported, [40]);
    });

    testWidgets('uses the diver O2-narcotic setting', (tester) async {
      await tester.pumpWidget(
        host(
          gas: const GasMix(o2: 21, he: 10),
          units: const UnitFormatter(AppSettings(o2Narcotic: false)),
        ),
      );
      await tester.pumpAndSettle();

      // Only N2 narcotic: 79 - 4 x 0.7902 / 5 = 15.8% He, so 16.
      await tester.enterText(field, '40');
      await tester.pumpAndSettle();

      expect(reported, [16]);
    });

    testWidgets('keeps what was typed until the diver leaves the field, then '
        'shows the MND the rounded He gives', (tester) async {
      await tester.pumpWidget(host(gas: const GasMix(o2: 21, he: 10)));
      await tester.pumpAndSettle();

      // 40.4 m gives 20.6% He, rounded to 21: an MND of 40.6 m.
      await tester.enterText(field, '40.4');
      await tester.pumpAndSettle();

      expect(reported, [21]);
      expect(textOf(tester), '40.4');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(textOf(tester), '41');
    });

    testWidgets('a mix changed elsewhere while the field still has focus '
        'shows at once', (tester) async {
      await tester.pumpWidget(host(gas: const GasMix(o2: 21, he: 10)));
      await tester.pumpAndSettle();

      await tester.enterText(field, '40');
      await tester.pumpAndSettle();

      // A touch tap elsewhere, such as a gas chip, leaves the field focused.
      await tester.tap(find.text('outside'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      // 21/35: 51.5 m.
      expect(textOf(tester), '52');
    });

    testWidgets('an unreadable MND says why, reports nothing and does not '
        'block the form', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(gas: const GasMix(o2: 21, he: 35), formKey: formKey),
      );
      await tester.pumpAndSettle();

      await tester.enterText(field, '1..2');
      await tester.pump();

      expect(find.textContaining('Enter a valid number'), findsOneWidget);
      expect(reported, isEmpty);
      expect(formKey.currentState!.validate(), isTrue);

      // Leaving the box puts back the MND the mix really has.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(find.textContaining('Enter a valid number'), findsNothing);
      expect(textOf(tester), '52');
    });

    testWidgets('an MND no deeper than the END limit reports nothing, so a '
        'host that shows the field only for a mix with helium keeps it while '
        'the diver types', (tester) async {
      await tester.pumpWidget(host(gas: const GasMix(o2: 21, he: 35)));
      await tester.pumpAndSettle();

      // The first key of "40": 4 m needs no helium at a 30 m END.
      await tester.enterText(field, '4');
      await tester.pumpAndSettle();
      expect(reported, isEmpty);
      expect(field, findsOneWidget);

      await tester.enterText(field, '40');
      await tester.pumpAndSettle();
      expect(reported, [20]);
    });

    testWidgets('zero reports nothing', (tester) async {
      await tester.pumpWidget(host(gas: const GasMix(o2: 21, he: 35)));
      await tester.pumpAndSettle();

      await tester.enterText(field, '0');
      await tester.pumpAndSettle();

      expect(reported, isEmpty);
    });
  });
}
