import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/presentation/widgets/nav_shortcut_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Set<String> added, void Function(String?) onPicked) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async =>
            onPicked(await showNavShortcutPicker(context, alreadyAdded: added)),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester, Widget host, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(host);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the groups and returns the chosen id', (tester) async {
    String? picked;
    await _open(tester, _host(const {}, (id) => picked = id));

    expect(find.text('Add a shortcut'), findsOneWidget);
    expect(find.text('Planning'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'blender');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trimix blender'));
    await tester.pumpAndSettle();

    expect(picked, 'gas-blender');
  });

  testWidgets('search matches the parent label too', (tester) async {
    // Tall enough that the sheet builds all eight calculators.
    await _open(tester, _host(const {}, (_) {}), size: const Size(400, 1600));
    await tester.enterText(find.byType(TextField), 'gas calc');
    await tester.pumpAndSettle();

    // Every calculator lists Gas Calculators as its parent.
    expect(find.text('MOD'), findsOneWidget);
    expect(find.text('Trimix blender'), findsOneWidget);
    expect(find.text('Records'), findsNothing);
  });

  testWidgets('an entry already added is disabled', (tester) async {
    String? picked = 'unset';
    await _open(tester, _host({'gas-blender'}, (id) => picked = id));
    await tester.enterText(find.byType(TextField), 'blender');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trimix blender'));
    await tester.pumpAndSettle();

    expect(picked, 'unset');
    expect(find.byTooltip('Already in this layout'), findsOneWidget);
  });

  testWidgets('a search with no match says so', (tester) async {
    await _open(tester, _host(const {}, (_) {}));
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('No matching pages'), findsOneWidget);
  });

  testWidgets('the close button returns nothing', (tester) async {
    String? picked = 'unset';
    await _open(tester, _host(const {}, (id) => picked = id));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('a wide window gets a dialog', (tester) async {
    await _open(tester, _host(const {}, (_) {}), size: const Size(1200, 900));
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('a phone gets a bottom sheet', (tester) async {
    await _open(tester, _host(const {}, (_) {}), size: const Size(400, 800));
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('the phone sheet rises above the keyboard', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await _open(tester, _host(const {}, (_) {}), size: const Size(400, 800));

    expect(
      tester.getBottomLeft(find.byType(NavShortcutPicker)).dy,
      lessThanOrEqualTo(800 - 300),
    );
  });

  testWidgets(
    'on a desktop OS the search takes focus at once',
    (tester) async {
      await _open(tester, _host(const {}, (_) {}), size: const Size(1200, 900));
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets(
    'a wide touch tablet leaves the keyboard down',
    (tester) async {
      // A tablet in landscape is wide enough for the dialog, but focusing
      // would throw the on-screen keyboard over it.
      await _open(tester, _host(const {}, (_) {}), size: const Size(1200, 900));
      expect(find.byType(Dialog), findsOneWidget);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isFalse);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('the phone sheet leaves the keyboard down until asked', (
    tester,
  ) async {
    await _open(tester, _host(const {}, (_) {}), size: const Size(400, 800));
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isFalse);
  });
}
