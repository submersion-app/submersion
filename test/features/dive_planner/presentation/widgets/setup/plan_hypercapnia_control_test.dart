import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_hypercapnia_control.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Records every callback [PlanHypercapniaControl] fires.
class _Calls {
  final amv = <double>[];
  final minutes = <int>[];
  final off = <bool>[];
  var defaults = 0;
}

PlanHypercapniaControl _control(
  _Calls calls, {
  double? amv,
  int? minutes,
  bool explicitlyOff = false,
  bool enabledInSettings = true,
}) => PlanHypercapniaControl(
  amv: amv,
  minutes: minutes,
  explicitlyOff: explicitlyOff,
  defaultAmv: 80,
  defaultMinutes: 5,
  enabledInSettings: enabledInSettings,
  units: const UnitFormatter(AppSettings()),
  onAmvChanged: calls.amv.add,
  onMinutesChanged: calls.minutes.add,
  onOff: calls.off.add,
  onDefault: () => calls.defaults++,
);

/// The Default/Off/Custom control for a plan's hypercapnia-bailout phase
/// (issue #3743).
void main() {
  group('PlanHypercapniaControl', () {
    testWidgets('Default shows the Settings rate and duration as text', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_control(_Calls())));
      await tester.pumpAndSettle();

      expect(find.textContaining('80.0 L/min'), findsOneWidget);
      expect(find.textContaining('5 min'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Default reads Off when the Settings toggle is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_control(_Calls(), enabledInSettings: false)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('L/min'), findsNothing);
      // The Off chip plus the Default state's own "Off" line.
      expect(find.text('Off'), findsNWidgets(2));
    });

    testWidgets('choosing Custom clears Off and seeds both values from the '
        'defaults', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_app(_control(calls, explicitlyOff: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
      await tester.pumpAndSettle();

      expect(calls.off, [false]);
      expect(calls.amv, [80]);
      expect(calls.minutes, [5]);
    });

    testWidgets('choosing Off and Default fire their own callbacks', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(_app(_control(calls, amv: 90, minutes: 3)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Off'));
      await tester.pumpAndSettle();
      expect(calls.off, [true]);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Default'));
      await tester.pumpAndSettle();
      expect(calls.defaults, 1);
    });

    testWidgets('Custom shows editable rate and duration fields', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_control(_Calls(), amv: 90, minutes: 3)));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
    });
  });
}
