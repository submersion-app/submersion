import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/section_tabs/section_tab.dart';

/// The two tabs the Media screen hosts, Photos/Videos and Documents, in
/// their on-screen order (#3631).
enum MediaDocumentsTab implements SectionTab {
  media('/media', 'media'),
  documents('/documents', 'documents');

  const MediaDocumentsTab(this.path, this.featureId);

  @override
  final String path;

  @override
  final String featureId;
}

/// The page key both tab addresses build the Media host under, so moving
/// between `/media` and `/documents` keeps the host (see
/// [sectionTabsHostPage]).
const ValueKey<String> kMediaDocumentsHostPageKey = ValueKey<String>(
  'media-documents-host',
);

/// The page a Media tab address shows: [child] under
/// [kMediaDocumentsHostPageKey].
Page<void> mediaDocumentsHostPage(Widget child) =>
    sectionTabsHostPage(kMediaDocumentsHostPageKey, child);
