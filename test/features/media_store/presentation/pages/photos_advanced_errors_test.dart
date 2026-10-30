// The Photos page's actions say why they failed instead of leaving an
// unhandled error and a silent tap (issue #3482 review).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import 'photos_page_harness.dart';

/// Reads off and refuses every write.
class _RefusingPolicies extends MediaStorePolicies {
  @override
  Future<bool> autoUpload() async => false;

  @override
  Future<bool> photosOnCellular() async => false;

  @override
  Future<void> setAutoUpload(bool value) async =>
      throw StateError('prefs unavailable');
}

/// Holds each auto-upload write open until [release] completes.
class _SlowPolicies extends MediaStorePolicies {
  final writes = <bool>[];
  final release = Completer<void>();

  @override
  Future<bool> autoUpload() async => false;

  @override
  Future<bool> photosOnCellular() async => false;

  @override
  Future<void> setAutoUpload(bool value) async {
    writes.add(value);
    await release.future;
  }
}

void main() {
  late PhotosPageHarness h;

  setUp(() async => h = await PhotosPageHarness.create());

  Future<void> pumpAttached(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(h.app(statusHint: 'dive-media @ minio'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  Future<void> tapAndSettle(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(key));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  testWidgets('a failed upload-everything says why', (tester) async {
    h.backfill.failure = StateError('database is locked');
    await pumpAttached(tester);

    await tapAndSettle(tester, const Key('media-s3-backfill'));

    expect(h.backfill.calls, 1);
    expect(find.textContaining('database is locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed stop-keeping says why', (tester) async {
    h.service.failure = StateError('keychain is locked');
    await pumpAttached(tester);

    await tester.ensureVisible(find.byKey(const Key('media-s3-disconnect')));
    await tester.tap(find.byKey(const Key('media-s3-disconnect')));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, const Key('media-s3-disconnect-confirm'));

    expect(h.service.disconnectCalls, 1);
    expect(find.textContaining('keychain is locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed upload switch goes back and says so', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaStorePoliciesProvider.overrideWithValue(_RefusingPolicies()),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    await tapAndSettle(tester, const Key('media-s3-policy-auto-upload'));

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('media-s3-policy-auto-upload')),
    );
    expect(toggle.value, isFalse);
    expect(find.text('Could not save. Try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // A second tap while the first write is saving could finish first and be
  // overwritten by the older value; the switch waits for its write instead.
  testWidgets('an upload switch is held while its write saves', (tester) async {
    final policies = _SlowPolicies();
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        h.app(
          statusHint: 'dive-media @ minio',
          extraOverrides: [
            mediaStorePoliciesProvider.overrideWithValue(policies),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    final toggle = find.byKey(const Key('media-s3-policy-auto-upload'));

    await tapAndSettle(tester, const Key('media-s3-policy-auto-upload'));
    await tapAndSettle(tester, const Key('media-s3-policy-auto-upload'));

    expect(policies.writes, [true]);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);

    policies.release.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  });
}
