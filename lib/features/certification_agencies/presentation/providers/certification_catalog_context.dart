import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';

/// The live certification catalog for helper methods that hold only a
/// [BuildContext] (issue #690).
///
/// This reads without subscribing. A widget that renders from it must also
/// `ref.watch(certificationCatalogSyncProvider)` in its build method, or sit
/// under one that does, so it rebuilds when custom entries change.
extension CertificationCatalogContext on BuildContext {
  CertificationCatalog get certificationCatalog {
    try {
      return ProviderScope.containerOf(
        this,
        listen: false,
      ).read(certificationCatalogSyncProvider);
    } on StateError {
      // No ProviderScope above (a widget pumped on its own in a test):
      // built-in names and colours still render.
      return CertificationCatalog.builtInOnly;
    }
  }
}
