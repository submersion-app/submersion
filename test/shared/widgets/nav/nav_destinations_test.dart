import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_selection.dart';

void main() {
  group('kNavDestinations', () {
    test('Insights uses the insights glyph', () {
      final insights = kNavDestinations.singleWhere((d) => d.id == 'insights');
      expect(insights.icon, Icons.insights_outlined);
      expect(insights.selectedIcon, Icons.insights);
    });

    test('has exactly 16 entries (15 routable + more sentinel)', () {
      expect(kNavDestinations.length, 16);
    });

    test('exactly two entries are pinned (dashboard and more)', () {
      final pinned = kNavDestinations.where((d) => d.isPinned).toList();
      expect(pinned.length, 2);
      expect(pinned.map((d) => d.id).toSet(), {'dashboard', 'more'});
    });

    test('ids are unique', () {
      final ids = kNavDestinations.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids match kebab-case pattern', () {
      final pattern = RegExp(r'^[a-z][a-z-]*$');
      for (final d in kNavDestinations) {
        expect(pattern.hasMatch(d.id), isTrue, reason: 'bad id: ${d.id}');
      }
    });

    test('contains the expected 15 routable ids plus more sentinel', () {
      expect(kNavDestinations.map((d) => d.id).toList(), [
        'dashboard',
        'dives',
        'sites',
        'trips',
        'equipment',
        'buddies',
        'dive-centers',
        'training',
        'media-documents',
        'species',
        'insights',
        'planning',
        'transfer',
        'tracks',
        'settings',
        'more',
      ]);
    });

    test('Tracks takes GPS Log\'s place and route', () {
      final tracks = kNavDestinations.firstWhere((d) => d.id == 'tracks');
      expect(tracks.route, '/tracks');
      expect(kNavDestinations.map((d) => d.id), isNot(contains('gps-log')));
    });

    test('Training replaces Certifications and Courses', () {
      final training = kNavDestinations.firstWhere((d) => d.id == 'training');
      expect(training.route, '/training');
      expect(training.extraMatchPaths, ['/certifications', '/courses']);
      expect(training.icon, Icons.school_outlined);
      expect(training.selectedIcon, Icons.school);
      expect(training.accentId, 'certifications');
      final ids = kNavDestinations.map((d) => d.id);
      expect(ids, isNot(contains('certifications')));
      expect(ids, isNot(contains('courses')));
    });

    test('Training is the selected entry on every training page', () {
      final training = kNavDestinations.indexWhere((d) => d.id == 'training');
      for (final location in const [
        '/training',
        '/certifications',
        '/certifications/wallet',
        '/certifications/abc/edit',
        '/courses',
        '/courses/abc',
        '/courses?selected=abc',
      ]) {
        expect(
          bestNavMatchIndex(kNavDestinations, Uri.parse(location)),
          training,
          reason: location,
        );
      }
    });

    test('Media-Documents replaces Media and Documents', () {
      final mediaDocuments = kNavDestinations.firstWhere(
        (d) => d.id == 'media-documents',
      );
      expect(mediaDocuments.route, '/media');
      expect(mediaDocuments.extraMatchPaths, ['/documents']);
      expect(mediaDocuments.icon, Icons.photo_library_outlined);
      expect(mediaDocuments.selectedIcon, Icons.photo_library);
      expect(mediaDocuments.accentId, 'media');
      final ids = kNavDestinations.map((d) => d.id);
      expect(ids, isNot(contains('media')));
      expect(ids, isNot(contains('documents')));
    });

    test(
      'Media-Documents is the selected entry on every media/documents page',
      () {
        final mediaDocuments = kNavDestinations.indexWhere(
          (d) => d.id == 'media-documents',
        );
        for (final location in const [
          '/media',
          '/documents',
          '/documents/abc',
          '/documents/abc/edit',
          '/documents?type=insurance',
        ]) {
          expect(
            bestNavMatchIndex(kNavDestinations, Uri.parse(location)),
            mediaDocuments,
            reason: location,
          );
        }
      },
    );

    test(
      'routable destinations have non-empty route; more sentinel has empty route',
      () {
        for (final d in kNavDestinations) {
          if (d.id == 'more') {
            expect(d.route, '');
          } else {
            expect(d.route, isNotEmpty);
          }
        }
      },
    );
  });

  group('movableNavIds', () {
    test('is kNavDestinations minus dashboard and more, in order', () {
      expect(movableNavIds, [
        'dives',
        'sites',
        'trips',
        'equipment',
        'buddies',
        'dive-centers',
        'training',
        'media-documents',
        'species',
        'insights',
        'planning',
        'transfer',
        'tracks',
        'settings',
      ]);
    });

    test('has exactly 14 entries', () {
      expect(movableNavIds.length, 14);
    });

    test('Connections lives in Insights, not in the nav', () {
      expect(kNavDestinations.map((d) => d.id), isNot(contains('connections')));
    });
  });
}
