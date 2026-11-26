import 'dart:ui' show Locale;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/presentation/widgets/poll_interval_options.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppDatabase db;
  late ManifestSubscriptionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    DatabaseService.instance.setTestDatabase(db);
    repo = ManifestSubscriptionRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<ManifestSubscription> create() => repo.createSubscription(
    manifestUrl: 'https://feed.example.com/m.json',
    format: ManifestFormat.json,
  );

  test('a new interval moves the next poll with it', () async {
    final sub = await create();
    final polled = DateTime.utc(2026, 1, 1, 12);
    await repo.recordPollSuccess(
      sub.id,
      pollIntervalSeconds: 86400,
      etag: null,
      lastModified: null,
      now: polled,
    );

    await repo.setPollInterval(sub.id, 3600);

    final after = await repo.getById(sub.id);
    expect(after!.pollIntervalSeconds, 3600);
    expect(after.nextPollAt, polled.add(const Duration(hours: 1)));
    expect(after.lastPolledAt, polled);
  });

  test('a subscription never polled stays due', () async {
    final sub = await create();
    await repo.setPollInterval(sub.id, 604800);
    final after = await repo.getById(sub.id);
    expect(after!.pollIntervalSeconds, 604800);
    expect(after.nextPollAt, isNull);
  });

  test('a failed first poll moves its retry with a new interval', () async {
    final sub = await create();
    final failed = DateTime.utc(2026, 1, 1, 12);
    await repo.recordPollFailure(
      sub.id,
      pollIntervalSeconds: 604800,
      error: 'boom',
      now: failed,
    );
    // A week doubled is capped at a day.
    expect(
      (await repo.getById(sub.id))!.nextPollAt,
      failed.add(const Duration(hours: 24)),
    );

    await repo.setPollInterval(sub.id, 3600);

    // The same backoff, now on an hour: twice the interval.
    expect(
      (await repo.getById(sub.id))!.nextPollAt,
      failed.add(const Duration(hours: 2)),
    );
  });

  test('a failure after a successful poll counts from the failure', () async {
    final sub = await create();
    final polled = DateTime.utc(2026, 1, 1, 12);
    await repo.recordPollSuccess(
      sub.id,
      pollIntervalSeconds: 86400,
      etag: null,
      lastModified: null,
      now: polled,
    );
    final failed = polled.add(const Duration(days: 1));
    await repo.recordPollFailure(
      sub.id,
      pollIntervalSeconds: 86400,
      error: 'boom',
      now: failed,
    );

    await repo.setPollInterval(sub.id, 21600);

    expect(
      (await repo.getById(sub.id))!.nextPollAt,
      failed.add(const Duration(hours: 12)),
    );
  });

  test('a non-positive interval is refused', () async {
    final sub = await create();
    expect(() => repo.setPollInterval(sub.id, 0), throwsArgumentError);
  });

  group('pollIntervalOptionsIncluding', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final de = lookupAppLocalizations(const Locale('de'));

    test('a standard interval offers the standard list', () {
      expect(pollIntervalOptionsIncluding(86400), same(kPollIntervalOptions));
    });

    test('an unusual interval is added in order', () {
      final options = pollIntervalOptionsIncluding(7200);
      expect(options.map((o) => o.seconds), [3600, 7200, 21600, 86400, 604800]);
      expect(options[1].label(en), '2 hours');
      expect(pollIntervalOptionsIncluding(1800).first.label(en), '30 minutes');
      expect(
        pollIntervalOptionsIncluding(
          5400,
        ).firstWhere((o) => o.seconds == 5400).label(en),
        '90 minutes',
      );
    });

    test('an interval under a minute still reads as one', () {
      expect(const PollIntervalOption(seconds: 20).label(en), '1 minute');
    });

    test('labels read in the diver\'s language', () {
      expect(kPollIntervalOptions.map((o) => o.label(en)), [
        '1 hour',
        '6 hours',
        '24 hours',
        '7 days',
      ]);
      expect(kPollIntervalOptions.map((o) => o.label(de)), [
        '1 Stunde',
        '6 Stunden',
        '24 Stunden',
        '7 Tage',
      ]);
    });
  });
}
