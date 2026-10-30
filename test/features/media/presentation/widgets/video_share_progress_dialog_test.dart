import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/share_preparation.dart';
import 'package:submersion/features/media/presentation/widgets/video_share_progress_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3521: the dialog shown while corrected videos are re-encoded.
void main() {
  Future<ValueNotifier<VideoShareProgress>> pump(
    WidgetTester tester, {
    VideoShareProgress initial = const VideoShareProgress(index: 1, total: 1),
    VoidCallback? onCancel,
  }) async {
    final progress = ValueNotifier(initial);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoShareProgressDialog(
            progress: progress,
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    );
    return progress;
  }

  testWidgets('one video says Preparing video, indeterminate at first', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Preparing video'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
  });

  testWidgets('shows the percentage as the encode runs', (tester) async {
    final progress = await pump(tester);
    progress.value = const VideoShareProgress(
      index: 1,
      total: 1,
      fraction: 0.42,
    );
    await tester.pump();
    expect(find.text('42%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.42, 1e-9));
  });

  testWidgets('several videos say which one of how many', (tester) async {
    await pump(
      tester,
      initial: const VideoShareProgress(index: 2, total: 3, fraction: 0.1),
    );
    expect(find.text('Preparing video 2 of 3'), findsOneWidget);
  });

  testWidgets('Cancel calls onCancel once and then disables', (tester) async {
    var cancels = 0;
    await pump(tester, onCancel: () => cancels++);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.tap(find.text('Cancel'), warnIfMissed: false);
    await tester.pump();
    expect(cancels, 1);
  });
}
