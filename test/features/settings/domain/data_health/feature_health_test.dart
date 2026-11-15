import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

FeatureHealth _h(
  HealthLevel level,
  HealthReason reason, {
  DataFeature feature = DataFeature.sync,
  String? subjectId,
  String? name,
}) => FeatureHealth(
  feature: feature,
  level: level,
  reason: reason,
  subjectId: subjectId,
  name: name,
);

void main() {
  group('pickHealth findings', () {
    test('keeps the headline and lists every candidate', () {
      final a = _h(HealthLevel.attention, HealthReason.syncAutoOff);
      final b = _h(HealthLevel.failing, HealthReason.syncFailed);
      final h = pickHealth(DataFeature.sync, [a, b]);
      expect(h.reason, HealthReason.syncFailed);
      expect(h.level, HealthLevel.failing);
      expect(h.findings, [a, b]);
    });

    test('healthy has no findings', () {
      expect(pickHealth(DataFeature.sync, const []).findings, isEmpty);
    });
  });

  group('findingFor', () {
    final health = pickHealth(DataFeature.sync, [
      _h(HealthLevel.attention, HealthReason.syncAutoOff),
      _h(HealthLevel.failing, HealthReason.syncFailed),
      _h(HealthLevel.attention, HealthReason.syncConflicts),
    ]);

    test('picks the most severe matching reason', () {
      final f = findingFor(health, {
        HealthReason.syncAutoOff,
        HealthReason.syncFailed,
      });
      expect(f?.reason, HealthReason.syncFailed);
    });

    test('ignores reasons not asked for', () {
      expect(findingFor(health, {HealthReason.syncOff}), isNull);
    });

    test('with a subject matches only that subject', () {
      final libs = pickHealth(DataFeature.sharedLibraries, [
        _h(
          HealthLevel.failing,
          HealthReason.librariesFailed,
          feature: DataFeature.sharedLibraries,
          subjectId: 'a',
        ),
        _h(
          HealthLevel.attention,
          HealthReason.librariesEditsHeld,
          feature: DataFeature.sharedLibraries,
          subjectId: 'b',
        ),
      ]);
      const reasons = {
        HealthReason.librariesFailed,
        HealthReason.librariesEditsHeld,
      };
      expect(
        findingFor(libs, reasons, subjectId: 'b')?.reason,
        HealthReason.librariesEditsHeld,
      );
      expect(findingFor(libs, reasons, subjectId: 'c'), isNull);
    });
  });

  group('copyWith', () {
    test('replaces findings and keeps the rest', () {
      final a = _h(HealthLevel.attention, HealthReason.syncOff);
      final b = a.copyWith(findings: [a]);
      expect(b.reason, HealthReason.syncOff);
      expect(b.findings, [a]);
    });
  });

  group('unreachable store text', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 11, 14);

    test('names the account', () {
      final h = _h(
        HealthLevel.attention,
        HealthReason.mediaStoreUnreachable,
        feature: DataFeature.media,
        name: 'B2',
      );
      expect(
        healthReasonText(l10n, h, now),
        l10n.settings_photos_status_unreachable('B2'),
      );
    });

    test('without a name reads as paused', () {
      final h = _h(
        HealthLevel.attention,
        HealthReason.mediaStoreUnreachable,
        feature: DataFeature.media,
      );
      expect(
        healthReasonText(l10n, h, now),
        l10n.settings_photos_status_pausedUnreachable,
      );
    });
  });
}
