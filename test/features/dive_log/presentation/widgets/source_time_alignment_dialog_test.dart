import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/source_time_alignment_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_time_alignment_dialog.dart';

import '../../../../helpers/test_app.dart';

class _FakeService extends SourceTimeAlignmentService {
  _FakeService(this.checks);
  final List<SourceAlignmentCheck> checks;

  @override
  Future<List<SourceAlignmentCheck>> check(String diveId) async => checks;
}

const _trace = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 120, depth: 18),
  DiveProfilePoint(timestamp: 600, depth: 20),
];

SourceAlignmentCheck _check({required int stored, required bool strong}) =>
    SourceAlignmentCheck(
      sourceId: 'src-2',
      storedOffsetSeconds: stored,
      fit: ProfileAlignmentResult(
        offsetSeconds: 2,
        rmsDepthError: strong ? 0.2 : 4,
        overlapFraction: 1,
        usedFallback: false,
        isStrongMatch: strong,
      ),
      primaryTrace: _trace,
      sourceTrace: _trace,
    );

void main() {
  /// Opens the dialog from a button and records what it pops with.
  Future<List<int?>> pumpDialog(
    WidgetTester tester,
    List<SourceAlignmentCheck> checks,
  ) async {
    final results = <int?>[];
    await tester.pumpWidget(
      testApp(
        overrides: [
          sourceTimeAlignmentServiceProvider.overrideWithValue(
            _FakeService(checks),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await SourceTimeAlignmentDialog.show(
                context,
                diveId: 'dive-1',
                sourceId: 'src-2',
                sourceName: 'Suunto Ocean',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  String offsetText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(SourceTimeAlignmentDialog.offsetKey))
      .data!;

  FilledButton applyButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.byKey(SourceTimeAlignmentDialog.applyKey),
  );

  testWidgets('shows the stored offset and the depth match', (tester) async {
    await pumpDialog(tester, [_check(stored: 100, strong: true)]);
    expect(offsetText(tester), '+100 s');
    expect(find.text('Currently +100 s'), findsOneWidget);
    expect(find.text('The depth traces line up best at +2 s.'), findsOneWidget);
    // Nothing changed yet.
    expect(applyButton(tester).onPressed, isNull);
  });

  testWidgets('use depth match then apply pops the fitted offset', (
    tester,
  ) async {
    final results = await pumpDialog(tester, [
      _check(stored: 100, strong: true),
    ]);
    await tester.ensureVisible(find.byKey(SourceTimeAlignmentDialog.useFitKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SourceTimeAlignmentDialog.useFitKey));
    await tester.pumpAndSettle();
    expect(offsetText(tester), '+2 s');
    await tester.tap(find.byKey(SourceTimeAlignmentDialog.applyKey));
    await tester.pumpAndSettle();
    expect(results, [2]);
  });

  testWidgets('nudges move the offset by hand', (tester) async {
    final results = await pumpDialog(tester, [
      _check(stored: 0, strong: false),
    ]);
    expect(find.textContaining('do not match closely enough'), findsOneWidget);
    expect(find.byKey(SourceTimeAlignmentDialog.useFitKey), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right));
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(offsetText(tester), '+9 s');
    await tester.tap(find.byKey(SourceTimeAlignmentDialog.applyKey));
    await tester.pumpAndSettle();
    expect(results, [9]);
  });

  testWidgets('cancel pops null', (tester) async {
    final results = await pumpDialog(tester, [
      _check(stored: 100, strong: true),
    ]);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('a source without a readable trace explains why', (tester) async {
    await pumpDialog(tester, const []);
    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull);
  });
}
