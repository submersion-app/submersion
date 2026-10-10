import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
    ),
  );

  SafetyFinding finding(String id, {required int start, int? end}) {
    return SafetyFinding(
      id: id,
      diveId: 'd1',
      ruleId: SafetyRuleId.rapidAscent,
      severity: SafetySeverity.caution,
      startTimestamp: start,
      endTimestamp: end,
      value: 14,
      engineVersion: 1,
      createdAt: DateTime(2026),
    );
  }

  Future<void> pumpChart(
    WidgetTester tester, {
    List<SafetyFinding>? safetyFindings,
    String? selectedId,
    void Function(SafetyFinding)? onTap,
    List<PhotoChartMarker>? photoMarkers,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                safetyFindings: safetyFindings,
                selectedSafetyFindingId: selectedId,
                onSafetyFindingTap:
                    onTap ?? (safetyFindings != null ? (_) {} : null),
                photoMarkers: photoMarkers,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no findings renders no lane overlay', (tester) async {
    await pumpChart(tester);
    expect(find.byType(SafetyFindingsOverlay), findsNothing);
  });

  testWidgets('findings render the lane overlay with chips', (tester) async {
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
    );
    // Two layers: the lane below the photo markers, the callout above.
    expect(find.byType(SafetyFindingsOverlay), findsNWidgets(2));
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
  });

  testWidgets('chip tap reaches the chart callback', (tester) async {
    SafetyFinding? tapped;
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    // Settle past the chart's double-tap window so its recognizer's timer
    // resolves before the test tears the tree down.
    await tester.pumpAndSettle();
    expect(tapped?.id, 'a');
  });

  testWidgets('selected finding shows the callout above the lane', (
    tester,
  ) async {
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
      selectedId: 'a',
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsOneWidget);
  });

  group('stacking against photo markers (issue #3051)', () {
    // A photo at the deepest point opens its preview card downward, across
    // the lane. Stack children paint in order, so the depth-first element
    // order below is the paint order: a later element paints on top.
    PhotoChartMarker deepPhoto() {
      final now = DateTime.utc(2026);
      return PhotoChartMarker(
        item: MediaItem(
          id: 'p1',
          diveId: 'd1',
          mediaType: MediaType.photo,
          takenAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        elapsedSeconds: 150,
        depthMeters: 15,
      );
    }

    int paintOrder(WidgetTester tester, Finder finder) {
      final target = tester.element(finder);
      return tester.allElements.toList().indexOf(target);
    }

    testWidgets('the photo preview card paints above the lane', (tester) async {
      await pumpChart(
        tester,
        safetyFindings: [finding('a', start: 60, end: 120)],
        photoMarkers: [deepPhoto()],
      );
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('photoMarkerCard'));
      expect(card, findsOneWidget);
      expect(
        paintOrder(tester, card),
        greaterThan(
          paintOrder(tester, find.byKey(const ValueKey('safetyLaneStrip'))),
        ),
      );
      expect(
        paintOrder(tester, card),
        greaterThan(
          paintOrder(tester, find.byKey(const ValueKey('safetyLaneChip-0'))),
        ),
      );
    });

    testWidgets('the finding callout paints above the photo markers', (
      tester,
    ) async {
      await pumpChart(
        tester,
        safetyFindings: [finding('a', start: 60, end: 120)],
        selectedId: 'a',
        photoMarkers: [deepPhoto()],
      );

      expect(
        paintOrder(tester, find.byKey(const ValueKey('safetyFindingCallout'))),
        greaterThan(paintOrder(tester, find.byIcon(Icons.camera_alt))),
      );
    });
  });
}
