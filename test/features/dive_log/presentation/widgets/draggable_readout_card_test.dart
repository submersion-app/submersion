import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _cardKey = ValueKey('readout-card');

Widget _wrap({
  List<TooltipRow>? rows,
  Offset? initialFraction,
  ValueChanged<Offset>? onDragEnd,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          key: const ValueKey('arena'),
          width: 600,
          height: 400,
          child: Stack(
            children: [
              DraggableReadoutCard(
                rows: rows,
                initialFraction: initialFraction,
                onDragEnd: onDragEnd ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the localized hint before any rows arrive', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(rows: null));
    await tester.pumpAndSettle();

    expect(find.text('Hover or scrub the profile'), findsOneWidget);
  });

  testWidgets('renders rows with label and value, hint gone', (tester) async {
    await tester.pumpWidget(
      _wrap(
        rows: const [
          TooltipRow(label: 'Depth', value: '18.2 m', bulletColor: Colors.blue),
          TooltipRow(label: 'Temp', value: '22 C', bulletColor: Colors.red),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hover or scrub the profile'), findsNothing);
    expect(find.text('Depth'), findsOneWidget);
    expect(find.text('18.2 m'), findsOneWidget);
    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('defaults to the top-right corner', (tester) async {
    await tester.pumpWidget(_wrap(rows: null));
    await tester.pumpAndSettle();

    final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
    final cardRect = tester.getRect(find.byKey(_cardKey));
    // Right edge inset by the 12px padding; top edge likewise.
    expect(cardRect.right, closeTo(stackRect.right - 12, 1.0));
    expect(cardRect.top, closeTo(stackRect.top + 12, 1.0));
  });

  testWidgets('an out-of-range initial fraction is clamped into view', (
    tester,
  ) async {
    // Simulates corrupted/out-of-contract persisted values: the card must
    // still land inside the bounds (Stack clips, so an off-range card would
    // be invisible and undraggable forever).
    await tester.pumpWidget(
      _wrap(rows: null, initialFraction: const Offset(5, -3)),
    );
    await tester.pumpAndSettle();

    final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
    final cardRect = tester.getRect(find.byKey(_cardKey));
    // Clamped to (1, 0): flush to the inset top-right corner.
    expect(cardRect.right, closeTo(stackRect.right - 12, 1.0));
    expect(cardRect.top, closeTo(stackRect.top + 12, 1.0));
  });

  testWidgets('a non-finite initial fraction falls back to the default '
      'corner', (tester) async {
    // NaN survives double.clamp (NaN.clamp(0,1) is NaN) and would reach
    // FractionalOffset as invalid layout input; the card must fall back to
    // the default corner instead.
    await tester.pumpWidget(
      _wrap(rows: null, initialFraction: const Offset(double.nan, double.nan)),
    );
    await tester.pumpAndSettle();

    final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
    final cardRect = tester.getRect(find.byKey(_cardKey));
    expect(cardRect.right, closeTo(stackRect.right - 12, 1.0));
    expect(cardRect.top, closeTo(stackRect.top + 12, 1.0));
  });

  testWidgets('dragging moves the card and clamps at the bounds', (
    tester,
  ) async {
    Offset? lastFraction;
    await tester.pumpWidget(
      _wrap(rows: null, onDragEnd: (f) => lastFraction = f),
    );
    await tester.pumpAndSettle();

    // Drag far past the top-left corner: must clamp to fraction (0,0).
    await tester.drag(find.byKey(_cardKey), const Offset(-2000, -2000));
    await tester.pumpAndSettle();

    final stackRect = tester.getRect(find.byKey(const ValueKey('arena')));
    final cardRect = tester.getRect(find.byKey(_cardKey));
    expect(cardRect.left, closeTo(stackRect.left + 12, 1.0));
    expect(cardRect.top, closeTo(stackRect.top + 12, 1.0));
    expect(lastFraction, const Offset(0, 0));
  });

  testWidgets('a partial drag reports an interior fraction', (tester) async {
    Offset? lastFraction;
    await tester.pumpWidget(
      _wrap(
        rows: null,
        initialFraction: const Offset(0, 0),
        onDragEnd: (f) => lastFraction = f,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(_cardKey), const Offset(80, 60));
    await tester.pumpAndSettle();

    expect(lastFraction, isNotNull);
    expect(lastFraction!.dx, greaterThan(0));
    expect(lastFraction!.dx, lessThan(1));
    expect(lastFraction!.dy, greaterThan(0));
    expect(lastFraction!.dy, lessThan(1));
  });
}
