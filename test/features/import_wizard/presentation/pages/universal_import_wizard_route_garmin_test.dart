import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/pages/universal_import_wizard_route.dart';

/// Issue #4223: the wizard's Garmin download location carries the saved
/// computer and whether to read every activity.
void main() {
  GarminRequestParts? parse(String location) {
    final request = UniversalImportWizardRoute.garminImportFrom(
      Uri.parse(location),
    );
    return request == null
        ? null
        : (computerId: request.computerId, readAll: request.readAll);
  }

  test('a location round-trips its request', () {
    final location = UniversalImportWizardRoute.garminDeviceImportLocationFor(
      computerId: 'dc 1/2',
      readAll: true,
    );

    expect(location, startsWith('/transfer/import-wizard?'));
    expect(parse(location), (computerId: 'dc 1/2', readAll: true));
  });

  test('the plain location reads after the marker of any watch', () {
    expect(parse(UniversalImportWizardRoute.garminDeviceImportLocation), (
      computerId: null,
      readAll: false,
    ));
  });

  test('a plain file import is no Garmin request', () {
    expect(parse('/transfer/import-wizard'), isNull);
    expect(parse('/transfer/import-wizard?source=other'), isNull);
  });
}

typedef GarminRequestParts = ({String? computerId, bool readAll});
