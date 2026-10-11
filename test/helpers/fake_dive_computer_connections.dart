import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';

/// A [DiveComputerConnectionRepository] that records what it was asked to
/// record (issue #3106), for adapter tests that mock the database.
class FakeDiveComputerConnections implements DiveComputerConnectionRepository {
  final recorded =
      <
        ({
          String computerId,
          DiveComputerConnectionKind kind,
          String? detail,
          String? address,
        })
      >[];

  @override
  Future<DiveComputerConnection> recordConnection({
    required String computerId,
    required DiveComputerConnectionKind kind,
    String? detail,
    String? address,
    DateTime? usedAt,
    bool notify = true,
  }) async {
    recorded.add((
      computerId: computerId,
      kind: kind,
      detail: detail,
      address: address,
    ));
    return DiveComputerConnection(
      id: diveComputerConnectionId(
        computerId: computerId,
        kind: kind,
        detail: detail,
      ),
      computerId: computerId,
      kind: kind,
      detail: detail,
      firstUsedAt: usedAt ?? DateTime(2026),
      lastUsedAt: usedAt ?? DateTime(2026),
      address: address,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
