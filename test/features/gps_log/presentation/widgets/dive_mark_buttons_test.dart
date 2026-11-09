import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_draft_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gps_log/data/services/dive_mark_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/dive_mark_buttons.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records the taps instead of writing drafts.
class FakeDiveMarks implements DiveMarkService {
  final calls = <String>[];

  @override
  Future<Dive> enteredWater({required String diverId, DateTime? at}) async {
    calls.add('entered:$diverId');
    return Dive(id: 'draft', dateTime: DateTime(2026, 7, 17, 10));
  }

  @override
  Future<Dive?> surfaced({DateTime? at}) async {
    calls.add('surfaced');
    return null;
  }
}

final openDraft = Dive(
  id: 'draft',
  dateTime: DateTime(2026, 7, 17, 10),
  entryTime: DateTime(2026, 7, 17, 10),
  isDraft: true,
);

/// The base overrides already set a current-diver notifier with no diver,
/// so [pumpMarks] selects the diver once the tree is up.
Future<List<dynamic>> markOverrides(FakeDiveMarks marks, {Dive? open}) async =>
    [
      ...await getBaseOverrides(),
      diveMarkServiceProvider.overrideWithValue(marks),
      openDraftProvider('a').overrideWith((ref) async => open),
    ];

Widget harness(List<dynamic> overrides, Widget child) => ProviderScope(
  overrides: overrides.cast(),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

Future<void> pumpMarks(
  WidgetTester tester,
  Widget app, {
  String? diverId = 'a',
}) async {
  await tester.pumpWidget(app);
  if (diverId != null) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverId);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no open draft it offers Entered water', (tester) async {
    final marks = FakeDiveMarks();
    await pumpMarks(
      tester,
      harness(await markOverrides(marks), const DiveMarkButtons()),
    );

    expect(find.text('Surfaced'), findsNothing);
    await tester.tap(find.text('Entered water'));
    await tester.pumpAndSettle();
    expect(marks.calls, ['entered:a']);
  });

  testWidgets('with an open draft it offers Surfaced', (tester) async {
    final marks = FakeDiveMarks();
    await pumpMarks(
      tester,
      harness(
        await markOverrides(marks, open: openDraft),
        const DiveMarkButtons(),
      ),
    );

    expect(find.text('Entered water'), findsNothing);
    await tester.tap(find.text('Surfaced'));
    await tester.pumpAndSettle();
    expect(marks.calls, ['surfaced']);
  });

  testWidgets('with no diver there is nothing to mark', (tester) async {
    await pumpMarks(
      tester,
      harness(await markOverrides(FakeDiveMarks()), const DiveMarkButtons()),
      diverId: null,
    );

    expect(find.text('Entered water'), findsNothing);
    expect(find.text('Surfaced'), findsNothing);
  });

  testWidgets('the strip button marks without leaving the page', (
    tester,
  ) async {
    final marks = FakeDiveMarks();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: GpsRecordingStrip()),
        ),
        GoRoute(
          path: '/tracks',
          builder: (context, state) => const Text('TRACKS-PAGE'),
        ),
      ],
    );
    await pumpMarks(
      tester,
      ProviderScope(
        overrides: [
          ...await markOverrides(marks),
          gpsRecorderStateProvider.overrideWith(
            (ref) => Stream.value(
              const GpsRecorderState(
                status: GpsRecorderStatus.recording,
                trackId: 't1',
                pointCount: 2,
              ),
            ),
          ),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Entered water'));
    await tester.pumpAndSettle();

    expect(marks.calls, ['entered:a']);
    expect(find.text('TRACKS-PAGE'), findsNothing);
  });
}
