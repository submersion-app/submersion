import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/panel/display_section.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: DisplaySection())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('map mode offers web and not radial; a chip sets the layout', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(find.byKey(const ValueKey('layout-web')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-radial')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('layout-timeline')));
    await tester.pumpAndSettle();
    expect(
      c.read(connectionsDisplayProvider).mapLayout,
      ConnectionsLayout.timeline,
    );
    expect(
      c.read(connectionsDisplayProvider).aroundLayout,
      ConnectionsLayout.radial,
    );
  });

  testWidgets('around mode offers radial and sets the around layout', (
    tester,
  ) async {
    final c = await _pump(tester);
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.withMode(ConnectionsMode.around));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('layout-radial')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-web')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('layout-circle')));
    await tester.pumpAndSettle();
    expect(
      c.read(connectionsDisplayProvider).aroundLayout,
      ConnectionsLayout.circle,
    );
  });

  testWidgets('the segments and the switch write the display', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('Off'));
    await tester.tap(find.text('Uniform'));
    await tester.tap(find.text('Selected only'));
    await tester.tap(find.text('Hide unconnected'));
    await tester.pumpAndSettle();
    final d = c.read(connectionsDisplayProvider);
    expect(d.labels, LabelMode.off);
    expect(d.nodeSize, NodeSizeMode.uniform);
    expect(d.edges, EdgeMode.selectedOnly);
    expect(d.hideUnconnected, isTrue);
  });

  testWidgets('spacing is written once, when the slider is let go', (
    tester,
  ) async {
    final c = await _pump(tester);
    final slider = find.byKey(const ValueKey('spacing-slider'));
    await tester.drag(slider, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(c.read(connectionsDisplayProvider).spacing, greaterThan(1.0));
  });
}
