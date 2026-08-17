import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/wrecks/data/repositories/wreck_repository.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';
import 'package:submersion/features/wrecks/presentation/pages/wreck_detail_page.dart';
import 'package:submersion/features/wrecks/presentation/pages/wreck_edit_page.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/features/wrecks/presentation/widgets/wreck_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records what the edit form asks the repository to do.
class _RecordingWreckRepository implements WreckRepository {
  final List<Wreck> created = [];
  final List<Wreck> updated = [];

  @override
  Future<Wreck> createWreck(Wreck wreck) async {
    created.add(wreck);
    return wreck.copyWith(id: 'new-id');
  }

  @override
  Future<void> updateWreck(Wreck wreck) async => updated.add(wreck);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _hilma = Wreck(
  id: 'w-1',
  name: 'Hilma Hooker',
  vesselTypeName: 'ship',
  depthToDeckMeters: 18,
  depthToSeabedMeters: 30,
  yearSunk: 1984,
  conditionName: 'intact',
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppSettings settings = const AppSettings(),
  List<Wreck> wrecks = const [],
  Wreck? single,
  WreckRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
        wrecksProvider.overrideWith((ref) async => wrecks),
        wreckProvider('w-1').overrideWith((ref) async => single),
        sitesProvider.overrideWith((ref) async => <DiveSite>[]),
        if (repository != null)
          wreckRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('WreckListContent', () {
    testWidgets('lists wrecks and filters by search', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: WreckListContent(onWreckSelected: (_) {}, onAddWreck: () {}),
        ),
        wrecks: const [
          _hilma,
          Wreck(id: 'w-2', name: 'Salt Pier Barge'),
        ],
      );

      expect(find.text('Hilma Hooker'), findsOneWidget);
      expect(find.text('Salt Pier Barge'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('wreckSearchField')),
        'hilma',
      );
      await tester.pump();
      expect(find.text('Hilma Hooker'), findsOneWidget);
      expect(find.text('Salt Pier Barge'), findsNothing);
    });

    testWidgets('an empty catalogue shows the empty state', (tester) async {
      var added = 0;
      await _pump(
        tester,
        Scaffold(
          body: WreckListContent(
            onWreckSelected: (_) {},
            onAddWreck: () => added++,
          ),
        ),
      );

      expect(find.text('No wrecks yet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wreckAddButton')));
      await tester.pump();
      expect(added, 1);
    });

    testWidgets('tapping a row reports the selection upward', (tester) async {
      String? selected;
      await _pump(
        tester,
        Scaffold(
          body: WreckListContent(
            onWreckSelected: (id) => selected = id,
            onAddWreck: () {},
          ),
        ),
        wrecks: const [_hilma],
      );

      await tester.tap(find.byKey(const ValueKey('wreckRow-w-1')));
      await tester.pump();
      expect(selected, 'w-1');
    });
  });

  group('WreckDetailPage', () {
    testWidgets('renders the facts in the diver unit', (tester) async {
      await _pump(
        tester,
        const WreckDetailPage(wreckId: 'w-1'),
        single: _hilma,
      );

      expect(find.text('Hilma Hooker'), findsWidgets);
      expect(find.text('Ship'), findsOneWidget);
      expect(find.text('18 m'), findsOneWidget);
      expect(find.text('30 m'), findsOneWidget);
      expect(find.text('1984'), findsOneWidget);
      expect(find.text('Intact'), findsOneWidget);
    });

    testWidgets('a feet diver reads the depths in feet', (tester) async {
      await _pump(
        tester,
        const WreckDetailPage(wreckId: 'w-1'),
        single: _hilma,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );

      // 18 m is 59.1 ft to one decimal.
      expect(find.text('59.1 ft'), findsOneWidget);
    });

    testWidgets('an unknown enum name shows its raw value', (tester) async {
      await _pump(
        tester,
        const WreckDetailPage(wreckId: 'w-1'),
        single: const Wreck(
          id: 'w-1',
          name: 'Mystery',
          vesselTypeName: 'submersible',
        ),
      );

      expect(find.text('submersible'), findsOneWidget);
    });

    testWidgets('a missing wreck renders a message, not a crash', (
      tester,
    ) async {
      await _pump(tester, const WreckDetailPage(wreckId: 'w-1'));
      expect(find.text('No wrecks yet'), findsOneWidget);
    });
  });

  group('WreckEditPage', () {
    testWidgets('creating a wreck writes it through the repository', (
      tester,
    ) async {
      final repo = _RecordingWreckRepository();
      await _pump(tester, const WreckEditPage(), repository: repo);

      await tester.enterText(
        find.byKey(const ValueKey('wreckNameField')),
        'Hilma Hooker',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wreckDeckDepthField')),
        '18',
      );
      await tester.tap(find.byKey(const ValueKey('wreckSaveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.created, hasLength(1));
      expect(repo.created.single.name, 'Hilma Hooker');
      expect(repo.created.single.depthToDeckMeters, 18);
      expect(repo.updated, isEmpty);
    });

    testWidgets('a feet diver types feet and metres are stored', (
      tester,
    ) async {
      final repo = _RecordingWreckRepository();
      await _pump(
        tester,
        const WreckEditPage(),
        repository: repo,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );

      await tester.enterText(
        find.byKey(const ValueKey('wreckNameField')),
        'Hilma Hooker',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wreckDeckDepthField')),
        '60',
      );
      await tester.tap(find.byKey(const ValueKey('wreckSaveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.created.single.depthToDeckMeters, closeTo(18.288, 1e-9));
    });

    testWidgets('coordinates accept a decimal comma', (tester) async {
      final repo = _RecordingWreckRepository();
      await _pump(tester, const WreckEditPage(), repository: repo);

      await tester.enterText(
        find.byKey(const ValueKey('wreckNameField')),
        'Hilma Hooker',
      );
      // The coordinate fields sit far down a lazily built ListView, so
      // they are not in the tree until scrolled into view.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('wreckLatitudeField')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Many divers type a decimal comma; the other numeric fields
      // already normalize it.
      await tester.enterText(
        find.byKey(const ValueKey('wreckLatitudeField')),
        '12,15',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wreckLongitudeField')),
        '-68,3',
      );
      await tester.tap(find.byKey(const ValueKey('wreckSaveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.created.single.latitude, closeTo(12.15, 1e-9));
      expect(repo.created.single.longitude, closeTo(-68.3, 1e-9));
    });

    testWidgets('saving without a name is refused', (tester) async {
      final repo = _RecordingWreckRepository();
      await _pump(tester, const WreckEditPage(), repository: repo);

      await tester.tap(find.byKey(const ValueKey('wreckSaveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.created, isEmpty);
      expect(repo.updated, isEmpty);
    });

    testWidgets('editing an existing wreck updates rather than creates', (
      tester,
    ) async {
      final repo = _RecordingWreckRepository();
      await _pump(
        tester,
        const WreckEditPage(wreckId: 'w-1'),
        single: _hilma,
        repository: repo,
      );

      // The form hydrated from the stored wreck.
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('wreckNameField')))
            .controller
            ?.text,
        'Hilma Hooker',
      );

      await tester.enterText(
        find.byKey(const ValueKey('wreckNameField')),
        'Hilma',
      );
      await tester.tap(find.byKey(const ValueKey('wreckSaveButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.updated, hasLength(1));
      expect(repo.updated.single.id, 'w-1');
      expect(repo.updated.single.name, 'Hilma');
      // Untouched fields survive the round-trip.
      expect(repo.updated.single.depthToSeabedMeters, 30);
      expect(repo.created, isEmpty);
    });
  });
}
