import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_numbering_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_app.dart';

class _FakeDiveRepository implements DiveRepository {
  bool assignMissingCalled = false;
  bool renumberAllCalled = false;
  int? renumberStartFrom;
  Object? errorOnAssignMissing;
  Object? errorOnRenumber;

  @override
  Future<void> assignMissingDiveNumbers({String? diverId}) async {
    if (errorOnAssignMissing != null) throw errorOnAssignMissing!;
    assignMissingCalled = true;
  }

  @override
  Future<void> renumberAllDives({int startFrom = 1, String? diverId}) async {
    if (errorOnRenumber != null) throw errorOnRenumber!;
    renumberAllCalled = true;
    renumberStartFrom = startFrom;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveNumberingInfo _healthyInfo() => DiveNumberingInfo(
  dives: const [],
  gaps: const [],
  hasGaps: false,
  hasUnnumbered: false,
);

DiveNumberingInfo _infoWithGap() => DiveNumberingInfo(
  dives: const [],
  gaps: [DiveNumberGap(missingStart: 5, missingEnd: 7)],
  hasGaps: true,
  hasUnnumbered: false,
);

DiveNumberingInfo _infoWithUnnumbered() => DiveNumberingInfo(
  dives: [DiveNumberEntry(diveId: 'u1', entryTime: DateTime(2026))],
  gaps: const [],
  hasGaps: false,
  hasUnnumbered: true,
);

/// Pumps the app, opens the dialog, and returns the fake repo.
Future<_FakeDiveRepository> _pumpAndOpen(
  WidgetTester tester, {
  DiveNumberingInfo Function()? info,
  _FakeDiveRepository? repo,
}) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final fakeRepo = repo ?? _FakeDiveRepository();
  late BuildContext savedContext;

  await tester.pumpWidget(
    testApp(
      overrides: [
        diveNumberingInfoProvider.overrideWith(
          (_) async => (info ?? _healthyInfo)(),
        ),
        diveRepositoryProvider.overrideWithValue(fakeRepo),
        validatedCurrentDiverIdProvider.overrideWith((_) async => 'diver-1'),
      ],
      child: Builder(
        builder: (ctx) {
          savedContext = ctx;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  showDiveNumberingDialog(savedContext);
  await tester.pumpAndSettle();

  return fakeRepo;
}

void main() {
  group('DiveNumberingDialog', () {
    testWidgets('shows loading spinner while provider resolves', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Completer-based future so no timer is left pending after the test.
      final completer = Completer<DiveNumberingInfo>();
      late BuildContext savedContext;

      await tester.pumpWidget(
        testApp(
          overrides: [
            diveNumberingInfoProvider.overrideWith((_) => completer.future),
            diveRepositoryProvider.overrideWithValue(_FakeDiveRepository()),
            validatedCurrentDiverIdProvider.overrideWith(
              (_) async => 'diver-1',
            ),
          ],
          child: Builder(
            builder: (ctx) {
              savedContext = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      showDiveNumberingDialog(savedContext);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future so Riverpod does not leave the provider dangling.
      completer.complete(_healthyInfo());
      await tester.pumpAndSettle();
    });

    testWidgets('shows dialog title', (tester) async {
      await _pumpAndOpen(tester);
      expect(find.text('Dive Numbering'), findsOneWidget);
    });

    testWidgets('shows check_circle and "all correct" when healthy', (
      tester,
    ) async {
      await _pumpAndOpen(tester, info: _healthyInfo);
      expect(find.text('All dives numbered correctly'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows "issues detected" card when there are gaps', (
      tester,
    ) async {
      await _pumpAndOpen(tester, info: _infoWithGap);
      expect(find.text('Issues detected'), findsOneWidget);
    });

    testWidgets('shows gaps section with gap descriptions', (tester) async {
      await _pumpAndOpen(tester, info: _infoWithGap);
      expect(find.text('Gaps Detected'), findsOneWidget);
      expect(find.text('Missing dives #5-7'), findsOneWidget);
    });

    testWidgets('shows unnumbered dives warning', (tester) async {
      await _pumpAndOpen(tester, info: _infoWithUnnumbered);
      expect(find.textContaining('without numbers'), findsOneWidget);
    });

    testWidgets(
      'does not show assign-missing action when no unnumbered dives',
      (tester) async {
        await _pumpAndOpen(tester, info: _healthyInfo);
        expect(find.text('Assign missing numbers'), findsNothing);
      },
    );

    testWidgets('shows assign-missing action when unnumbered dives exist', (
      tester,
    ) async {
      await _pumpAndOpen(tester, info: _infoWithUnnumbered);
      expect(find.text('Assign missing numbers'), findsOneWidget);
    });

    testWidgets('close button dismisses the dialog', (tester) async {
      await _pumpAndOpen(tester);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(DiveNumberingDialog), findsNothing);
    });

    group('assign missing numbers', () {
      testWidgets('calls repository and shows success snackbar', (
        tester,
      ) async {
        final repo = _FakeDiveRepository();
        await _pumpAndOpen(tester, info: _infoWithUnnumbered, repo: repo);

        await tester.tap(find.text('Assign missing numbers'));
        await tester.pumpAndSettle();

        expect(repo.assignMissingCalled, isTrue);
        expect(find.text('Missing dive numbers assigned'), findsOneWidget);
      });

      testWidgets('shows error snackbar when repository throws', (
        tester,
      ) async {
        final repo = _FakeDiveRepository()
          ..errorOnAssignMissing = Exception('DB error');
        await _pumpAndOpen(tester, info: _infoWithUnnumbered, repo: repo);

        await tester.tap(find.text('Assign missing numbers'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Error:'), findsOneWidget);
      });
    });

    group('renumber all dives', () {
      testWidgets('opens confirmation dialog', (tester) async {
        await _pumpAndOpen(tester);

        await tester.tap(find.text('Renumber all dives'));
        await tester.pumpAndSettle();

        expect(find.text('Renumber All Dives'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('calls repository with startFrom=1 and shows snackbar', (
        tester,
      ) async {
        final repo = _FakeDiveRepository();
        await _pumpAndOpen(tester, repo: repo);

        await tester.tap(find.text('Renumber all dives'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Renumber'));
        await tester.pumpAndSettle();

        expect(repo.renumberAllCalled, isTrue);
        expect(repo.renumberStartFrom, 1);
        expect(
          find.text('All dives renumbered starting from #1'),
          findsOneWidget,
        );
      });

      testWidgets('cancel in confirmation dialog does not call repository', (
        tester,
      ) async {
        final repo = _FakeDiveRepository();
        await _pumpAndOpen(tester, repo: repo);

        await tester.tap(find.text('Renumber all dives'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(repo.renumberAllCalled, isFalse);
      });

      testWidgets('shows error snackbar when repository throws', (
        tester,
      ) async {
        final repo = _FakeDiveRepository()
          ..errorOnRenumber = Exception('DB error');
        await _pumpAndOpen(tester, repo: repo);

        await tester.tap(find.text('Renumber all dives'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Renumber'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Error:'), findsOneWidget);
      });
    });
  });
}
