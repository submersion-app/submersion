import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/new_dive_after_create.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// What a new dive is owed once it exists, as the new-dive form runs it
/// after its write (issue #4527, plan 8).
void main() {
  final entry = DateTime.utc(2026, 11, 17, 9, 30);
  const point = GeoPoint(7.1, 134.2);
  const reef = DiveSite(id: 'reef', name: 'Blue Corner', location: point);
  final logged = Dive(id: 'new', dateTime: entry, entryTime: entry, site: reef);

  late List<String> steps;

  NewDiveAfterCreate after({Object? failing}) => NewDiveAfterCreate(
    fetchWeather: (dive, location) {
      steps.add('weather ${dive.id} ${location.latitude}');
      if (failing == 'weather') throw StateError('weather');
    },
    recordTide: (dive, location) async {
      steps.add('tide ${dive.id}');
      if (failing == 'tide') throw StateError('tide');
    },
    runRules: (id) async {
      steps.add('rules $id');
      if (failing == 'rules') throw StateError('rules');
    },
    offerMirror: (id) async => steps.add('mirror $id'),
  );

  setUp(() => steps = []);

  test('weather, tide, rules and the mirror question, in that order', () async {
    await after().run(created: logged);
    expect(steps, ['weather new 7.1', 'tide new', 'rules new', 'mirror new']);
  });

  test('no weather over weather the diver entered or fetched', () async {
    await after().run(created: logged.copyWith(cloudCover: CloudCover.clear));
    expect(steps, ['tide new', 'rules new', 'mirror new']);
  });

  // A site's rules write the entry method on the Environment card; that is
  // no weather of the diver's (review of plan 8).
  test('an entry method from the site does not stop the weather', () async {
    await after().run(created: logged.copyWith(entryMethod: EntryMethod.shore));
    expect(steps.first, 'weather new 7.1');
  });

  test('no weather and no tide for a dive with no site position', () async {
    await after().run(
      created: logged.copyWith(
        site: const DiveSite(id: 's', name: 'Pool'),
      ),
    );
    expect(steps, ['rules new', 'mirror new']);
  });

  test('a planned dive runs no rules and asks no mirror question', () async {
    await after().run(created: logged.copyWith(isPlanned: true));
    expect(steps, ['weather new 7.1', 'tide new']);
  });

  test('a step that throws does not stop the next', () async {
    for (final failing in ['weather', 'tide', 'rules']) {
      steps = [];
      await after(failing: failing).run(created: logged);
      expect(steps.last, 'mirror new', reason: failing);
    }
  });

  // The tide record needs the network and is best effort, as the weather
  // is: the page does not wait on it to move on (second review of plan 8).
  test('a tide lookup still running does not hold up the rest', () async {
    final tide = Completer<void>();
    final after = NewDiveAfterCreate(
      fetchWeather: (_, _) {},
      recordTide: (_, _) => tide.future,
      runRules: (id) async => steps.add('rules $id'),
      offerMirror: (id) async => steps.add('mirror $id'),
    );
    await after.run(created: logged).timeout(const Duration(seconds: 1));
    expect(steps, ['rules new', 'mirror new']);
    tide.complete();
  });
}
