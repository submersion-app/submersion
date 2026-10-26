import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed) {
    state = CardViewConfig.defaultDetailed();
  }
}

class _ProfileRepository implements DiveRepository {
  final calls = <List<String>>[];

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    calls.add(diveIds);
    return {for (final id in diveIds) id: _profile};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 60, depth: 18),
  DiveProfilePoint(timestamp: 1800, depth: 0),
];

DiveListTile _tile(String id) {
  final summary = DiveSummary(
    id: id,
    diveNumber: 7,
    dateTime: DateTime(2024, 6, 1),
    siteName: 'Site $id',
    maxDepth: 18.0,
    sortTimestamp: 0,
  );
  return DiveListTile(
    diveId: id,
    diveNumber: 7,
    dateTime: DateTime(2024, 6, 1),
    siteName: 'Site $id',
    summary: summary,
  );
}

void main() {
  testWidgets('cards built without a cached profile fetch theirs in one '
      'batch', (tester) async {
    final repo = _ProfileRepository();
    await tester.pumpWidget(
      testApp(
        overrides: [
          diveRepositoryProvider.overrideWithValue(repo),
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(const AppSettings()),
          ),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
        ],
        child: ListView(children: [_tile('d1'), _tile('d2'), _tile('d3')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.calls, [
      ['d1', 'd2', 'd3'],
    ]);
    final cache = ProviderScope.containerOf(
      tester.element(find.byType(ListView)),
    ).read(batchProfileCacheProvider);
    expect(cache.keys.toSet(), {'d1', 'd2', 'd3'});

    await tester.pumpWidget(
      testApp(
        overrides: [
          diveRepositoryProvider.overrideWithValue(repo),
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(const AppSettings()),
          ),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
        ],
        child: ListView(children: [_tile('d1'), _tile('d2'), _tile('d3')]),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(1));
  });
}
