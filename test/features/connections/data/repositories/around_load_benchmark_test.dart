import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';

import '../../../../helpers/test_database.dart';

/// A log of 400 dives, 60 buddies and 40 sites: Around at three hops with
/// both kinds on reaches most of it. Loose bound on purpose: CI varies.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test(
    'three hops over a 400-dive log loads well inside a second or two',
    () async {
      final d = DatabaseService.instance.database;
      const ms = 1700000000000;
      await d
          .into(d.divers)
          .insert(
            const db.DiversCompanion(
              id: Value('me'),
              name: Value('me'),
              createdAt: Value(ms),
              updatedAt: Value(ms),
            ),
          );
      await d.batch((b) {
        for (var i = 0; i < 60; i++) {
          b.insert(
            d.buddies,
            db.BuddiesCompanion(
              id: Value('b$i'),
              name: Value('Buddy $i'),
              createdAt: const Value(ms),
              updatedAt: const Value(ms),
            ),
          );
        }
        for (var i = 0; i < 40; i++) {
          b.insert(
            d.diveSites,
            db.DiveSitesCompanion(
              id: Value('s$i'),
              name: Value('Site $i'),
              createdAt: const Value(ms),
              updatedAt: const Value(ms),
            ),
          );
        }
      });
      final rng = math.Random(7);
      await d.batch((b) {
        for (var i = 0; i < 400; i++) {
          b.insert(
            d.dives,
            db.DivesCompanion(
              id: Value('d$i'),
              diverId: const Value('me'),
              siteId: Value('s${rng.nextInt(40)}'),
              diveDateTime: Value(ms + i * 86400000),
              createdAt: const Value(ms),
              updatedAt: const Value(ms),
            ),
          );
          final buddies = {
            for (var k = 0; k < 1 + rng.nextInt(3); k++) rng.nextInt(60),
          };
          for (final bi in buddies) {
            b.insert(
              d.diveBuddies,
              db.DiveBuddiesCompanion(
                id: Value('d$i-b$bi'),
                diveId: Value('d$i'),
                buddyId: Value('b$bi'),
                role: const Value('buddy'),
                createdAt: const Value(ms),
              ),
            );
          }
        }
      });

      final sw = Stopwatch()..start();
      final g = await ConnectionsRepository().loadAround(
        focus: const NodeRef(ConnectionKind.buddy, 'b0'),
        kinds: {ConnectionKind.buddy, ConnectionKind.site},
        hops: 3,
        diverId: 'me',
        nodeBudget: 160,
      );
      sw.stop();
      expect(g.nodes, isNotEmpty);
      expect(g.nodes.length, lessThanOrEqualTo(160));
      expect(
        sw.elapsedMilliseconds,
        lessThan(3000),
        reason: 'took ${sw.elapsedMilliseconds} ms',
      );
    },
  );
}
