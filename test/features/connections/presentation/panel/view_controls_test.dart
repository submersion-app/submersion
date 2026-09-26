import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/connections/presentation/panel/map_editor.dart';
import 'package:submersion/features/connections/presentation/panel/mode_switch.dart';
import 'package:submersion/features/connections/presentation/panel/preset_grid.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/connections/presentation/providers/saved_connection_maps_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeMaps implements ConnectionMapRepository {
  final List<SavedConnectionMap> maps = [];
  final List<String> calls = [];

  @override
  Stream<void> watchConnectionMapsChanges() => const Stream.empty();

  @override
  Future<List<SavedConnectionMap>> getAll(String diverId) async => [...maps];

  @override
  Future<SavedConnectionMap> create({
    required String diverId,
    required String name,
    required MapSpec spec,
  }) async {
    final m = SavedConnectionMap(
      id: 'new-${maps.length}',
      diverId: diverId,
      name: name,
      spec: spec,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    maps.add(m);
    calls.add('create:$name');
    return m;
  }

  @override
  Future<void> rename(String id, String name) async =>
      calls.add('rename:$id:$name');

  @override
  Future<void> updateSpec(String id, MapSpec spec) async =>
      calls.add('update:$id');

  @override
  Future<void> delete(String id) async {
    maps.removeWhere((m) => m.id == id);
    calls.add('delete:$id');
  }

  @override
  Future<void> restore(SavedConnectionMap map) async {
    maps.add(map);
    calls.add('restore:${map.id}');
  }
}

final _saved = SavedConnectionMap(
  id: 'bon',
  diverId: 'me',
  name: 'Bonaire 2025',
  spec: ConnectionPresets.byId('travel')!.spec,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<(ProviderContainer, _FakeMaps)> _pump(
  WidgetTester tester,
  Widget child,
) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeMaps()..maps.add(_saved);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionMapRepositoryProvider.overrideWithValue(fake),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    ProviderScope.containerOf(tester.element(find.byType(Scaffold))),
    fake,
  );
}

void main() {
  testWidgets('the mode switch changes the view mode', (tester) async {
    final (c, _) = await _pump(tester, const ModeSwitch());
    await tester.tap(find.text('Around one entity'));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).mode, ConnectionsMode.around);
  });

  testWidgets('nine presets and the saved map; tapping applies', (
    tester,
  ) async {
    final (c, _) = await _pump(tester, const PresetGrid());
    for (final p in ConnectionPresets.all) {
      expect(find.byKey(ValueKey('preset-${p.id}')), findsOneWidget);
    }
    expect(find.text('Bonaire 2025'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-reef')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).presetId, 'reef');
    await tester.tap(find.byKey(const ValueKey('saved-map-bon')));
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).savedMapId, 'bon');
  });

  testWidgets('an edited preset shows its mark until another is chosen', (
    tester,
  ) async {
    final (c, _) = await _pump(
      tester,
      const Column(children: [PresetGrid(), MapEditor()]),
    );
    await tester.tap(find.byKey(const ValueKey('preset-travel')));
    await tester.pumpAndSettle();
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.editMap(s.mapSpec.withMinimum(2)));
    await tester.pumpAndSettle();
    expect(find.text('edited'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-reef')));
    await tester.pumpAndSettle();
    expect(find.text('edited'), findsNothing);
  });

  testWidgets('the editor ticks kinds, links and the minimum', (tester) async {
    final (c, _) = await _pump(tester, const MapEditor());
    await tester.tap(find.text('Custom map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kind-chip-site')));
    await tester.pumpAndSettle();
    var spec = c.read(connectionsViewProvider).mapSpec;
    expect(spec.kinds, {ConnectionKind.buddy, ConnectionKind.site});
    expect(
      spec.links,
      contains(KindLink(ConnectionKind.buddy, ConnectionKind.site)),
    );
    expect(c.read(connectionsViewProvider).editedFromPresetId, 'circle');

    await tester.tap(find.byKey(const ValueKey('link-buddy-buddy')));
    await tester.pumpAndSettle();
    spec = c.read(connectionsViewProvider).mapSpec;
    expect(
      spec.links,
      isNot(contains(KindLink(ConnectionKind.buddy, ConnectionKind.buddy))),
    );

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('min-shared-slider')),
    );
    slider.onChangeEnd!(4);
    await tester.pumpAndSettle();
    expect(c.read(connectionsViewProvider).mapSpec.minSharedDives, 4);
    expect(find.text('At least 4 shared dives'), findsOneWidget);
  });

  testWidgets('Save as map stores the edited spec and selects it', (
    tester,
  ) async {
    final (c, fake) = await _pump(tester, const MapEditor());
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.editMap(s.mapSpec.withKind(ConnectionKind.trip)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-as-map')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Liveaboard  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['create:Liveaboard']);
    expect(fake.maps.last.spec.kinds, contains(ConnectionKind.trip));
    expect(c.read(connectionsViewProvider).savedMapId, fake.maps.last.id);
  });

  testWidgets('deleting a saved map offers undo', (tester) async {
    final (_, fake) = await _pump(tester, const PresetGrid());
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('saved-map-bon')),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['delete:bon']);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['delete:bon', 'restore:bon']);
  });
}
