import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({DepthUnit depthUnit = DepthUnit.meters})
    : super(AppSettings(depthUnit: depthUnit));

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(PlanNumberField, label),
  matching: find.byType(TextField),
);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

bool _hasError(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).decoration?.errorText != null;

Widget _harness({
  DepthUnit depthUnit = DepthUnit.meters,
  Locale locale = const Locale('en'),
}) => testApp(
  locale: locale,
  overrides: [
    settingsProvider.overrideWith(
      (ref) => _TestSettingsNotifier(depthUnit: depthUnit),
    ),
  ],
  child: const SimplePlanDialog(),
);

void main() {
  testWidgets('quick plan takes depth and time as number boxes', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(PlanNumberField), findsNWidgets(2));
    expect(_text(tester, 'Depth:'), '18');
    expect(_text(tester, 'Time:'), '45');
    expect(find.text('m'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
  });

  testWidgets('typed depth and time reach the created plan', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SimplePlanDialog)),
    );

    await tester.enterText(_field('Depth:'), '25');
    await tester.enterText(_field('Time:'), '30');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    expect(segments.any((s) => s.targetDepth == 25), isTrue);
    expect(
      segments.any((s) => s.targetDepth == 25 && s.durationSeconds == 30 * 60),
      isTrue,
    );
  });

  testWidgets('depth box works in the diver depth unit', (tester) async {
    await tester.pumpWidget(_harness(depthUnit: DepthUnit.feet));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SimplePlanDialog)),
    );

    // 18 m seeded as whole feet.
    expect(_text(tester, 'Depth:'), '59');
    expect(find.text('ft'), findsOneWidget);

    await tester.enterText(_field('Depth:'), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    expect(
      segments.map((s) => s.targetDepth),
      contains(closeTo(100 / 3.28084, 0.01)),
    );
  });

  testWidgets('refuses a depth outside the quick-plan band', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.enterText(_field('Depth:'), '80');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(_field('Depth:')).decoration?.errorText,
      isNotNull,
    );
  });

  // A touch on a button does not take focus from a text field, so tapping
  // Create straight after typing leaves the edit uncommitted: the box is red
  // and the dialog still holds the value from before the edit.
  testWidgets('Create settles a pending out-of-range depth', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SimplePlanDialog)),
    );

    await tester.enterText(_field('Depth:'), '80');
    await tester.pumpAndSettle();
    expect(_hasError(tester, 'Depth:'), isTrue);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // The nearest legal depth, as a blur would have settled it, not the 18 m
    // the dialog held before the edit.
    final segments = container.read(divePlanNotifierProvider).segments;
    expect(segments.map((s) => s.targetDepth), contains(40));
    expect(segments.map((s) => s.targetDepth), isNot(contains(18)));
  });

  testWidgets('Create settles a pending out-of-range bottom time', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SimplePlanDialog)),
    );

    await tester.enterText(_field('Time:'), '200');
    await tester.pumpAndSettle();
    expect(_hasError(tester, 'Time:'), isTrue);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    expect(
      segments.any((s) => s.targetDepth == 18 && s.durationSeconds == 120 * 60),
      isTrue,
    );
  });

  testWidgets('imperial depth band never admits a depth outside 5-40 m', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(depthUnit: DepthUnit.feet));
    await tester.pumpAndSettle();

    // 5 m is 16.4 ft and 40 m is 131.2 ft: the whole-foot bounds narrow
    // inward to 17 and 131, so 16 ft (4.88 m) and 132 ft (40.2 m) are out.
    await tester.enterText(_field('Depth:'), '16');
    await tester.pumpAndSettle();
    expect(_hasError(tester, 'Depth:'), isTrue);

    await tester.enterText(_field('Depth:'), '17');
    await tester.pumpAndSettle();
    expect(_hasError(tester, 'Depth:'), isFalse);

    await tester.enterText(_field('Depth:'), '132');
    await tester.pumpAndSettle();
    expect(_hasError(tester, 'Depth:'), isTrue);

    await tester.enterText(_field('Depth:'), '131');
    await tester.pumpAndSettle();
    expect(_hasError(tester, 'Depth:'), isFalse);
  });

  testWidgets('the minute unit follows the app language', (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Min.'), findsOneWidget);
    expect(find.text('min'), findsNothing);
  });
}
