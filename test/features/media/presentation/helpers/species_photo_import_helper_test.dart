import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';
import 'package:submersion/features/media/presentation/pages/photo_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A gallery with nothing in it, granted.
class _EmptyGallery implements PhotoPickerService {
  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.authorized;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoPipeline implements NetworkFetchPipeline {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoCredentials implements NetworkCredentialsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoRepository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A species page's Add photos (issue #4527, media library decision 5).
void main() {
  testWidgets('opens the picker with its Gallery tab only', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoPickerServiceProvider.overrideWithValue(_EmptyGallery()),
          // The picker clears the URL tab's staging as it opens; no
          // database behind it here.
          urlTabNotifierProvider.overrideWith(
            (ref) => UrlTabNotifier(
              pipeline: _NoPipeline(),
              credentials: _NoCredentials(),
              mediaRepository: _NoRepository(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    SpeciesPhotoImportHelper.preparePhotosForSpecies(
                      context,
                      ref,
                      speciesId: 'sp',
                    ),
                child: const Text('Add photos'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add photos'));
    await tester.pumpAndSettle();

    final picker = tester.widget<PhotoPickerPage>(find.byType(PhotoPickerPage));
    expect(picker.galleryOnly, isTrue);
  });
}
