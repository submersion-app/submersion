import 'package:flutter/material.dart';

import 'package:submersion/core/router/media_documents_locations.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/pages/documents_page.dart';
import 'package:submersion/features/media/presentation/pages/media_section_page.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_tabs/section_tabs_host.dart';

/// The Media screen: Photos/Videos and Documents as two tabs of a
/// [SectionTabsHost] (#3631), the way Training holds Certifications and
/// Courses (#3437).
class MediaDocumentsPage extends StatelessWidget {
  const MediaDocumentsPage({super.key, required this.tab, this.tabBodyBuilder});

  /// The tab the current address names.
  final MediaDocumentsTab tab;

  /// Builds a tab's body; the real pages when null.
  final SectionTabBodyBuilder<MediaDocumentsTab>? tabBodyBuilder;

  /// The switch's names, in tab order.
  static List<String> labels(BuildContext context) => [
    context.l10n.nav_photosVideos,
    context.l10n.nav_documents,
  ];

  /// A tab's real body. Documents' filters come from the tab's own cached
  /// query rather than the active route's, so they survive a round trip
  /// through the Photos/Videos tab instead of resetting whenever the active
  /// address is `/media`.
  static Widget _body(
    BuildContext context,
    MediaDocumentsTab tab,
    SectionHeaderTitle headerTitle,
    Map<String, String> query,
  ) => switch (tab) {
    MediaDocumentsTab.media => MediaSectionPage(headerTitle: headerTitle),
    MediaDocumentsTab.documents => DocumentsPage(
      initialType: DocumentType.values.asNameMap()[query['type']],
      initialExpiringOnly: query['filter'] == 'expiring',
      initialPersonalOnly: query['owner'] == 'personal',
      initialTagId: query['tag'],
      headerTitle: headerTitle,
    ),
  };

  @override
  Widget build(BuildContext context) => SectionTabsHost<MediaDocumentsTab>(
    tabs: MediaDocumentsTab.values,
    tab: tab,
    labels: labels,
    toggleKey: const ValueKey('media_documents_section_toggle'),
    bodyBuilder: tabBodyBuilder ?? _body,
  );
}
