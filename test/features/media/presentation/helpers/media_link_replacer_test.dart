import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _pickedPath = '/tmp/new-reef.jpg';
const _pickedHash = 'aaaa1111';

MediaItem _item({String? contentHash}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  localPath: '/gone/reef.jpg',
  contentHash: contentHash,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<({String hash, int sizeBytes})> _fakeHash(File _) async =>
    (hash: _pickedHash, sizeBytes: 4);

/// Locate and Replace link hold the re-link they find in a sitting until
/// Save applies it (issue #4527).
void main() {
  late List<RepairProposal> held;

  setUp(() => held = []);

  /// Pumps a host tree and hands back its context and ref.
  ///
  /// Both the picker and the hasher are injected, so nothing here touches the
  /// disk. That matters for the confirm-dialog cases: real I/O only completes
  /// under `tester.runAsync`, and a future started there cannot be awaited
  /// across the pumps that dismiss the dialog without deadlocking.
  Future<({BuildContext context, WidgetRef ref})> host(
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    return (context: capturedContext, ref: capturedRef);
  }

  Future<bool> call(
    WidgetTester tester,
    MediaItem item, {
    String? pick = _pickedPath,
  }) async {
    final h = await host(tester);
    final pending = replaceMediaLink(
      h.context,
      h.ref,
      item,
      pickPath: () async => pick,
      hashFile: _fakeHash,
      onHold: held.add,
    );
    await tester.pumpAndSettle();
    return pending;
  }

  testWidgets('holds an exact proposal when the bytes match the row hash', (
    tester,
  ) async {
    final outcome = await call(tester, _item(contentHash: _pickedHash));

    expect(outcome, isTrue);
    expect(held.single.confidence, RepairConfidence.exact);
    expect(held.single.candidate!.path, _pickedPath);
  });

  testWidgets('a row with no hash is treated as an exact match', (
    tester,
  ) async {
    // Nothing to contradict, so there is no edited-bytes decision to make.
    final outcome = await call(tester, _item());

    expect(outcome, isTrue);
    expect(held.single.confidence, RepairConfidence.exact);
  });

  testWidgets('a cancelled picker holds nothing', (tester) async {
    final outcome = await call(tester, _item(), pick: null);

    expect(outcome, isFalse);
    expect(held, isEmpty);
  });

  // Accepting different bytes re-uploads them to the media store, which is
  // why the flow demands an explicit confirm rather than silently relinking.
  testWidgets('different bytes are not held when the confirm is declined', (
    tester,
  ) async {
    final h = await host(tester);
    final pending = replaceMediaLink(
      h.context,
      h.ref,
      _item(contentHash: 'a-different-hash'),
      pickPath: () async => _pickedPath,
      hashFile: _fakeHash,
      onHold: held.add,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await pending, isFalse);
    expect(held, isEmpty);
  });

  testWidgets('different bytes are held once the confirm is accepted', (
    tester,
  ) async {
    final h = await host(tester);
    final pending = replaceMediaLink(
      h.context,
      h.ref,
      _item(contentHash: 'a-different-hash'),
      pickPath: () async => _pickedPath,
      hashFile: _fakeHash,
      onHold: held.add,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-link'));
    await tester.pumpAndSettle();

    expect(await pending, isTrue);
    // Recorded as edited rather than exact, so the store knows these are new
    // bytes and does not deduplicate the re-upload against the old hash.
    expect(held.single.confidence, RepairConfidence.edited);
  });
}
