// Session scoping for [UrlTabNotifier] (issue #1996).
//
// The notifier is global on purpose: the draft has to survive a swipe to
// another picker tab, and Undo can fire after the picker closes. The picker
// therefore starts a new session on open instead, and work the previous
// session left in flight must not reach into the new one when it lands.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

const _oldUrl = 'https://example.com/old.jpg';
const _newUrl = 'https://example.com/new.jpg';

/// Holds every [resolve] and [insertResolved] call open until the test
/// completes the matching gate, one gate per call in call order.
class _GatedPipeline implements NetworkFetchPipeline {
  final resolveGates = <Completer<void>>[];
  final insertGates = <Completer<void>>[];

  @override
  Future<List<ResolvedNetworkMedia>> resolve(List<Uri> uris) async {
    final gate = Completer<void>();
    resolveGates.add(gate);
    await gate.future;
    return [for (final uri in uris) ResolvedNetworkMedia(uri: uri)];
  }

  @override
  Future<List<String>> insertResolved(
    List<NetworkInsertRequest> requests, {
    String? subscriptionId,
  }) async {
    final gate = Completer<void>();
    insertGates.add(gate);
    await gate.future;
    return ['row-1'];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCredentials implements NetworkCredentialsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMediaRepository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _GatedPipeline pipeline;
  late UrlTabNotifier notifier;

  setUp(() {
    pipeline = _GatedPipeline();
    notifier = UrlTabNotifier(
      pipeline: pipeline,
      credentials: _FakeCredentials(),
      mediaRepository: _FakeMediaRepository(),
    );
  });

  tearDown(() => notifier.dispose());

  test('startSession drops the draft and what the last session left', () {
    notifier
      ..setMode(UrlTabMode.manifest)
      ..setDraft(_oldUrl);

    notifier.startSession();

    expect(notifier.state.draftLines, isEmpty);
    expect(notifier.state.committedIds, isEmpty);
    expect(notifier.state.lastError, isNull);
    expect(notifier.state.unauthenticatedHosts, isEmpty);
    expect(notifier.state.mode, UrlTabMode.manifest);
  });

  group('a resolve left pending by the last session', () {
    test('does not disable Add in the next session', () {
      notifier.setDraft(_oldUrl);
      unawaited(notifier.resolveDraft());
      expect(notifier.state.resolving, isTrue);

      notifier.startSession();

      expect(notifier.state.resolving, isFalse);
    });

    test('does not end a resolve the next session started', () async {
      notifier.setDraft(_oldUrl);
      final stale = notifier.resolveDraft();
      notifier
        ..startSession()
        ..setDraft(_newUrl);
      final current = notifier.resolveDraft();

      pipeline.resolveGates.first.complete();
      await stale;

      expect(notifier.state.resolving, isTrue);

      pipeline.resolveGates.last.complete();
      await current;

      expect(notifier.state.resolving, isFalse);
    });
  });

  group('a commit left pending by the last session', () {
    test('does not erase the draft typed in the next session', () async {
      notifier.setDraft(_oldUrl);
      final stale = notifier.commitRequests(const []);
      notifier
        ..startSession()
        ..setDraft(_newUrl);

      pipeline.insertGates.single.complete();
      final ids = await stale;

      expect(notifier.state.draftLines, [_newUrl]);
      expect(notifier.state.committedIds, isEmpty);
      // The rows exist regardless, and its Undo snackbar still needs them.
      expect(ids, ['row-1']);
    });
  });

  test('a commit in the current session clears its draft as before', () async {
    notifier.setDraft(_oldUrl);
    final commit = notifier.commitRequests(const []);

    pipeline.insertGates.single.complete();
    await commit;

    expect(notifier.state.draftLines, isEmpty);
    expect(notifier.state.committedIds, ['row-1']);
  });
}
