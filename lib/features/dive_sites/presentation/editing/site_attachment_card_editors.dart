import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Media card's editor: the site's attachments over the sitting, with
/// Add photos, Add document and selection with Unlink held until Save
/// (issue #4527, phase 2). An attachment's own details stay its own
/// record's, edited from the card or its viewer.
class SiteMediaCardEditor extends ConsumerWidget {
  const SiteMediaCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => SiteMediaSection(
        siteId: session.stored.id,
        editing: session,
        onOpenDocument: (item) => DocumentOpenHelper.open(
          context,
          ref,
          item,
          // The attachment opens under its own lock (issue #4527).
          editableSiteId: session.stored.id,
        ),
      ),
    );
  }
}

/// The Documents card's editor: attach and remove, held until Save, as the
/// dive's Documents card holds them (issue #4527, phase 2).
class SiteDocumentsCardEditor extends StatelessWidget {
  const SiteDocumentsCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => DocumentsSection<DiveSite>(
        owner: DocumentOwner(DocumentOwnerKind.site, session.stored.id),
        editing: session,
      ),
    );
  }
}
