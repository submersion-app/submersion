import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/presentation/change_log_value_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  ChangeLogValueFormatter formatter({
    AppSettings settings = const AppSettings(),
    Map<String, List<ConflictReference>> references = const {},
  }) => ChangeLogValueFormatter(
    l10n: l10n,
    units: UnitFormatter(settings),
    references: references,
  );

  test('a depth follows the unit setting', () {
    expect(
      formatter(
        settings: const AppSettings(depthUnit: DepthUnit.meters),
      ).value('dives', 'max_depth', 30.0),
      '30.0m',
    );
    expect(
      formatter(
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      ).value('dives', 'max_depth', 30.0),
      '98.4ft',
    );
  });

  test('a column gets its catalogue label', () {
    expect(
      formatter().label('dives', 'max_depth'),
      l10n.settings_conflict_notSet.isEmpty ? '' : 'Max Depth',
    );
  });

  test('null reads as not set', () {
    expect(
      formatter().value('dives', 'notes', null),
      l10n.settings_conflict_notSet,
    );
  });

  test('empty text reads as not set', () {
    expect(
      formatter().value('equipment', 'notes', ''),
      l10n.settings_conflict_notSet,
    );
  });

  test('a stored flag reads as yes or no', () {
    expect(
      formatter().value('dives', 'is_favorite', 1),
      l10n.common_action_yes,
    );
  });

  test('a blob shows its size, not its bytes', () {
    final text = formatter().value(
      'dive_data_sources',
      'raw_data',
      Uint8List(2048),
    );

    expect(text, contains('KB'));
    expect(text, isNot(contains('[0,')));
  });

  test('a 5,000 character note is clipped', () {
    final text = formatter().value(
      'dives',
      'notes',
      'x' * 5000,
      clip: kChangeLogFeedClip,
    );

    expect(text.length, lessThanOrEqualTo(kChangeLogFeedClip + 1));
    expect(text, endsWith('…'));
  });

  test('a short note is left alone', () {
    expect(
      formatter().value('dives', 'notes', 'Calm', clip: kChangeLogFeedClip),
      'Calm',
    );
  });

  test('a reference column is named as the conflict dialog names it', () {
    expect(formatter().label('tank_pressure_series', 'tank_id'), 'Tank');
    expect(formatter().label('dive_plans', 'linked_dive_id'), 'Linked dive');
    expect(formatter().label('documents', 'dive_id'), 'Dive');
    // Catalogued: unchanged.
    expect(formatter().label('dives', 'max_depth'), 'Max Depth');
  });

  // A newer peer's column, neither catalogued nor a reference.
  test('a column the catalogue does not know is spelled from its name', () {
    expect(formatter().label('dives', 'brand_new_column'), 'Brand New Column');
  });

  test('a dismissal reads as the moment it was made', () {
    const ms = 1794825060000;
    const units = UnitFormatter(AppSettings());

    expect(
      formatter().value('dive_safety_findings', 'dismissed_at', ms),
      units.formatDateTime(DateTime.fromMillisecondsSinceEpoch(ms), l10n: l10n),
    );
  });

  // A route's link mode is stored as its wire value ('auto', 'manual'),
  // which no diver should read, in any language.
  test('how a route was linked reads in the diver\'s language', () {
    expect(
      formatter().value('nav_tracks', 'link_mode', 'auto'),
      'Automatically',
    );
    expect(formatter().value('nav_tracks', 'link_mode', 'manual'), 'Manually');
    expect(formatter().label('nav_tracks', 'link_mode'), 'Linked');

    final german = ChangeLogValueFormatter(
      l10n: lookupAppLocalizations(const Locale('de')),
      units: const UnitFormatter(AppSettings()),
    );
    expect(german.value('nav_tracks', 'link_mode', 'manual'), 'Manuell');
  });

  // A newer peer may link a route some way this build has never heard of.
  test('a link mode this build does not know is shown as stored', () {
    expect(formatter().value('nav_tracks', 'link_mode', 'shared'), 'shared');
  });

  test('a foreign key reads as the record it points at', () {
    final text = formatter(
      references: const {
        'dives|siteId|s1': [
          ConflictReference(
            field: 'siteId',
            targetType: 'diveSites',
            recordId: 's1',
            name: 'Blue Hole',
          ),
        ],
      },
    ).value('dives', 'site_id', 's1');

    expect(text, 'Blue Hole');
  });

  test('a table name maps to its sync entity', () {
    final wrong = [
      for (final entry in SyncRepository.hlcTargets.entries)
        if (changeLogEntityType(entry.value.table) != entry.key) entry.key,
    ];

    expect(wrong, isEmpty);
  });
}
