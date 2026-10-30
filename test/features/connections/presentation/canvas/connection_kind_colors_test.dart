import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';

double _hueGap(Color a, Color b) {
  final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

void main() {
  for (final (name, palette) in [
    ('light', FeatureAccentColors.light),
    ('dark', FeatureAccentColors.dark),
  ]) {
    group('$name palette', () {
      final colors = ConnectionKindColors.fromPalette(
        palette,
        palette.of('connections')!,
      );
      final buddy = colors.colorFor(ConnectionKind.buddy);

      test('buddies and sites are far apart in hue', () {
        expect(
          _hueGap(buddy, colors.colorFor(ConnectionKind.site)),
          greaterThanOrEqualTo(90),
        );
      });

      test('buddies differ in hue from every other kind on the map', () {
        for (final kind in ConnectionKind.values) {
          if (kind == ConnectionKind.buddy || kind.accentFeatureId == null) {
            continue;
          }
          expect(
            _hueGap(buddy, colors.colorFor(kind)),
            greaterThanOrEqualTo(30),
            reason: kind.name,
          );
        }
      });

      test('the app-wide buddies accent is left alone', () {
        expect(buddy, isNot(palette.of('buddies')));
        expect(palette.of('connections-buddy'), buddy);
      });
    });
  }
}
