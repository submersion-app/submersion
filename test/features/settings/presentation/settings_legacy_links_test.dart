import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/settings_legacy_links.dart';

String? phone(String location) =>
    resolveLegacySettingsLocation(Uri.parse(location), masterDetail: false);

String? desktop(String location) =>
    resolveLegacySettingsLocation(Uri.parse(location), masterDetail: true);

void main() {
  group('desktop', () {
    test('the old Decompression section opens under Safety in the pane', () {
      expect(
        desktop('/settings?selected=decompression'),
        '/settings?selected=safety&safetyPage=decompression',
      );
    });

    test('Safety and its sub-pages already belong in the pane', () {
      expect(desktop('/settings?selected=safety'), isNull);
      expect(desktop('/settings?selected=safety&safetyPage=review'), isNull);
    });

    test('Data pages already belong in the pane', () {
      expect(desktop('/settings?selected=data'), isNull);
      expect(desktop('/settings?selected=data&dataPage=cloud-sync'), isNull);
    });

    test('other sections and no selection are left alone', () {
      expect(desktop('/settings?selected=units'), isNull);
      expect(desktop('/settings'), isNull);
    });
  });

  group('phone', () {
    test('the old Decompression section goes to its new page', () {
      expect(
        phone('/settings?selected=decompression'),
        '/settings/safety/decompression',
      );
    });

    test('Safety goes to the hub, or to the named sub-page', () {
      expect(phone('/settings?selected=safety'), '/settings/safety');
      expect(
        phone('/settings?selected=safety&safetyPage=review'),
        '/settings/safety/review',
      );
      expect(
        phone('/settings?selected=safety&safetyPage=equipment-condition'),
        '/settings/safety/equipment-condition',
      );
      expect(
        phone('/settings?selected=safety&safetyPage=bogus'),
        '/settings/safety',
      );
    });

    test('a Data pane URL goes to the innermost page it opens (#3467)', () {
      expect(phone('/settings?selected=data'), isNull);
      expect(
        phone(
          '/settings?selected=data&dataPage=cloud-sync'
          '&dataPage=cloud-sync%2Fs3-config',
        ),
        '/settings/cloud-sync/s3-config',
      );
      expect(
        phone(
          '/settings?selected=data&dataPage=shared-libraries'
          '&dataPage=shared-libraries%2Fconnect%3Fprefix%3Dclub',
        ),
        '/settings/shared-libraries/connect?prefix=club',
      );
    });

    test('a Data pane URL skips pages the pane cannot show', () {
      expect(
        phone('/settings?selected=data&dataPage=backup&dataPage=appearance'),
        '/settings/backup',
      );
      expect(phone('/settings?selected=data&dataPage=bogus'), isNull);
    });

    test('other sections and no selection are left alone', () {
      expect(phone('/settings?selected=units'), isNull);
      expect(phone('/settings?selected=appearance'), isNull);
      expect(phone('/settings'), isNull);
    });
  });

  group('resolveSettingsSectionRedirect', () {
    test('old Decompression section links open in the desktop pane', () {
      expect(
        resolveSettingsSectionRedirect('decompression', masterDetail: true),
        '/settings?selected=safety&safetyPage=decompression',
      );
    });

    test('on phone they go to the Decompression page', () {
      expect(
        resolveSettingsSectionRedirect('decompression', masterDetail: false),
        '/settings/safety/decompression',
      );
    });

    test('other sections keep their dedicated route or none', () {
      for (final masterDetail in [true, false]) {
        expect(
          resolveSettingsSectionRedirect('safety', masterDetail: masterDetail),
          '/settings/safety',
        );
        expect(
          resolveSettingsSectionRedirect('units', masterDetail: masterDetail),
          isNull,
        );
        expect(
          resolveSettingsSectionRedirect(null, masterDetail: masterDetail),
          isNull,
        );
      }
    });
  });
}
