import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';

MediaDropDestination? _destinationFor(
  String? routeName,
  String location, {
  Map<String, String> pathParameters = const {},
  bool detailPaneVisible = true,
}) => mediaDropDestinationForRoute(
  routeName: routeName,
  pathParameters: pathParameters,
  uri: Uri.parse(location),
  isDetailVisible: (_) => detailPaneVisible,
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

    test('a selected item is not one while a narrow window hides it', () {
      // Below the master-detail breakpoint the list stands alone, so the
      // selected id left in the URL names a dive the user cannot see.
      expect(
        _destinationFor(
          'dives',
          '/dives?selected=dive-1',
          detailPaneVisible: false,
        ),
        isNull,
      );
      expect(
        _destinationFor(
          'sites',
          '/sites?selected=site-1',
          detailPaneVisible: false,
        ),
        isNull,
      );
    });

    test('a detail page is one whatever the window width', () {
      expect(
        _destinationFor(
          'diveDetail',
          '/dives/dive-1',
          pathParameters: {'diveId': 'dive-1'},
          detailPaneVisible: false,
        ),
        const MediaDropDestination(target: DiveAttachTarget('dive-1')),
      );
    });

    test('a list with nothing selected is not a media destination', () {
      expect(_destinationFor('dives', '/dives'), isNull);
      expect(_destinationFor('sites', '/sites'), isNull);
    });

    test('a selected item being edited is not one', () {
      expect(_destinationFor('dives', '/dives?selected=d&mode=edit'), isNull);
    });

    test('asks about the section the route belongs to', () {
      final asked = <String>[];
      mediaDropDestinationForRoute(
        routeName: 'sites',
        pathParameters: const {},
        uri: Uri.parse('/sites?selected=s'),
        isDetailVisible: (section) {
          asked.add(section);
          return true;
        },
      );
      expect(asked, ['sites']);
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

  group('isListDetailVisible', () {
    bool visible({
      bool wideWindow = true,
      bool tableMode = false,
      bool tableDetailsPane = true,
      String location = '/dives?selected=d',
    }) => isListDetailVisible(
      wideWindow: wideWindow,
      tableMode: tableMode,
      tableDetailsPane: tableDetailsPane,
      uri: Uri.parse(location),
    );

    test('a wide list shows its selected item beside it', () {
      expect(visible(), isTrue);
    });

    test('a narrow window shows the list alone', () {
      expect(visible(wideWindow: false), isFalse);
      expect(visible(wideWindow: false, tableMode: true), isFalse);
    });

    test('the list layout swaps the detail for the map', () {
      expect(visible(location: '/dives?selected=d&view=map'), isFalse);
    });

    test('the table layout shows the detail only with its pane on', () {
      expect(visible(tableMode: true), isTrue);
      expect(visible(tableMode: true, tableDetailsPane: false), isFalse);
    });

    test('the table layout keeps the detail beside its map', () {
      expect(
        visible(tableMode: true, location: '/dives?selected=d&view=map'),
        isTrue,
      );
    });
  });
}
