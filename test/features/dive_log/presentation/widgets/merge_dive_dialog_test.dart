import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/merge_dive_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/run_dive_consolidation.dart'
    show runDiveConsolidation;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Fixed date used for the "current" dive across all tests.
final _currentDiveDate = DateTime(2026, 3, 20, 10, 0);

/// Default time pattern from the default AppSettings (12-hour).
const _defaultTimePattern = 'h:mm a';

Dive _makeDive({
  required String id,
  int? diveNumber,
  String? siteName,
  double? maxDepth,
  Duration? duration,
  String? diveComputerModel,
  DateTime? dateTime,
  DateTime? entryTime,
}) {
  return Dive(
    id: id,
    dateTime: dateTime ?? _currentDiveDate,
    diveNumber: diveNumber,
    maxDepth: maxDepth,
    bottomTime: duration,
    diveComputerModel: diveComputerModel,
    entryTime: entryTime,
    site: siteName != null ? DiveSite(id: 'site-$id', name: siteName) : null,
  );
}

/// Pumps a [MaterialApp] + [ProviderScope] and opens the [MergeDiveDialog]
/// via [showMergeDiveDialog] so the dialog gets its natural constraints.
///
/// Sets the test surface to 1024x768 to give the dialog enough room --
/// the production widget uses a 520px maxWidth which overflows the default
/// 800px test surface at the headlineSmall text size.
Future<void> _pumpAndOpenDialog(
  WidgetTester tester, {
  required List<Dive> allDives,
  String currentDiveId = 'current-dive',
  DateTime? currentDiveDate,
  void Function(List<String>)? onMerge,
}) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  late BuildContext savedContext;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diveListNotifierProvider.overrideWith(
          (ref) => _FakeDiveListNotifier(allDives),
        ),
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  showMergeDiveDialog(
    context: savedContext,
    currentDiveId: currentDiveId,
    currentDiveDate: currentDiveDate ?? _currentDiveDate,
    onMerge: onMerge ?? (_) {},
  );
  await tester.pumpAndSettle();
}

