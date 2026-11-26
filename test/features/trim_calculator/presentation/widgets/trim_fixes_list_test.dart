import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trim_calculator/domain/trim_fixes.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_fixes_list.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_strings.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/test_app.dart';

/// "What would level you" in words (spec section 14 B).
void main() {
  final l10n = AppLocalizationsEn();
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(weightUnit: WeightUnit.pounds, depthUnit: DepthUnit.feet),
  );
  const level = TrimResult(pitchKgM: 0, rollKgM: 0, balancingLiftKg: 0);

  TrimFix fix(
    TrimFixKind kind, {
    double? kg,
    double? metres,
    TrimSpot? from,
    TrimSpot? to,
    TrimLateral? side,
  }) => TrimFix(
    kind: kind,
    result: level,
    kg: kg,
    metres: metres,
    from: from,
    to: to,
    fromSide: side,
  );

  test('less lead, in kilograms or whole pounds', () {
    expect(
      trimFixText(fix(TrimFixKind.lessLead, kg: 1.5), metric, l10n),
      'Carry 1.5 kg less lead',
    );
    expect(
      trimFixText(
        fix(TrimFixKind.lessLead, kg: 3 * kTrimPoundKg),
        imperial,
        l10n,
      ),
      'Carry 3 lbs less lead',
    );
  });

  test('tank height, up or down the band, in cm or inches', () {
    expect(
      trimFixText(fix(TrimFixKind.tankHeight, metres: -0.05), metric, l10n),
      'Slide the tank 5 cm up the band',
    );
    expect(
      trimFixText(fix(TrimFixKind.tankHeight, metres: 0.0508), imperial, l10n),
      'Slide the tank 2 in down the band',
    );
  });

  test('moving lead names where from and where to', () {
    expect(
      trimFixText(
        fix(
          TrimFixKind.moveLead,
          kg: 1,
          from: TrimSpot.waist,
          to: TrimSpot.trimPockets,
        ),
        metric,
        l10n,
      ),
      'Move 1 kg of lead from Waist to Trim pockets',
    );
    expect(
      trimFixText(
        fix(TrimFixKind.moveAcross, kg: 1.5, side: TrimLateral.left),
        metric,
        l10n,
      ),
      'Move 1.5 kg of lead from your left side to your right',
    );
  });

  testWidgets('lists each fix with the verdict it leads to', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TrimFixesList(
          fixes: [fix(TrimFixKind.lighterFins)],
          units: metric,
        ),
      ),
    );
    expect(find.text('What would level you'), findsOneWidget);
    expect(
      find.text('Lighter fins, near neutral in the water'),
      findsOneWidget,
    );
    expect(find.text('Then: Level'), findsOneWidget);
  });

  testWidgets('nothing to fix, nothing shown', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: const TrimFixesList(fixes: [], units: metric),
      ),
    );
    expect(find.text('What would level you'), findsNothing);
  });
}
