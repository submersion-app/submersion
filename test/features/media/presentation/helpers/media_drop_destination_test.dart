import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';

MediaDropDestination? _destinationFor(
  String? routeName,
  String location, {
  Map<String, String> pathParameters = const {},
}) => mediaDropDestinationForRoute(
  routeName: routeName,
  pathParameters: pathParameters,
  uri: Uri.parse(location),
);

void main() {
  group('mediaDropDestinationForRoute', () {
    test('the Media section imports into the library with no owner', () {
      expect(_destinationFor('media', '/media'), const MediaDropDestination());
    });

    test('a dive detail page attaches to that dive', () {
      expect(
        _destinationFor(
          'diveDetail',
          '/dives/dive-1',
          pathParameters: {'diveId': 'dive-1'},
        ),
        const MediaDropDestination(target: DiveAttachTarget('dive-1')),
      );
    });

    test('a site detail page attaches to that site', () {
      expect(
        _destinationFor(
          'siteDetail',
          '/sites/site-1',
          pathParameters: {'siteId': 'site-1'},
        ),
        const MediaDropDestination(target: SiteAttachTarget('site-1')),
      );
    });

    test('the dive list with a dive selected attaches to it', () {
      expect(
        _destinationFor('dives', '/dives?selected=dive-1'),
        const MediaDropDestination(target: DiveAttachTarget('dive-1')),
      );
    });

    test('the site list with a site selected attaches to it', () {
      expect(
        _destinationFor('sites', '/sites?selected=site-1'),
        const MediaDropDestination(target: SiteAttachTarget('site-1')),
      );
    });

    test('a list with nothing selected is not a media destination', () {
      expect(_destinationFor('dives', '/dives'), isNull);
      expect(_destinationFor('sites', '/sites'), isNull);
    });

    test('a selected item being edited or shown on the map is not one', () {
      expect(_destinationFor('dives', '/dives?selected=d&mode=edit'), isNull);
      expect(_destinationFor('sites', '/sites?selected=s&view=map'), isNull);
    });

    test('a create pane is not a media destination', () {
      expect(_destinationFor('dives', '/dives?mode=new'), isNull);
    });

    test('pages under a dive, such as its editor, are not one', () {
      expect(
        _destinationFor(
          'editDive',
          '/dives/dive-1/edit',
          pathParameters: {'diveId': 'dive-1'},
        ),
        isNull,
      );
    });

    test('other sections are not media destinations', () {
      expect(_destinationFor('equipment', '/equipment'), isNull);
      expect(_destinationFor(null, '/home'), isNull);
    });
  });
}
