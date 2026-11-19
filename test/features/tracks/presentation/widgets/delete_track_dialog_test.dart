import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/widgets/delete_track_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/test_app.dart';

/// The delete confirmation the Tracks list and the tracks' own pages share
/// (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  const item = GpsTrackItem(GpsTrack(id: 't1', startTime: 0));

  Future<List<bool>> pumpAndAsk(WidgetTester tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answers.add(await confirmDeleteTrack(context, item)),
            child: const Text('ask'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('confirms in the GPS track wording', (tester) async {
    final answers = await pumpAndAsk(tester);

    expect(find.text(l.gpsLogger_deleteTrackTitle), findsOneWidget);
    await tester.tap(find.text(l.common_action_delete));
    await tester.pumpAndSettle();

    expect(answers, [true]);
  });

  testWidgets('cancelling answers false', (tester) async {
    final answers = await pumpAndAsk(tester);

    await tester.tap(find.text(l.common_action_cancel));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('dismissing answers false', (tester) async {
    final answers = await pumpAndAsk(tester);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });
}
