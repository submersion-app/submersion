import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/presentation/widgets/tank_mod_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';

import '../../../../helpers/test_app.dart';

/// The MOD field shared by the saved-cylinder card and the planner's tank
/// dialog (issue #3567): the default for the cylinder's role, or a depth the
/// diver typed, with the ppO2 that depth means.
void main() {
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
  const ean50 = GasMix(o2: 50);
  const ean40 = GasMix(o2: 40);

  late double? reported;
  late int reports;

  Widget host({
    GasMix gas = ean50,
    TankRole role = TankRole.deco,
    double? override,
    UnitFormatter units = metric,
    double diluentPpO2 = 1.6,
  }) {
    reported = override;
    reports = 0;
    return testApp(
      locale: const Locale('en'),
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: TankModField(
            gas: gas,
            role: role,
            overrideMeters: reported,
            bottomPpO2: 1.4,
            decoPpO2: 1.6,
            diluentPpO2: diluentPpO2,
            units: units,
            onChanged: (value) => setState(() {
              reported = value;
              reports++;
            }),
          ),
        ),
      ),
    );
  }

  Finder field() => find.byKey(TankModField.fieldKey);

  String fieldText(WidgetTester tester) =>
      tester.widget<NumberField>(field()).controller.text;

  testWidgets('shows the default for the role, and where it comes from', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('MOD'), findsOneWidget);
    expect(fieldText(tester), '22');
    expect(find.text('Default at ppO2 1.6 (deco limit)'), findsOneWidget);
    expect(find.byKey(TankModField.resetKey), findsNothing);
  });

  testWidgets('a stage uses the bottom limit', (tester) async {
    await tester.pumpWidget(host(gas: ean40, role: TankRole.stage));
    await tester.pumpAndSettle();

    expect(fieldText(tester), '25');
    expect(find.text('Default at ppO2 1.4 (bottom limit)'), findsOneWidget);
  });

  testWidgets('a diluent uses the CCR Dil MOD limit, not the bottom limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(gas: ean40, role: TankRole.diluent, diluentPpO2: 1.6),
    );
    await tester.pumpAndSettle();

    expect(fieldText(tester), '30');
    expect(find.text('Default at ppO2 1.6 (Dil MOD)'), findsOneWidget);
  });

  testWidgets('typing a depth sets the override', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(field(), '18');
    await tester.pumpAndSettle();

    expect(reported, 18);
    expect(find.text('Set by you · default 22m'), findsOneWidget);
    expect(find.text('ppO2 1.40 at 18m'), findsOneWidget);
    expect(find.byKey(TankModField.resetKey), findsOneWidget);
  });

  testWidgets('Reset goes back to the default', (tester) async {
    await tester.pumpWidget(host(override: 18));
    await tester.pumpAndSettle();
    expect(fieldText(tester), '18');

    await tester.tap(find.byKey(TankModField.resetKey));
    await tester.pumpAndSettle();

    expect(reported, isNull);
    expect(fieldText(tester), '22');
  });

  testWidgets('clearing the field goes back to the default', (tester) async {
    await tester.pumpWidget(host(override: 18));
    await tester.pumpAndSettle();

    await tester.enterText(field(), '');
    await tester.pumpAndSettle();

    expect(reported, isNull);
  });

  testWidgets('a half-typed number changes nothing', (tester) async {
    await tester.pumpWidget(host(override: 18));
    await tester.pumpAndSettle();

    await tester.enterText(field(), '.');
    await tester.pumpAndSettle();

    expect(reported, 18);
  });

  testWidgets('a MOD under one unit is refused, not stored', (tester) async {
    await tester.pumpWidget(host(override: 18));
    await tester.pumpAndSettle();

    await tester.enterText(field(), '0');
    await tester.pumpAndSettle();

    expect(reported, 18);
    expect(find.text('Enter 1 or more'), findsOneWidget);
  });

  testWidgets('unreadable text makes an enclosing form refuse to save', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Form(
          key: formKey,
          child: TankModField(
            gas: ean50,
            role: TankRole.deco,
            overrideMeters: 18,
            bottomPpO2: 1.4,
            decoPpO2: 1.6,
            diluentPpO2: 1.6,
            units: metric,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(formKey.currentState!.validate(), isTrue);

    await tester.enterText(field(), '1.2.');
    await tester.pumpAndSettle();

    expect(formKey.currentState!.validate(), isFalse);
  });

  testWidgets('an override deeper than the limit is flagged in red', (
    tester,
  ) async {
    await tester.pumpWidget(host(override: 24));
    await tester.pumpAndSettle();

    final warning = find.text('ppO2 1.70 at 24m, above the deco limit 1.6');
    expect(warning, findsOneWidget);
    final context = tester.element(warning);
    expect(
      tester.widget<Text>(warning).style?.color,
      Theme.of(context).colorScheme.error,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('a shallower override is not flagged', (tester) async {
    await tester.pumpWidget(host(override: 18));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('without an override, the default follows the mix', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(fieldText(tester), '22');

    await tester.pumpWidget(host(gas: ean40));
    await tester.pumpAndSettle();
    expect(fieldText(tester), '30');
    expect(reports, 0, reason: 'a default is never written back');
  });

  testWidgets('an override stays put when the mix changes', (tester) async {
    await tester.pumpWidget(host(override: 21));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(gas: ean40, override: 21));
    await tester.pumpAndSettle();

    expect(fieldText(tester), '21');
    expect(find.text('ppO2 1.24 at 21m'), findsOneWidget);
  });

  testWidgets('reads and writes the diver depth unit', (tester) async {
    await tester.pumpWidget(host(units: imperial));
    await tester.pumpAndSettle();

    // 22 m is 72.18 ft, floored so the shown MOD is never deeper.
    expect(fieldText(tester), '72');

    await tester.enterText(field(), '60');
    await tester.pumpAndSettle();

    // The app converts feet at 3.28084 per metre, a hair off 0.3048.
    expect(reported, closeTo(18.288, 1e-5));
    // 60 ft is 18.29 m: 0.50 x 2.829 bar.
    expect(find.text('ppO2 1.41 at 60ft'), findsOneWidget);
  });
}