/// Minimal notifier that immediately exposes a successful dive list.
class _FakeDiveListNotifier extends StateNotifier<AsyncValue<List<Dive>>>
    implements DiveListNotifier {
  _FakeDiveListNotifier(List<Dive> dives) : super(AsyncValue.data(dives));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal SettingsNotifier override that returns default AppSettings.
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Candidate dives on the same day as _currentDiveDate.
List<Dive> _sameDayCandidates() {
  return [
    _makeDive(
      id: 'current-dive',
      diveNumber: 100,
      siteName: 'Blue Hole',
      dateTime: _currentDiveDate,
    ),
    _makeDive(
      id: 'candidate-1',
      diveNumber: 101,
      siteName: 'Coral Garden',
      maxDepth: 25.0,
      duration: const Duration(minutes: 45),
      diveComputerModel: 'Shearwater Perdix',
      entryTime: _currentDiveDate.add(const Duration(hours: 1)),
      dateTime: _currentDiveDate.add(const Duration(hours: 1)),
    ),
    _makeDive(
      id: 'candidate-2',
      diveNumber: 102,
      maxDepth: 18.3,
      duration: const Duration(minutes: 30),
      entryTime: _currentDiveDate.add(const Duration(hours: 3)),
      dateTime: _currentDiveDate.add(const Duration(hours: 3)),
    ),
  ];
}

/// Navigate to the confirmation screen by selecting candidate-1 and
/// tapping Next.
Future<void> _navigateToConfirmation(WidgetTester tester) async {
  await tester.tap(find.text('#101'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
}

void main() {
  group('MergeDiveDialog - selection screen', () {
    testWidgets('renders heading and description text', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      expect(find.text('Merge with another dive'), findsOneWidget);
      expect(
        find.text(
          'Select a dive from the same day to merge as an additional '
          'computer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Cancel and Next buttons', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Next button is disabled when no dive is selected', (
      tester,
    ) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      final nextButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('shows candidate dives but excludes the current dive', (
      tester,
    ) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      // Candidates should appear.
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('#102'), findsOneWidget);

      // The current dive should not appear as a candidate tile.
      expect(find.text('#100'), findsNothing);
    });

    testWidgets('shows site name with time in tile title', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      final entryTime = _currentDiveDate.add(const Duration(hours: 1));
      final timeStr = DateFormat(_defaultTimePattern).format(entryTime);

      expect(find.textContaining('Coral Garden'), findsOneWidget);
      expect(find.textContaining(timeStr), findsOneWidget);
    });

    testWidgets('shows depth, duration, and computer in subtitle', (
      tester,
    ) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      // Candidate-1: 25.0m (UnitFormatter format), 45min, Shearwater Perdix
      expect(find.textContaining('25.0m'), findsOneWidget);
      expect(find.textContaining('45min'), findsOneWidget);
      expect(find.textContaining('Shearwater Perdix'), findsOneWidget);
    });

    testWidgets('shows empty state when no same-day dives exist', (
      tester,
    ) async {
      final dives = [_makeDive(id: 'current-dive', dateTime: _currentDiveDate)];
      await _pumpAndOpenDialog(tester, allDives: dives);

      expect(find.text('No other dives found on this day.'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('excludes dives from a different day', (tester) async {
      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        _makeDive(
          id: 'other-day',
          diveNumber: 200,
          dateTime: _currentDiveDate.add(const Duration(days: 1)),
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      expect(find.text('#200'), findsNothing);
      expect(find.text('No other dives found on this day.'), findsOneWidget);
    });

    testWidgets('selecting a dive enables the Next button', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      await tester.tap(find.text('#101'));
      await tester.pumpAndSettle();

      final nextButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(nextButton.onPressed, isNotNull);
    });

    testWidgets('selected tile shows check_circle icon', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.tap(find.text('#101'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('Cancel button dismisses the dialog', (tester) async {
      List<String>? mergedIds;
      await _pumpAndOpenDialog(
        tester,
        allDives: _sameDayCandidates(),
        onMerge: (ids) => mergedIds = ids,
      );

      expect(find.text('Merge with another dive'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Merge with another dive'), findsNothing);
      expect(mergedIds, isNull);
    });

    testWidgets('shows loading indicator while dives are loading', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveListNotifierProvider.overrideWith(
              (ref) => _LoadingDiveListNotifier(),
            ),
            settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      showMergeDiveDialog(
        context: ctx,
        currentDiveId: 'current-dive',
        currentDiveDate: _currentDiveDate,
        onMerge: (_) {},
      );
      // Single pump to show loading state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error text when dive list fails to load', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveListNotifierProvider.overrideWith(
              (ref) => _ErrorDiveListNotifier(),
            ),
            settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      showMergeDiveDialog(
        context: ctx,
        currentDiveId: 'current-dive',
        currentDiveDate: _currentDiveDate,
        onMerge: (_) {},
      );
      await tester.pump();

      expect(find.textContaining('Error loading dives'), findsOneWidget);
    });
  });

  group('MergeDiveDialog - confirmation screen', () {
    testWidgets('tapping Next shows confirmation screen', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());
      await _navigateToConfirmation(tester);

      expect(find.text('Confirm merge'), findsOneWidget);
      expect(find.text('What this does'), findsOneWidget);
    });

    testWidgets('confirmation screen shows warning icon', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());
      await _navigateToConfirmation(tester);

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('confirmation screen shows merge time label', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());
      await _navigateToConfirmation(tester);

      final entryTime = _currentDiveDate.add(const Duration(hours: 1));
      final timeStr = DateFormat(_defaultTimePattern).format(entryTime);
      expect(
        find.text('Merging dive at $timeStr into this dive.'),
        findsOneWidget,
      );
    });

    testWidgets('confirmation screen explains the fold honestly', (
      tester,
    ) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());
      await _navigateToConfirmation(tester);

      expect(
        find.textContaining(
          "profile, tanks, pressures, events, tags, buddies, and sightings "
          "will be folded into this dive as an additional computer source",
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining("reversed with 'Unlink computer'"),
        findsOneWidget,
      );
    });

    testWidgets('confirmation screen has Back and Merge buttons', (
      tester,
    ) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());
      await _navigateToConfirmation(tester);

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Merge'), findsOneWidget);
    });

    testWidgets('Back button returns to selection screen', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());
      await _navigateToConfirmation(tester);

      expect(find.text('Confirm merge'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Merge with another dive'), findsOneWidget);
      expect(find.text('Confirm merge'), findsNothing);
    });

    testWidgets(
      'Merge button calls onMerge with the selected dive ID wrapped in a '
      'list (secondaryDiveIds shape expected by DiveConsolidationService)',
      (tester) async {
        List<String>? mergedIds;

        await _pumpAndOpenDialog(
          tester,
          allDives: _sameDayCandidates(),
          onMerge: (ids) => mergedIds = ids,
        );
        await _navigateToConfirmation(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
        await tester.pumpAndSettle();

        expect(mergedIds, equals(['candidate-1']));
        // Dialog should be dismissed.
        expect(find.text('Confirm merge'), findsNothing);
      },
    );
  });

  group('MergeDiveDialog - candidate ordering', () {
    testWidgets('candidates are sorted by time proximity to current dive', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        // 5 hours away
        _makeDive(
          id: 'far',
          diveNumber: 200,
          dateTime: _currentDiveDate.add(const Duration(hours: 5)),
        ),
        // 30 minutes away (should be listed first)
        _makeDive(
          id: 'close',
          diveNumber: 201,
          dateTime: _currentDiveDate.add(const Duration(minutes: 30)),
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      expect(find.text('#200'), findsOneWidget);
      expect(find.text('#201'), findsOneWidget);

      // The closer dive (#201) should appear before the farther one (#200).
      final close = tester.getTopLeft(find.text('#201'));
      final far = tester.getTopLeft(find.text('#200'));
      expect(close.dy, lessThan(far.dy));
    });
  });

  group('MergeDiveDialog - tile formatting', () {
    testWidgets('formats duration over 60min with hours', (tester) async {
      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        _makeDive(
          id: 'long-dive',
          diveNumber: 300,
          duration: const Duration(hours: 1, minutes: 15),
          dateTime: _currentDiveDate.add(const Duration(hours: 1)),
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      expect(find.textContaining('1h 15min'), findsOneWidget);
    });

    testWidgets('formats exact hour duration without remaining minutes', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        _makeDive(
          id: 'hour-dive',
          diveNumber: 301,
          duration: const Duration(hours: 2),
          dateTime: _currentDiveDate.add(const Duration(hours: 1)),
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      expect(find.textContaining('2h'), findsOneWidget);
    });

    testWidgets('tile with no site shows only time in title', (tester) async {
      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        _makeDive(
          id: 'no-site',
          diveNumber: 302,
          dateTime: _currentDiveDate.add(const Duration(hours: 2)),
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      final entryTime = _currentDiveDate.add(const Duration(hours: 2));
      final timeStr = DateFormat(_defaultTimePattern).format(entryTime);

      // Title should be just the time string (no site name prefix).
      expect(find.text(timeStr), findsOneWidget);
    });

    testWidgets('tile with no optional fields shows no subtitle', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        _makeDive(
          id: 'bare',
          dateTime: _currentDiveDate.add(const Duration(hours: 1)),
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      final entryTime = _currentDiveDate.add(const Duration(hours: 1));
      final timeStr = DateFormat(_defaultTimePattern).format(entryTime);
      expect(find.text(timeStr), findsOneWidget);
    });

    testWidgets('uses entryTime over dateTime when available', (tester) async {
      final baseDateTime = _currentDiveDate.add(const Duration(hours: 2));
      final realEntry = _currentDiveDate.add(const Duration(hours: 1));

      final dives = [
        _makeDive(id: 'current-dive', dateTime: _currentDiveDate),
        _makeDive(
          id: 'with-entry',
          diveNumber: 400,
          dateTime: baseDateTime,
          entryTime: realEntry,
        ),
      ];
      await _pumpAndOpenDialog(tester, allDives: dives);

      final entryStr = DateFormat(_defaultTimePattern).format(realEntry);
      expect(find.textContaining(entryStr), findsOneWidget);
    });
  });

  group('showMergeDiveDialog', () {
    testWidgets('opens dialog with correct content', (tester) async {
      await _pumpAndOpenDialog(tester, allDives: _sameDayCandidates());

      expect(find.text('Merge with another dive'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Consolidation service wiring (Task 7).
  //
  // The dialog itself only plumbs the selected id out via onMerge; the
  // apply/undo/snackbar wiring lives in run_dive_consolidation.dart's
  // `runDiveConsolidation`, which is imported and called directly below --
  // there is no hand-copied mirror of that logic in this test file.
  // ---------------------------------------------------------------------------
  group('MergeDiveDialog - consolidation service wiring', () {
    testWidgets(
      'confirming the merge calls DiveConsolidationService.apply with the '
      'current dive as targetDiveId and the selection as secondaryDiveIds',
      (tester) async {
        final service = _FakeDiveConsolidationService();

        await _pumpWithConsolidationHandler(tester, service: service);
        await _navigateToConfirmation(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
        await tester.pumpAndSettle();

        expect(service.capturedTargetDiveId, equals('current-dive'));
        expect(service.capturedSecondaryDiveIds, equals(['candidate-1']));
      },
    );

    testWidgets('shows an Undo snackbar on success with persist:false and '
        "showCloseIcon:true (this repo's convention for actioned SnackBars, "
        "e.g. the combine flow's undo snackbar)", (tester) async {
      final service = _FakeDiveConsolidationService();

      await _pumpWithConsolidationHandler(tester, service: service);
      await _navigateToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.action, isNotNull);
      expect(snackBar.action!.label, equals('Undo'));
      expect(snackBar.persist, isFalse);
      expect(snackBar.showCloseIcon, isTrue);
    });

    testWidgets('tapping Undo calls service.undo with the outcome snapshot', (
      tester,
    ) async {
      final service = _FakeDiveConsolidationService();

      await _pumpWithConsolidationHandler(tester, service: service);
      await _navigateToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(service.undoneSnapshot, isNotNull);
      expect(identical(service.undoneSnapshot, service.outcomeSnapshot), true);
    });

    testWidgets('an ArgumentError with a sameComputer reason surfaces the '
        'sameComputer error text instead of a success snackbar', (
      tester,
    ) async {
      final service = _FakeDiveConsolidationService(
        applyError: ArgumentError('sameComputer: shares comp-1'),
      );

      await _pumpWithConsolidationHandler(tester, service: service);
      await _navigateToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'These dives are from the same dive computer and can\'t be '
          'merged this way.',
        ),
        findsOneWidget,
      );
      // No Undo action on a failure snackbar.
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.action, isNull);
    });

    testWidgets('a non-ArgumentError failure (e.g. a dive deleted by sync '
        'mid-flow) surfaces the generic error text instead of crashing', (
      tester,
    ) async {
      final service = _FakeDiveConsolidationService(
        applyError: StateError('Bad state: No element'),
      );

      await _pumpWithConsolidationHandler(tester, service: service);
      await _navigateToConfirmation(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't merge the dives. Nothing was changed."),
        findsOneWidget,
      );
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.action, isNull);
      // The interaction failed gracefully: no unhandled exception reached
      // the framework.
      expect(tester.takeException(), isNull);
    });
  });
}

/// Pumps a dialog whose `onMerge` calls the real
/// [runDiveConsolidation] from run_dive_consolidation.dart -- the exact
/// function production wires up in `_showMergeDiveDialog` -- so there is no
/// duplicated apply/undo/SnackBar logic in this test file.
Future<void> _pumpWithConsolidationHandler(
  WidgetTester tester, {
  required _FakeDiveConsolidationService service,
  String currentDiveId = 'current-dive',
}) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  late BuildContext savedContext;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diveListNotifierProvider.overrideWith(
          (ref) => _FakeDiveListNotifier(_sameDayCandidates()),
        ),
        settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              savedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  showMergeDiveDialog(
    context: savedContext,
    currentDiveId: currentDiveId,
    currentDiveDate: _currentDiveDate,
    onMerge: (ids) => runDiveConsolidation(
      context: savedContext,
      service: service,
      targetDiveId: currentDiveId,
      secondaryDiveIds: ids,
      onConsolidated: () {},
    ),
  );
  await tester.pumpAndSettle();
}

/// Records calls made to [DiveConsolidationService.apply] and [.undo] so
/// tests can assert on the wiring contract without touching a real database.
class _FakeDiveConsolidationService extends DiveConsolidationService {
  _FakeDiveConsolidationService({this.applyError}) : super(DiveRepository());

  /// When set, [apply] throws this instead of returning a fake outcome.
  final Object? applyError;

  String? capturedTargetDiveId;
  List<String>? capturedSecondaryDiveIds;
  DiveMergeSnapshot? undoneSnapshot;

  /// The snapshot handed back inside [apply]'s outcome -- exposed so tests
  /// can assert Undo is invoked with this exact instance.
  final DiveMergeSnapshot outcomeSnapshot = const DiveMergeSnapshot(
    mergedDiveId: 'candidate-1',
    diveRows: [],
    profileRows: [],
    tankRows: [],
    weightRows: [],
    customFieldRows: [],
    equipmentRows: [],
    diveTypeRows: [],
    tagRows: [],
    buddyRows: [],
    sightingRows: [],
    eventRows: [],
    gasSwitchRows: [],
    tankPressureRows: [],
    dataSourceRows: [],
    tideRows: [],
    mediaDiveIds: {},
  );

  @override
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
  }) async {
    capturedTargetDiveId = targetDiveId;
    capturedSecondaryDiveIds = secondaryDiveIds;
    final error = applyError;
    if (error != null) throw error;
    return DiveConsolidationOutcome(
      targetDiveId: targetDiveId,
      snapshot: outcomeSnapshot,
    );
  }

  @override
  Future<void> undo(DiveMergeSnapshot snapshot) async {
    undoneSnapshot = snapshot;
  }
}

/// Notifier that stays in loading state indefinitely.
class _LoadingDiveListNotifier extends StateNotifier<AsyncValue<List<Dive>>>
    implements DiveListNotifier {
  _LoadingDiveListNotifier() : super(const AsyncValue.loading());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Notifier that immediately reports an error.
class _ErrorDiveListNotifier extends StateNotifier<AsyncValue<List<Dive>>>
    implements DiveListNotifier {
  _ErrorDiveListNotifier()
    : super(AsyncValue.error('Connection failed', StackTrace.current));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
