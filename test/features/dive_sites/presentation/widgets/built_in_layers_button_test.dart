import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_layers_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _siteRow = ValueKey('builtInLayer_site');
const _registerRow = ValueKey('builtInLayer_register');

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  BuiltInMapLayers layers = const BuiltInMapLayers(),
  Locale? locale,
  Size size = const Size(400, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      builtInMapLayersNotifierProvider.overrideWith(
        (ref) => BuiltInMapLayersNotifier.unstored(layers),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(actions: const [BuiltInLayersButton()])),
      ),
    ),
  );
  return container;
}

/// The layer's row. A [CheckboxMenuButton] hands its key on to the menu
/// item inside it, so the key alone finds two widgets.
Finder _row(Key key) => find.byWidgetPredicate(
  (widget) => widget is CheckboxMenuButton && widget.key == key,
);

bool? _ticked(WidgetTester tester, Key row) =>
    tester.widget<CheckboxMenuButton>(_row(row)).value;

void main() {
  testWidgets('opens a menu of the two layers, ticked as they stand', (
    tester,
  ) async {
    await _pump(tester);
    expect(_row(_siteRow), findsNothing);

    await tester.tap(find.byType(BuiltInLayersButton));
    await tester.pumpAndSettle();

    expect(find.text('Built-in dive sites'), findsOneWidget);
    expect(find.text('Charted wrecks and reefs'), findsOneWidget);
    expect(_ticked(tester, _siteRow), isTrue);
    expect(_ticked(tester, _registerRow), isFalse);
    // Each row carries the glyph its pins have on the map.
    expect(
      find.descendant(
        of: _row(_siteRow),
        matching: find.byIcon(Icons.location_on_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row(_registerRow),
        matching: find.byIcon(Icons.anchor),
      ),
      findsOneWidget,
    );
  });

  testWidgets('ticking a row changes its layer and leaves the menu open', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.tap(find.byType(BuiltInLayersButton));
    await tester.pumpAndSettle();

    await tester.tap(_row(_registerRow));
    await tester.pumpAndSettle();

    expect(
      container.read(builtInMapLayersNotifierProvider),
      const BuiltInMapLayers(registers: true),
    );
    // Still open, so the other layer can be changed in the same visit.
    expect(_ticked(tester, _registerRow), isTrue);

    await tester.tap(_row(_siteRow));
    await tester.pumpAndSettle();

    expect(
      container.read(builtInMapLayersNotifierProvider),
      const BuiltInMapLayers(diveSites: false, registers: true),
    );
    expect(_ticked(tester, _siteRow), isFalse);
  });

  testWidgets('the button shows whether any layer is on', (tester) async {
    final container = await _pump(tester);
    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(find.byTooltip('Built-in sites on the map'), findsOneWidget);

    await container
        .read(builtInMapLayersNotifierProvider.notifier)
        .setLayer(CatalogueKind.site, false);
    await tester.pump();

    expect(find.byIcon(Icons.public_off), findsOneWidget);
    expect(find.byIcon(Icons.public), findsNothing);

    await container
        .read(builtInMapLayersNotifierProvider.notifier)
        .setLayer(CatalogueKind.register, true);
    await tester.pump();

    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('a screen reader hears whether any layer is on', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await _pump(tester);
    // The node the button's own Semantics makes, which its tooltip and
    // tap action merge into.
    final button = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.toggled != null,
    );

    expect(
      tester.getSemantics(button),
      isSemantics(hasToggledState: true, isToggled: true),
    );

    await container
        .read(builtInMapLayersNotifierProvider.notifier)
        .setLayer(CatalogueKind.site, false);
    await tester.pump();

    expect(
      tester.getSemantics(button),
      isSemantics(hasToggledState: true, isToggled: false),
    );
    handle.dispose();
  });

  testWidgets('the rows fit a narrow phone in a long language', (tester) async {
    await _pump(tester, locale: const Locale('de'), size: const Size(320, 600));

    await tester.tap(find.byType(BuiltInLayersButton));
    await tester.pumpAndSettle();

    expect(find.text('Verzeichnete Wracks und Riffe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
