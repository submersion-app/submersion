import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/presentation/widgets/lock_barrier.dart';
import 'package:submersion/core/presentation/widgets/unlock_form.dart';
import 'package:submersion/core/services/security/database_security_key_store.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DatabaseSecurityService.instance.resetForTesting();
  });

  testWidgets('passes the child through when unlocked, overlays when locked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_lock_enabled': true,
      'app_lock_timeout_minutes': 0,
      // Biometric hardware is absent in tests; keep the auto-fire path off.
      'app_lock_biometrics_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
    );

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const LockBarrier(child: Text('APP'));
            },
          ),
        ),
      ),
    );
    expect(find.text('APP'), findsOneWidget);
    expect(find.byType(UnlockForm), findsNothing);

    // Timeout 0: any background/resume cycle locks immediately.
    final notifier = capturedRef.read(appLockNotifierProvider.notifier);
    notifier.noteBackgrounded();
    notifier.noteResumed();
    await tester.pump();

    expect(find.byType(UnlockForm), findsOneWidget);
  });

  testWidgets('blocks pointers and semantics reaching the app behind it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_lock_enabled': true,
      'app_lock_timeout_minutes': 0,
      'app_lock_biometrics_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    DatabaseSecurityService.instance.resetForTesting();
    await DatabaseSecurityService.instance.configure(
      prefs: prefs,
      keyStore: DatabaseSecurityKeyStore(storage: InMemoryKeychain()),
    );

    // Disposed at the end of the body, not via addTearDown: the framework's
    // "SemanticsHandle was active" check runs before tear-down callbacks.
    final semantics = tester.ensureSemantics();

    var behindTaps = 0;
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return LockBarrier(
                // A full-screen tap target with a label a screen reader
                // could read: exactly the dive-log content a lock must hide.
                child: GestureDetector(
                  onTap: () => behindTaps++,
                  child: const SizedBox.expand(child: Text('SECRET DIVE DATA')),
                ),
              );
            },
          ),
        ),
      ),
    );

    final notifier = capturedRef.read(appLockNotifierProvider.notifier);
    notifier.noteBackgrounded();
    notifier.noteResumed();
    await tester.pump();

    // Tap the top-left corner: inside the overlay, outside its centered
    // content. An opaque-looking overlay that does not absorb pointers would
    // let this through to the app beneath.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(behindTaps, 0, reason: 'overlay must absorb pointer events');

    // Screen readers must not be able to traverse the locked-away content.
    // simulatedAccessibilityTraversal walks what the platform actually
    // exposes; find.bySemanticsLabel would search the widget tree, where the
    // blocked widgets still exist and the leak is invisible.
    final labels = tester.semantics
        .simulatedAccessibilityTraversal()
        .map((node) => node.label)
        .where((label) => label.isNotEmpty)
        .toList();
    expect(
      labels,
      isNot(contains('SECRET DIVE DATA')),
      reason: 'overlay must block semantics of the app behind it',
    );
    expect(
      labels,
      contains('Submersion is locked'),
      reason: 'the lock screen itself must stay accessible',
    );

    semantics.dispose();
  });
}
