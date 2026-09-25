import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_query.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

void main() {
  test('self-join is detected', () {
    const q = ConnectionQuery(
      kindA: ConnectionKind.buddy,
      kindB: ConnectionKind.buddy,
    );
    expect(q.isSelfJoin, isTrue);
    expect(q.focusIsValid, isTrue);
  });

  test('neighbourKind is the far end of the focus', () {
    const q = ConnectionQuery(
      kindA: ConnectionKind.buddy,
      kindB: ConnectionKind.site,
      focus: NodeRef(ConnectionKind.site, 's1'),
    );
    expect(q.neighbourKind, ConnectionKind.buddy);
    expect(q.focusIsValid, isTrue);
  });

  test('a focus whose kind is not in the query is invalid', () {
    const q = ConnectionQuery(
      kindA: ConnectionKind.buddy,
      kindB: ConnectionKind.buddy,
      focus: NodeRef(ConnectionKind.site, 's1'),
    );
    expect(q.neighbourKind, isNull);
    expect(q.focusIsValid, isFalse);
  });
}
