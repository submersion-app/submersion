import 'dart:async';

import 'package:submersion/features/media_store/data/media_store_reconnect.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/domain/media_store_reconnect_situation.dart';

/// Answers fixed situations for the guided reconnect sheet (issue #2303)
/// and records what the sheet asked for, without reaching a store.
class FakeMediaStoreReconnect implements MediaStoreReconnect {
  FakeMediaStoreReconnect([this.situations = const [ReconnectResolved()]]);

  /// Answered in turn; the last one repeats.
  final List<MediaStoreReconnectSituation> situations;
  int inspectCalls = 0;
  int reconnectCalls = 0;
  int detachCalls = 0;
  bool createsNewStore = false;
  Object? reconnectFailure;
  Object? detachFailure;

  /// When set, [reconnect] waits for it before answering.
  Completer<void>? gate;

  /// When set, [inspect] waits for it before answering.
  Completer<void>? inspectGate;

  @override
  Future<MediaStoreReconnectSituation> inspect() async {
    final i = inspectCalls++;
    await inspectGate?.future;
    return situations[i < situations.length ? i : situations.length - 1];
  }

  @override
  Future<({MediaStoreConnectResult result, int queued})> reconnect() async {
    reconnectCalls++;
    await gate?.future;
    if (reconnectFailure case final f?) throw f;
    return (
      result: MediaStoreConnectResult(
        storeId: 'store-b',
        createdNewStore: createsNewStore,
      ),
      queued: 3,
    );
  }

  @override
  Future<void> detach() async {
    detachCalls++;
    if (detachFailure case final f?) throw f;
  }
}
