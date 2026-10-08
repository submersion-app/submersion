import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/presentation/widgets/delete_diver_snackbar_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The message after a profile delete (issues #2594, #2852).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('trips and sites only', () {
    expect(
      deleteDiverSnackbarText(
        l10n,
        const DeleteDiverResult(
          reassignedTripsCount: 2,
          reassignedSitesCount: 1,
          reassignedToDiverName: 'Anna',
        ),
      ),
      'Diver deleted. 2 shared trips and 1 shared site reassigned to Anna.',
    );
  });

  test('kept gear to one profile', () {
    expect(
      deleteDiverSnackbarText(
        l10n,
        const DeleteDiverResult(
          reassignedTripsCount: 0,
          reassignedSitesCount: 0,
          keptEquipmentCount: 3,
          keptEquipmentHeirNames: ['Tom'],
        ),
      ),
      'Diver deleted. 3 pieces of gear handed to Tom.',
    );
  });

  test('kept gear to several profiles, with trips', () {
    expect(
      deleteDiverSnackbarText(
        l10n,
        const DeleteDiverResult(
          reassignedTripsCount: 1,
          reassignedSitesCount: 0,
          reassignedToDiverName: 'Anna',
          keptEquipmentCount: 1,
          keptEquipmentHeirNames: ['Tom', 'Anna'],
        ),
      ),
      'Diver deleted. 1 shared trip and 0 shared sites reassigned to Anna. '
      '1 piece of gear handed to the profiles that use it.',
    );
  });

  test('nothing kept or reassigned', () {
    expect(
      deleteDiverSnackbarText(
        l10n,
        const DeleteDiverResult(
          reassignedTripsCount: 0,
          reassignedSitesCount: 0,
        ),
      ),
      'Diver deleted',
    );
  });
}
