import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_display.dart';
import 'package:submersion/features/connections/presentation/providers/connections_display_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  test('starts at the defaults with nothing stored', () async {
    final (c, _) = await _container({});
    expect(c.read(connectionsDisplayProvider), ConnectionsDisplay.initial);
  });

  test('restores a stored display', () async {
    final stored = ConnectionsDisplay.initial.copyWith(
      view: ConnectionsViewKind.pairs,
      spacing: 1.5,
    );
    final (c, _) = await _container({
      kConnectionsDisplayKey: jsonEncode(stored.toJson()),
    });
    expect(c.read(connectionsDisplayProvider), stored);
  });

  test('garbage in storage falls back to the defaults', () async {
    final (c, _) = await _container({kConnectionsDisplayKey: '{nope'});
    expect(c.read(connectionsDisplayProvider), ConnectionsDisplay.initial);
  });

  test('update changes state and persists it', () async {
    final (c, sp) = await _container({});
    await c
        .read(connectionsDisplayProvider.notifier)
        .update((d) => d.copyWith(labels: LabelMode.all));
    expect(c.read(connectionsDisplayProvider).labels, LabelMode.all);
    final saved = ConnectionsDisplay.fromJson(
      jsonDecode(sp.getString(kConnectionsDisplayKey)!),
    );
    expect(saved.labels, LabelMode.all);
  });

  test('a failed write keeps the new state', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final n = ConnectionsDisplayNotifier(
      sp,
      write: (_, _) async => throw Exception('disk full'),
    );
    addTearDown(n.dispose);
    await n.update((d) => d.copyWith(edges: EdgeMode.thin));
    expect(n.state.edges, EdgeMode.thin);
  });

  test('writes run one after another, in the order of the changes', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final first = Completer<bool>();
    final started = <String>[];
    final n = ConnectionsDisplayNotifier(
      sp,
      write: (_, value) {
        started.add(value);
        return started.length == 1 ? first.future : Future.value(true);
      },
    );
    addTearDown(n.dispose);
    final a = n.update((d) => d.copyWith(labels: LabelMode.all));
    final b = n.update((d) => d.copyWith(labels: LabelMode.off));
    await Future<void>.delayed(Duration.zero);
    expect(started, hasLength(1), reason: 'the second waits for the first');
    first.complete(true);
    await Future.wait([a, b]);
    expect(started, hasLength(2));
    expect(
      ConnectionsDisplay.fromJson(jsonDecode(started.last)).labels,
      LabelMode.off,
    );
  });
}
