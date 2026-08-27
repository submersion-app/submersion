import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/notification_permission_card.dart';

import '../../../../helpers/test_app.dart';

/// Answers [requestPermission] with a scripted result and counts the calls.
///
/// Mirrors the platform contract the card is written against: a real iOS
/// request returns false without drawing anything once a decision exists.
class _FakeNotificationService implements NotificationService {
  _FakeNotificationService(this.grantResult) : currentlyGranted = grantResult;

  /// What a request comes back with.
  final bool grantResult;

  /// What the platform currently reports, settable so a test can stand in for
  /// the user changing the answer in the Settings app while we are backgrounded.
  bool currentlyGranted;

  int requestCount = 0;

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    return grantResult;
  }

  @override
  Future<bool> isPermissionGranted() async => currentlyGranted;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

void main() {
  Widget buildCard({
    required _FakeNotificationService service,
    Future<bool> Function()? openSettings,
  }) {
    return testApp(
      overrides: [notificationServiceProvider.overrideWithValue(service)],
      child: NotificationPermissionCard(openSettings: openSettings),
    );
  }

  /// Hosts the card the way the settings page does, behind a watch on
  /// [notificationPermissionProvider], so a stale cache is observable.
  Widget buildHosted({
    required _FakeNotificationService service,
    Future<bool> Function()? openSettings,
  }) {
    return testApp(
      overrides: [notificationServiceProvider.overrideWithValue(service)],
      child: Consumer(
        builder: (context, ref, _) {
          return ref
              .watch(notificationPermissionProvider)
              .when(
                data: (granted) => granted
                    ? const Text('permission resolved')
                    : NotificationPermissionCard(openSettings: openSettings),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              );
        },
      ),
    );
  }

  group('NotificationPermissionCard', () {
    testWidgets('offers a neutral action before the platform has been asked', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(service: _FakeNotificationService(true)),
      );
      await tester.pumpAndSettle();

      // Guideline 5.1.1(iv): nothing here may urge the user to allow access.
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Enable'), findsNothing);
      expect(find.text('Open Settings'), findsNothing);
      expect(
        find.text('Service reminders need permission to send notifications'),
        findsOneWidget,
      );
    });

    testWidgets('asks the platform when the neutral action is taken', (
      tester,
    ) async {
      final service = _FakeNotificationService(true);
      await tester.pumpWidget(buildCard(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(service.requestCount, 1);
    });

    testWidgets('switches to Open Settings once the platform refuses', (
      tester,
    ) async {
      final service = _FakeNotificationService(false);
      await tester.pumpWidget(buildCard(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(
        find.text('Enable in system settings to receive reminders'),
        findsOneWidget,
      );
    });

    testWidgets('stays on the neutral action when the platform grants', (
      tester,
    ) async {
      final service = _FakeNotificationService(true);
      await tester.pumpWidget(buildCard(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // A grant clears the card upstream; it must never accuse the user of
      // having refused.
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('the refused action opens settings rather than asking again', (
      tester,
    ) async {
      final service = _FakeNotificationService(false);
      var opened = 0;
      await tester.pumpWidget(
        buildCard(
          service: service,
          openSettings: () async {
            opened++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(service.requestCount, 1);

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(opened, 1);
      // Re-requesting would draw nothing on iOS, so it must not be attempted.
      expect(service.requestCount, 1);
    });

    testWidgets('does not ask the platform merely by being shown', (
      tester,
    ) async {
      final service = _FakeNotificationService(true);
      await tester.pumpWidget(buildCard(service: service));
      await tester.pumpAndSettle();

      expect(service.requestCount, 0);
    });
    testWidgets('re-reads the permission after a trip to the Settings app', (
      tester,
    ) async {
      final service = _FakeNotificationService(false);
      await tester.pumpWidget(
        buildHosted(service: service, openSettings: () async => true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // The user grants while we are backgrounded. Nothing in the app knows.
      service.currentlyGranted = true;
      expect(find.text('Open Settings'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('permission resolved'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('leaves the card in place when Settings changed nothing', (
      tester,
    ) async {
      final service = _FakeNotificationService(false);
      await tester.pumpWidget(
        buildHosted(service: service, openSettings: () async => true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Still refused, so the row must not fall back to offering a prompt the
      // platform will no longer draw.
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(service.requestCount, 1);
    });
  });
}
