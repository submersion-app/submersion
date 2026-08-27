import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_sort_provider.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_toolbar.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

/// Both the view-mode notifier and the sort notifier read and WRITE app
/// settings. Without this override they reach the real repository, and the
/// awaited setMode/setSort calls below throw because no database is open
/// under flutter test.
class _FakeSettingsRepo extends AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getRawSetting(String key) async => values[key];

  @override
  Future<void> setRawSetting(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late ProviderContainer container;
  late SelectionController selection;

  setUp(() {
    selection = SelectionController();
    addTearDown(selection.dispose);
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host({bool canSelect = true}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaLibraryToolbar(selection: selection, canSelect: canSelect),
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, {bool canSelect = true}) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(canSelect: canSelect));
    await tester.pumpAndSettle();
  }

  testWidgets('the filter badge is hidden until something is filtered', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo);
    await tester.pumpAndSettle();

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });

  testWidgets('the sort button opens the sheet and writes the choice', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(find.text('Sort media'), findsOneWidget);
    await tester.tap(find.text('File Name'));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibrarySortProvider).field,
      MediaSortField.fileName,
    );
  });

  testWidgets('the sort button is absent outside grid mode', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.sort), findsOneWidget);

    await container
        .read(mediaLibraryViewModeProvider.notifier)
        .setMode(MediaLibraryViewMode.timeline);
    await tester.pumpAndSettle();

    // The grouped modes consume an already-date-sorted stream, so offering a
    // name or size sort there would shred the timeline into one-item groups.
    expect(find.byIcon(Icons.sort), findsNothing);
  });

  testWidgets('the filter button opens the filter sheet', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.text('Filter media'), findsOneWidget);
  });

  testWidgets('the Select control enters selection mode with nothing checked', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();

    expect(selection.value.isActive, isTrue);
    expect(selection.value.checkedIds, isEmpty);
    expect(
      selection.value.enteredExplicitly,
      isTrue,
      reason: 'a deliberate entry must survive unchecking the last item',
    );
  });

  testWidgets('the Select control is absent when there is nothing to select', (
    tester,
  ) async {
    await pump(tester, canSelect: false);

    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
  });

  // Every control in this row is fixed-width, so a new one is spent budget
  // rather than borrowed space. 320dp is the narrowest phone the app ships
  // to, and a RenderFlex overflow there is a red banner, not a squeeze.
  testWidgets('the row still fits the narrowest supported phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);
  });
}
