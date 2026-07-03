import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _diveId = 'd1';

List<DiveProfilePoint> _profile() =>
    List.generate(61, (i) => DiveProfilePoint(timestamp: i * 10, depth: 10));

void main() {
  late ProviderContainer container;

  Widget wrap() {
    container = ProviderContainer();
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileTransportControls(diveId: _diveId, profile: _profile()),
        ),
      ),
    );
  }

  testWidgets('play button starts playback', (tester) async {
    await tester.pumpWidget(wrap());
    // The widget initializes+activates playback on first build.
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(container.read(playbackProvider(_diveId)).isPlaying, isTrue);
    container.read(playbackProvider(_diveId).notifier).pause();
  });

  testWidgets('slider seek updates playback and review position', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(120, 0));
    await tester.pump();

    expect(
      container.read(playbackProvider(_diveId)).currentTimestamp,
      greaterThan(0),
    );
    expect(container.read(profileReviewProvider(_diveId)), greaterThan(0));
  });

  testWidgets('speed chip shows current speed', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('30x'), findsOneWidget);
  });

  testWidgets('ticker updates propagate to profileReviewProvider', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    // Advance the fake clock several ticks (25ms each at default 30x speed).
    await tester.pump(const Duration(milliseconds: 200));

    final playbackTimestamp = container
        .read(playbackProvider(_diveId))
        .currentTimestamp;
    expect(playbackTimestamp, greaterThan(0));
    expect(
      container.read(profileReviewProvider(_diveId)),
      equals(playbackTimestamp),
    );

    container.read(playbackProvider(_diveId).notifier).pause();
  });

  testWidgets('seeking while playing does not pause playback', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(container.read(playbackProvider(_diveId)).isPlaying, isTrue);

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(60, 0));
    await tester.pump();

    expect(container.read(playbackProvider(_diveId)).isPlaying, isTrue);

    container.read(playbackProvider(_diveId).notifier).pause();
  });
}
