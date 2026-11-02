import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_recorder_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final lri = String.fromCharCode(0x2066);
  final pdi = String.fromCharCode(0x2069);

  group('formatSignedVolts', () {
    test('a drained battery reads negative', () {
      expect(formatSignedVolts(-0.12), '-0.12');
    });

    test('a charged battery reads positive', () {
      expect(formatSignedVolts(0.05), '+0.05');
    });

    test('a change too small to show carries no sign', () {
      expect(formatSignedVolts(-0.001), '0.00');
      expect(formatSignedVolts(0), '0.00');
    });
  });

  group('isolateForDirection', () {
    test('wraps a signed figure in an LTR isolate inside RTL text', () {
      expect(isolateForDirection('-0.12', TextDirection.rtl), '$lri-0.12$pdi');
    });

    test('leaves LTR text alone', () {
      expect(isolateForDirection('-0.12', TextDirection.ltr), '-0.12');
    });
  });

  group('NavTrackRecorderCard', () {
    final route =
        NavTrack(
          id: 'r1',
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'r1.csv',
          startTime: 1755856800000,
          endTime: 1755860400000,
          pointCount: 2,
          createdAt: DateTime(2026, 8, 22),
          updatedAt: DateTime(2026, 8, 22),
        ).copyWith(
          points: const [
            NavTrackPoint(
              timestamp: 1755856800,
              north: 0,
              east: 0,
              depth: 0,
              batteryVolts: 3.9,
            ),
            NavTrackPoint(
              timestamp: 1755857000,
              north: 0,
              east: 0,
              depth: 0,
              batteryVolts: 3.78,
            ),
          ],
        );

    Future<void> pump(WidgetTester tester, Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: NavTrackRecorderCard(route: route)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('in Hebrew the arrow points from start to end and the signed '
        'change stays whole', (tester) async {
      await pump(tester, const Locale('he'));
      expect(find.textContaining('3.90'), findsOneWidget);
      expect(find.textContaining('←'), findsOneWidget);
      expect(find.textContaining('$lri-0.12$pdi'), findsOneWidget);
    });

    testWidgets('left-to-right text carries no isolate', (tester) async {
      await pump(tester, const Locale('en'));
      expect(find.text('Battery: 3.90 V → 3.78 V (-0.12 V)'), findsOneWidget);
    });
  });
}
