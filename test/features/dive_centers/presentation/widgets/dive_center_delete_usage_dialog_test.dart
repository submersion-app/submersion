import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Stands in for the database: [linkedDives] dives use every center.
class _FakeCenterRepository extends DiveCenterRepository {
  _FakeCenterRepository(this.linkedDives);

  final int linkedDives;
  final countedFor = <List<String>>[];

  @override
  Future<int> getLinkedDiveCount(List<String> centerIds) async {
    countedFor.add(centerIds);
    return linkedDives;
  }
}

class _FakeCenterListNotifier
    extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _FakeCenterListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A center delete keeps the dives logged with the center, with the center
/// cleared (issue #1952). Both delete confirmations say so when the center
/// is in use.
void main() {
  final center = DiveCenter(
    id: 'center-1',
    name: 'Reef Divers',
    notes: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  void setPhoneSize(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('DiveCenterDetailPage', () {
    Future<void> openDeleteDialog(
      WidgetTester tester,
      _FakeCenterRepository repository,
    ) async {
      setPhoneSize(tester);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveCenterRepositoryProvider.overrideWithValue(repository),
            diveCenterByIdProvider(center.id).overrideWith((_) async => center),
            diveCenterDiveCountProvider(center.id).overrideWith((_) async => 0),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: DiveCenterDetailPage(centerId: center.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('the delete dialog says how many dives keep going without '
        'the center', (tester) async {
      final repository = _FakeCenterRepository(3);

      await openDeleteDialog(tester, repository);

      expect(
        find.textContaining('3 dives will be left without a dive center.'),
        findsOneWidget,
      );
      expect(repository.countedFor, [
        ['center-1'],
      ]);
    });

    testWidgets('the delete dialog of a center no dive uses says nothing '
        'more', (tester) async {
      await openDeleteDialog(tester, _FakeCenterRepository(0));

      expect(find.textContaining('without a dive center'), findsNothing);
    });
  });

  testWidgets('DiveCenterListContent bulk delete says how many dives keep '
      'going without their center', (tester) async {
    setPhoneSize(tester);
    final repository = _FakeCenterRepository(1);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveCenterRepositoryProvider.overrideWithValue(repository),
          diveCenterListNotifierProvider.overrideWith(
            (ref) => _FakeCenterListNotifier([center]),
          ),
          diveCenterListViewModeProvider.overrideWith(
            (ref) => ListViewMode.detailed,
          ),
          diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
          highlightedDiveCenterIdProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: DiveCenterListContent(showAppBar: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_delete')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 dive will be left without a dive center.'),
      findsOneWidget,
    );
    expect(repository.countedFor, [
      ['center-1'],
    ]);
  });
}
