import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');

Future<(ProviderContainer, SharedPreferences)> _container(
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
  addTearDown(c.dispose);
  return (c, sp);
}

void main() {
  test('starts at the Dive circle preset with nothing stored', () async {
    final (c, _) = await _container({});
    expect(c.read(connectionsViewProvider), ConnectionsViewState.initial);
  });

  test('restores a stored view and prefers it over the legacy lens', () async {
    final stored = ConnectionsViewState.initial.centreOn(_jane).withHops(2);
    final (c, _) = await _container({
      kConnectionsViewKey: jsonEncode(stored.toJson()),
      kConnectionsLegacyLensKey: 'where',
    });
    expect(c.read(connectionsViewProvider), stored);
  });

  test('migrates a phase 1 lens when no view is stored', () async {
    final (c, _) = await _container({kConnectionsLegacyLensKey: 'where'});
    expect(c.read(connectionsViewProvider).presetId, 'where');
  });

  test('garbage in storage falls back to the initial view', () async {
    final (c, _) = await _container({kConnectionsViewKey: '{not json'});
    expect(c.read(connectionsViewProvider), ConnectionsViewState.initial);
  });

  test('update changes state and persists it', () async {
    final (c, sp) = await _container({});
    await c
        .read(connectionsViewProvider.notifier)
        .update((s) => s.applyPreset(ConnectionPresets.byId('reef')!));
    expect(c.read(connectionsViewProvider).presetId, 'reef');
    final saved = ConnectionsViewState.fromJson(
      jsonDecode(sp.getString(kConnectionsViewKey)!),
    );
    expect(saved!.presetId, 'reef');
  });

  test('a failing write keeps the new state and does not throw', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final notifier = ConnectionsViewNotifier(
      sp,
      write: (key, value) => Future.error(StateError('disk full')),
    );
    addTearDown(notifier.dispose);
    await notifier.update((s) => s.centreOn(_jane));
    expect(notifier.state.focus, _jane);
  });
}
