import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

typedef Override = riverpod.Override;

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Testable notifier that allows seeding the full set of fields the
/// photo-step logic reads from state.
class _TestableNotifier extends UniversalImportNotifier {
  _TestableNotifier(
    super.ref, {
    ImportPayload? payload,
    bool photoLinkingSkipped = false,
  }) {
    state = state.copyWith(
      payload: payload,
      photoLinkingSkipped: photoLinkingSkipped,
    );
  }
}

/// Build a single-ref payload that makes `imageRefs.isNotEmpty` true.
ImportPayload _payloadWithImageRefs() {
  return const ImportPayload(
    entities: {},
    imageRefs: [
      ImportImageRef(originalPath: '/tmp/a.jpg', diveSourceUuid: 'dive-1'),
    ],
  );
}

ImportPayload _payloadWithoutImageRefs() {
  return const ImportPayload(entities: {});
}

/// Pump a widget tree that gives us access to a [WidgetRef] via Consumer
/// so we can construct the adapter the way production does.
Future<void> _runWithAdapter(
  WidgetTester tester, {
  required List<Override> overrides,
  required void Function(UniversalAdapter adapter) callback,
}) async {
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  callback(adapter);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UniversalAdapter.acquisitionSteps Link Photos injection', () {
    testWidgets('omits Link Photos when payload has no imageRefs', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith(
            (ref) =>
                _TestableNotifier(ref, payload: _payloadWithoutImageRefs()),
          ),
        ],
        callback: (adapter) {
          final steps = adapter.acquisitionSteps;
          expect(steps, hasLength(3));
          expect(
            steps.map((s) => s.label),
            equals(['Select File', 'Confirm Source', 'Map Fields']),
          );
        },
      );
    });

    testWidgets('omits Link Photos when payload is null', (tester) async {
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith(
            (ref) => _TestableNotifier(ref),
          ),
        ],
        callback: (adapter) {
          final steps = adapter.acquisitionSteps;
          expect(steps, hasLength(3));
        },
      );
    });

    testWidgets('includes Link Photos when payload has imageRefs', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith(
            (ref) => _TestableNotifier(ref, payload: _payloadWithImageRefs()),
          ),
        ],
        callback: (adapter) {
          final steps = adapter.acquisitionSteps;
          expect(steps, hasLength(4));
          expect(steps.last.label, equals('Link Photos'));
          expect(steps.last.icon, isNotNull);
        },
      );
    });

    testWidgets('keeps Link Photos in the list after user clicks Skip so '
        'auto-advance can move forward without shrinking the step list', (
      tester,
    ) async {
      await _runWithAdapter(
        tester,
        overrides: [
          universalImportNotifierProvider.overrideWith(
            (ref) => _TestableNotifier(
              ref,
              payload: _payloadWithImageRefs(),
              photoLinkingSkipped: true,
            ),
          ),
        ],
        callback: (adapter) {
          final steps = adapter.acquisitionSteps;
          expect(
            steps,
            hasLength(4),
            reason:
                'Removing the step after Skip would shrink the list while '
                '_currentPage still points at it, which re-routes _onNext '
                'into the Review branch and skips bundle preparation.',
          );
          expect(steps.last.label, equals('Link Photos'));
        },
      );
    });
  });
}
