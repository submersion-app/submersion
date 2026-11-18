import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// The service that saves an editing sitting on a site.
final siteEditSaveServiceProvider = Provider<SiteEditSaveService>(
  (ref) => SiteEditSaveService(ref.watch(siteRepositoryProvider)),
);
