import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Media card's editor: the dive's media grid over the sitting, with
/// Add photos, Scan gallery, Add document, selection with Unlink, and
/// Replace link on a local file, each held until Save (issue #4527, plan
/// 6). A photo still opens in the viewer, which has its own lock.
class DiveMediaCardEditor extends ConsumerWidget {
  const DiveMediaCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => DiveMediaSection(
        diveId: session.stored.id,
        editing: session,
        onOpenDocument: (item) => DocumentOpenHelper.open(context, ref, item),
      ),
    );
  }
}
