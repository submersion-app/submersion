import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// A card with nothing to edit fades while its record is unlocked, and says
/// why (issue #4527, plan 6).
void main() {
  late RecordEditController<String> controller;
  late int taps;

  setUp(() {
    controller = RecordEditController<String>(onSave: (_) async {});
    taps = 0;
  });
  tearDown(() => controller.dispose());

  Widget card() => SizedBox(
    key: const ValueKey('card'),
    width: 300,
    height: 120,
    child: ElevatedButton(onPressed: () => taps++, child: const Text('Read')),
  );

  Widget harness({required RecordCardFadeReason reason, bool scoped = true}) {
    final fade = RecordCardFade<String>(reason: reason, child: card());
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: scoped
              ? RecordEditScope<String>(controller: controller, child: fade)
              : fade,
        ),
      ),
    );
  }

  testWidgets('locked or without a scope: the child as it is, no label', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(reason: RecordCardFadeReason.calculated, scoped: false),
    );
    expect(find.text('Calculated'), findsNothing);
    expect(find.byType(Opacity), findsNothing);

    // Locked: one shape with the unlocked one, so unlocking never remounts
    // the card.
    await tester.pumpWidget(harness(reason: RecordCardFadeReason.calculated));
    expect(find.text('Calculated'), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('unlocked: faded, the label shows, and the size is unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(harness(reason: RecordCardFadeReason.calculated));
    final before = tester.getRect(find.byKey(const ValueKey('card')));
    final outerBefore = tester.getSize(find.byType(RecordCardFade<String>));

    controller.unlock('dive');
    await tester.pump();

    expect(find.text('Calculated'), findsOneWidget);
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, lessThan(1));
    expect(tester.getRect(find.byKey(const ValueKey('card'))), before);
    expect(tester.getSize(find.byType(RecordCardFade<String>)), outerBefore);
  });

  testWidgets('imported cards say Imported', (tester) async {
    await tester.pumpWidget(harness(reason: RecordCardFadeReason.imported));
    controller.unlock('dive');
    await tester.pump();

    expect(find.text('Imported'), findsOneWidget);
    expect(find.text('Calculated'), findsNothing);
  });

  testWidgets('a tap inside a faded card still reaches it', (tester) async {
    await tester.pumpWidget(harness(reason: RecordCardFadeReason.calculated));
    controller.unlock('dive');
    await tester.pump();

    await tester.tap(find.text('Read'));
    expect(taps, 1);
  });

  // A card's header keeps its actions (an info button) at the top right,
  // and its values below; the label covers neither.
  testWidgets('the label sits on the card\'s top edge, over no header '
      'action', (tester) async {
    final header = Card(
      key: const ValueKey('headed'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(child: Text('Deco status')),
            IconButton(
              key: const ValueKey('info'),
              onPressed: () {},
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
      ),
    );
    controller.unlock('dive');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 320,
              child: RecordEditScope<String>(
                controller: controller,
                child: RecordCardFade<String>(
                  reason: RecordCardFadeReason.calculated,
                  child: header,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final label = tester.getRect(find.text('Calculated'));
    final info = tester.getRect(find.byKey(const ValueKey('info')));
    final title = tester.getRect(find.text('Deco status'));
    final card = tester.getRect(find.byKey(const ValueKey('headed')));
    expect(label.overlaps(info), isFalse);
    expect(label.overlaps(title), isFalse);
    // On the edge: it straddles the card's top.
    expect(label.top, lessThan(card.top));
    expect(label.bottom, greaterThan(card.top));
  });
}
