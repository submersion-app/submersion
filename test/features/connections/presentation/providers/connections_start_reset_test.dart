import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_start_reset.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');

Future<ProviderContainer> _container(SharedPreferences sp) async {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('a stored map moves to the start, keeping Around settings', () async {
    final stored = ConnectionsViewState.initial
        .applySavedMap('m1', ConnectionPresets.byId('circle')!.spec)
        .centreOn(_jane)
        .withHops(2)
        .withMode(ConnectionsMode.around);
    final sp = await _prefs({kConnectionsViewKey: jsonEncode(stored.toJson())});
    final view = (await _container(sp)).read(connectionsViewProvider);
    expect(view.mode, ConnectionsMode.map);
    expect(view.presetId, 'where');
    expect(view.savedMapId, isNull);
    expect(view.focus, _jane);
    expect(view.hops, 2);
    // The marker follows the writes it confirms.
    await pumpEventQueue();
    expect(sp.getBool(kConnectionsStartResetKey), isTrue);
  });

  test('the display returns to the web graph, keeping the rest', () async {
    const stored = ConnectionsDisplay(
      view: ConnectionsViewKind.matrix,
      mapLayout: ConnectionsLayout.circle,
      labels: LabelMode.all,
      spacing: 1.5,
    );
    final sp = await _prefs({
      kConnectionsDisplayKey: jsonEncode(stored.toJson()),
    });
    final display = (await _container(sp)).read(connectionsDisplayProvider);
    expect(display.view, ConnectionsViewKind.graph);
    expect(display.mapLayout, ConnectionsLayout.web);
    expect(display.labels, LabelMode.all);
    expect(display.spacing, 1.5);
  });

  test('a phase 1 lens alone moves to the start too', () async {
    final sp = await _prefs({kConnectionsLegacyLensKey: 'gear'});
    final view = (await _container(sp)).read(connectionsViewProvider);
    expect(view.presetId, 'where');
  });

  test('nothing stored gives the start and sets the marker', () async {
    final sp = await _prefs({});
    final c = await _container(sp);
    expect(c.read(connectionsViewProvider), ConnectionsViewState.initial);
    expect(c.read(connectionsDisplayProvider), ConnectionsDisplay.initial);
    await pumpEventQueue();
    expect(sp.getBool(kConnectionsStartResetKey), isTrue);
  });

  test('the move runs once per device', () async {
    final travel = ConnectionsViewState.initial.applyPreset(
      ConnectionPresets.byId('travel')!,
    );
    final sp = await _prefs({
      kConnectionsStartResetKey: true,
      kConnectionsViewKey: jsonEncode(travel.toJson()),
    });
    final first = await _container(sp);
    expect(first.read(connectionsViewProvider).presetId, 'travel');
    await first
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('gear')!));
    final second = await _container(sp);
    expect(second.read(connectionsViewProvider).presetId, 'gear');
  });

  test('a returning device keeps its choice after the move', () async {
    final sp = await _prefs({
      kConnectionsViewKey: jsonEncode(
        ConnectionsViewState.initial
            .applyPreset(ConnectionPresets.byId('travel')!)
            .toJson(),
      ),
    });
    final first = await _container(sp);
    expect(first.read(connectionsViewProvider).presetId, 'where');
    await first
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    final second = await _container(sp);
    expect(second.read(connectionsViewProvider).presetId, 'reef');
  });

  test('resetConnectionsStartOnce is idempotent', () async {
    final sp = await _prefs({kConnectionsLegacyLensKey: 'gear'});
    await resetConnectionsStartOnce(sp);
    final once = sp.getString(kConnectionsViewKey);
    await resetConnectionsStartOnce(sp);
    expect(sp.getString(kConnectionsViewKey), once);
  });

  test(
    'a failed write leaves the marker unset, so the move runs again',
    () async {
      final sp = await _prefs({kConnectionsLegacyLensKey: 'gear'});
      await resetConnectionsStartOnce(sp, writeString: (_, _) async => false);
      expect(sp.getBool(kConnectionsStartResetKey), isNull);
      await resetConnectionsStartOnce(sp);
      expect(sp.getBool(kConnectionsStartResetKey), isTrue);
    },
  );

  test('the marker is written only after the view and display', () async {
    final sp = await _prefs({
      kConnectionsLegacyLensKey: 'gear',
      kConnectionsDisplayKey: '{}',
    });
    final written = <String>[];
    await resetConnectionsStartOnce(
      sp,
      writeString: (key, value) async {
        // Each write is issued before the marker exists.
        expect(sp.getBool(kConnectionsStartResetKey), isNull);
        written.add(key);
        return sp.setString(key, value);
      },
    );
    expect(written, {kConnectionsViewKey, kConnectionsDisplayKey});
    expect(sp.getBool(kConnectionsStartResetKey), isTrue);
  });

  test('two providers building at once run the move once', () async {
    final sp = await _prefs({
      kConnectionsLegacyLensKey: 'gear',
      kConnectionsDisplayKey: '{}',
    });
    final written = <String>[];
    Future<bool> writer(String key, String value) {
      written.add(key);
      return sp.setString(key, value);
    }

    final first = resetConnectionsStartOnce(sp, writeString: writer);
    final second = resetConnectionsStartOnce(sp, writeString: writer);
    await Future.wait([first, second]);
    expect(written, [kConnectionsViewKey, kConnectionsDisplayKey]);
    expect(sp.getBool(kConnectionsStartResetKey), isTrue);
  });

  test('a write that throws is logged and leaves the marker unset', () async {
    final sp = await _prefs({kConnectionsLegacyLensKey: 'gear'});
    await expectLater(
      resetConnectionsStartOnce(
        sp,
        writeString: (_, _) => Future.error(StateError('disk full')),
      ),
      completes,
    );
    expect(sp.getBool(kConnectionsStartResetKey), isNull);
  });
}
