import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_return_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';

class _Recorded {
  _Recorded(this.ids, this.locationId, this.movedAt, this.note);
  final List<String> ids;
  final String? locationId;
  final DateTime movedAt;
  final String note;
}

class _FakeMoves extends Fake implements EquipmentLocationMoveRepository {
  _FakeMoves({
    required this.history,
    this.parts = const {},
    this.current = const {},
  });

  final Map<String, List<EquipmentLocationMove>> history;
  final Map<String, EquipmentStatus> parts;
  final Map<String, String?> current;
  final recorded = <_Recorded>[];

  @override
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async =>
      history[equipmentId] ?? const [];

  @override
  Future<Map<String, EquipmentStatus>> partsOf(Iterable<String> ids) async =>
      parts;

  @override
  Future<Map<String, String?>> getCurrentLocationIds() async => current;

  @override
  Future<List<EquipmentLocationMove>> recordMoves({
    required Iterable<String> equipmentIds,
    required String? locationId,
    required DateTime movedAt,
    String note = '',
  }) async {
    recorded.add(_Recorded(equipmentIds.toList(), locationId, movedAt, note));
    return const [];
  }
}

void main() {
  EquipmentLocation place(
    String id, {
    String? buddyId,
    EquipmentLocationKind kind = EquipmentLocationKind.storage,
  }) => EquipmentLocation(
    id: id,
    name: id,
    kind: kind,
    buddyId: buddyId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final anna = place('anna', buddyId: 'b1', kind: EquipmentLocationKind.person);
  final shelf = place('shelf');
  final locker = place('locker');
  final shop = place('shop', kind: EquipmentLocationKind.serviceShop);
  final places = {
    for (final p in [anna, shelf, locker, shop]) p.id: p,
  };

  EquipmentItem item(
    String id, {
    EquipmentStatus status = EquipmentStatus.loaned,
  }) =>
      EquipmentItem(id: id, name: id, type: EquipmentType.bcd, status: status);

  final loanAt = DateTime(2026, 10, 12, 14);
  final returnAt = DateTime(2026, 10, 20, 9);

  /// [before] newest first, then the loan on top.
  List<EquipmentLocationMove> history(
    String id,
    List<String?> before, {
    DateTime? loan,
  }) => [
    EquipmentLocationMove(
      id: '$id-loan',
      equipmentId: id,
      locationId: 'anna',
      movedAt: loan ?? loanAt,
      createdAt: loan ?? loanAt,
    ),
    for (final (i, location) in before.indexed)
      EquipmentLocationMove(
        id: '$id-$i',
        equipmentId: id,
        locationId: location,
        movedAt: DateTime(2026, 3, 2 - i),
        createdAt: DateTime(2026, 3, 2 - i),
      ),
  ];

  late List<(EquipmentStatus, int)> statusAsks;
  late List<int> partsAsks;
  late List<(List<String>, EquipmentStatus)> statusWrites;
  late bool statusFailed;

  setUp(() {
    statusAsks = [];
    partsAsks = [];
    statusWrites = [];
    statusFailed = false;
  });

  EquipmentReturnFlow flow(
    _FakeMoves moves, {
    bool answerParts = true,
    bool answerStatus = true,
    bool failStatus = false,
  }) => EquipmentReturnFlow(
    moves: moves,
    askMoveParts: (n) async {
      partsAsks.add(n);
      return answerParts;
    },
    askStatus: (status, n) async {
      statusAsks.add((status, n));
      return answerStatus;
    },
    setStatus: (ids, status) async {
      if (failStatus) throw StateError('no');
      statusWrites.add((ids, status));
    },
    onStatusFailed: () => statusFailed = true,
  );

  Future<int> run(
    EquipmentReturnFlow f,
    List<EquipmentItem> items, {
    DateTime? movedAt,
    String note = '',
  }) => f.run(
    items: items,
    buddyId: 'b1',
    places: places,
    movedAt: movedAt ?? returnAt,
    note: note,
  );

  test('each item goes back to its own previous place', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'b': history('b', ['locker']),
      },
    );

    final count = await run(flow(moves), [
      item('a'),
      item('b'),
    ], note: 'back from course');

    expect(count, 2);
    expect(moves.recorded.map((r) => (r.ids.join(), r.locationId)), [
      ('a', 'shelf'),
      ('b', 'locker'),
    ]);
    expect(moves.recorded.every((r) => r.note == 'back from course'), isTrue);
    expect(moves.recorded.every((r) => r.movedAt == returnAt), isTrue);
  });

  test('items sharing a destination and time share one write', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'b': history('b', ['shelf']),
      },
    );

    await run(flow(moves), [item('a'), item('b')]);

    expect(moves.recorded.single.ids, ['a', 'b']);
  });

  test('no move before the loan goes to No location, still offering '
      'Active', () async {
    final moves = _FakeMoves(history: {'a': history('a', const [])});

    await run(flow(moves), [item('a')]);

    expect(moves.recorded.single.locationId, isNull);
    expect(statusAsks, [(EquipmentStatus.active, 1)]);
    expect(statusWrites.single.$1, ['a']);
    expect(statusWrites.single.$2, EquipmentStatus.active);
  });

  test('Loaned Out is offered Active once across every destination', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'b': history('b', ['shop']),
        'c': history('c', const []),
      },
    );

    await run(flow(moves), [item('a'), item('b'), item('c')]);

    expect(statusAsks, [(EquipmentStatus.active, 3)]);
    expect(statusWrites.single.$1, ['a', 'b', 'c']);
  });

  test('gear that was never Loaned Out gets no prompt', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'b': history('b', ['shelf']),
      },
    );

    await run(flow(moves), [
      item('a', status: EquipmentStatus.active),
      item('b', status: EquipmentStatus.needsService),
    ]);

    expect(moves.recorded, hasLength(1));
    expect(statusAsks, isEmpty);
    expect(statusWrites, isEmpty);
  });

  test('only the Loaned Out items are offered Active', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'b': history('b', ['shelf']),
      },
    );

    await run(flow(moves), [
      item('a'),
      item('b', status: EquipmentStatus.active),
    ]);

    expect(statusAsks, [(EquipmentStatus.active, 1)]);
    expect(statusWrites.single.$1, ['a']);
  });

  test('answering No keeps the status and the moves', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
      },
    );

    await run(flow(moves, answerStatus: false), [item('a')]);

    expect(moves.recorded, hasLength(1));
    expect(statusWrites, isEmpty);
  });

  test('a return dated before the loan lands at the loan, per item', () async {
    final early = DateTime(2026, 10, 12, 9);
    final late = DateTime(2026, 10, 12, 16);
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf'], loan: early),
        'b': history('b', ['shelf'], loan: late),
      },
    );
    final noon = DateTime(2026, 10, 12, 12);

    await run(flow(moves), [item('a'), item('b')], movedAt: noon);

    expect(moves.recorded.map((r) => (r.ids.join(), r.movedAt)), [
      ('a', noon),
      ('b', late),
    ]);
  });

  test('a part at the same buddy is asked about and goes back to its own '
      'previous place', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'p': history('p', ['locker']),
      },
      parts: {'p': EquipmentStatus.loaned},
      current: {'p': 'anna'},
    );

    final count = await run(flow(moves), [item('a')]);

    expect(partsAsks, [1]);
    expect(count, 2);
    expect(moves.recorded.map((r) => (r.ids.join(), r.locationId)), [
      ('a', 'shelf'),
      ('p', 'locker'),
    ]);
    expect(statusAsks, [(EquipmentStatus.active, 2)]);
  });

  test('declining the parts prompt leaves the part with the buddy', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
      },
      parts: {'p': EquipmentStatus.loaned},
      current: {'p': 'anna'},
    );

    final count = await run(flow(moves, answerParts: false), [item('a')]);

    expect(count, 1);
    expect(moves.recorded.single.ids, ['a']);
  });

  test('a part kept elsewhere is not asked about', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
      },
      parts: {'p': EquipmentStatus.active},
      current: {'p': 'shelf'},
    );

    await run(flow(moves), [item('a')]);

    expect(partsAsks, isEmpty);
    expect(moves.recorded.single.ids, ['a']);
  });

  test('a failed status write is reported and the moves still count', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
      },
    );

    final count = await run(flow(moves, failStatus: true), [item('a')]);

    expect(count, 1);
    expect(statusFailed, isTrue);
  });

  test('no items writes nothing and asks nothing', () async {
    final moves = _FakeMoves(history: const {});

    expect(await run(flow(moves), const []), 0);
    expect(moves.recorded, isEmpty);
    expect(statusAsks, isEmpty);
  });

  test('destinations names where each item would go', () async {
    final moves = _FakeMoves(
      history: {
        'a': history('a', ['shelf']),
        'b': history('b', ['shelf']),
        'c': history('c', const []),
      },
    );

    expect(
      await flow(moves).destinations(
        items: [item('a'), item('b')],
        buddyId: 'b1',
        places: places,
      ),
      {shelf},
    );
    expect(
      await flow(moves).destinations(
        items: [item('a'), item('c')],
        buddyId: 'b1',
        places: places,
      ),
      {shelf, null},
    );
  });
}
